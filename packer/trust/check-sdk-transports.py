#!/usr/bin/env python3
"""Credential-free SDK TLS checks against ephemeral loopback servers.

Run inside the guest/builder being qualified (Python 3 and openssl required):
  python3 packer/trust/check-sdk-transports.py --sdk-root /usr/lib/google-cloud-sdk
  python3 packer/trust/check-sdk-transports.py --sdk-root /usr/local/google-cloud-sdk \
      --transport gcloud --transport httplib2 --transport bq --transport gsutil

No external endpoints, credentials, SDK commands, or host configuration are used.
For stronger containment run the image with --network none and no credential or
home mounts. Each transport runs in a subprocess with a fresh HOME, a fixed PATH,
and an allowlisted environment, removing inherited proxy, credential, Python,
CA, and SDK overrides. gcloud/httplib2, bq and gsutil use the corresponding
installed shell launcher's interpreter-selection preamble, including its Python
arguments. Unknown launcher layouts fail closed. pip/grpc deliberately require
SDK bundled Python (Debian/glibc), never a fallback to system Python on Alpine.

Every mode must reject an unknown ephemeral CA by default, accept that CA when
explicitly supplied, and reject a mismatching IP hostname with that CA supplied.
gRPC performs a real unary RPC using a TLS gRPC server (HTTP/2 via native gRPC),
not a handshake-only HTTP/1 server or readiness timeout. Missing dependencies or
an unusable bundled interpreter are reported as failures, never passing skips.

These are runtime transport controls, not incident-chain replay, cloud API or
mTLS tests. Explicit trust tests client API parameters, not all CLI/config paths.
JSON includes interpreter evidence and individual outcomes. Exit 0 means all
requested transports passed; exit 1 means a failure or unsupported runtime.
Default: run all six transports. The SDK installation is never modified.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import contextlib
import http.server
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading

TRANSPORTS = ("gcloud", "httplib2", "bq", "gsutil", "pip", "grpc")
TIMEOUT = 5


def sandbox_environment(directory):
    """Do not forward user configuration, credentials, trust or proxy overrides."""
    home = directory / "home"
    home.mkdir()
    config = directory / "config"
    config.mkdir()
    return {
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(config),
        "CLOUDSDK_CONFIG": str(config / "gcloud"),
        "CLOUDSDK_CORE_DISABLE_USAGE_REPORTING": "true",
        "CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK": "true",
        "BOTO_CONFIG": os.devnull,
        "BOTO_PATH": os.devnull,
        "PIP_CONFIG_FILE": os.devnull,
        "PYTHONDONTWRITEBYTECODE": "1",
        "LC_ALL": "C.UTF-8",
        "TMPDIR": str(directory),
    }


def worker_command(root, transport):
    arguments = [str(Path(__file__).resolve()), "--sdk-root", str(root),
                 "--transport", transport, "--worker"]
    if transport in ("pip", "grpc"):
        python = root / "platform/bundledpythonunix/bin/python3"
        if not python.is_file():
            raise RuntimeError(f"Unsupported: SDK bundled Python missing: {python}")
        return [str(python), *arguments]

    launcher_name = "gcloud" if transport == "httplib2" else transport
    launcher = root / "bin" / launcher_name
    source = launcher.read_text()
    marker = "# </cloud-sdk-sh-preamble>"
    if source.count(marker) != 1 or "# <cloud-sdk-sh-preamble>" not in source:
        raise RuntimeError(f"Unsupported SDK launcher preamble: {launcher}")
    variable = {"bq": "CLOUDSDK_BQ_PYTHON", "gsutil": "CLOUDSDK_GSUTIL_PYTHON"}.get(
        launcher_name, "CLOUDSDK_PYTHON")
    # $0 must be the real launcher: its preamble resolves the SDK root from it.
    # Retain the launcher's own intentional word splitting of Python arguments.
    preamble = source.split(marker)[0]
    script = preamble + f'\nexec "${variable}" $CLOUDSDK_PYTHON_ARGS "$@"\n'
    return ["/bin/sh", "-c", script, str(launcher), *arguments]


def make_certificates(directory):
    """Create a one-day CA and a localhost-only leaf; no private key leaves tmp."""
    commands = [
        ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", "ca.key",
         "-out", "ca.crt", "-days", "1", "-subj", "/CN=SDK loopback ephemeral CA",
         "-addext", "basicConstraints=critical,CA:TRUE",
         "-addext", "keyUsage=critical,keyCertSign,cRLSign"],
        ["req", "-newkey", "rsa:2048", "-nodes", "-keyout", "server.key",
         "-out", "server.csr", "-subj", "/CN=localhost"],
        ["x509", "-req", "-in", "server.csr", "-CA", "ca.crt", "-CAkey", "ca.key",
         "-CAcreateserial", "-out", "server.crt", "-days", "1", "-extfile", "extensions"],
    ]
    (directory / "extensions").write_text(
        "subjectAltName=DNS:localhost\nextendedKeyUsage=serverAuth\n"
        "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n")
    for command in commands:
        subprocess.run(["openssl", *command], cwd=directory, check=True,
                       capture_output=True, text=True, timeout=30)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, *args):
        pass


@contextlib.contextmanager
def https_server(directory):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(directory / "server.crt", directory / "server.key")
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server.server_port
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


@contextlib.contextmanager
def http_request(root, transport, trust):
    """Initialize the same SDK transports as their CLI bootstraps, without auth."""
    if transport in ("gcloud", "httplib2"):
        sys.path.insert(0, str(root / "lib"))
        import gcloud  # noqa: F401: SDK dependency bootstrap
        if transport == "gcloud":
            from googlecloudsdk.core import requests
            client = requests.GetSession(ca_certs=trust, timeout=TIMEOUT)
            client.trust_env = False
        else:
            import httplib2
            client = httplib2.Http(ca_certs=trust, timeout=TIMEOUT, proxy_info=None)
    elif transport == "bq":
        sys.path.insert(0, str(root / "platform/bq"))
        import bq  # noqa: F401: bq dependency bootstrap
        from absl import flags
        from clients import bigquery_client
        if not flags.FLAGS.is_parsed():
            flags.FLAGS(["loopback-check"])
        client = bigquery_client.CreateHttp()
        client.timeout = TIMEOUT
        if trust:
            client.ca_certs = trust
    elif transport == "gsutil":
        sys.path.insert(0, str(root / "platform/gsutil"))
        import gsutil  # noqa: F401: gsutil dependency bootstrap
        from gslib.utils import boto_util
        import boto
        if not boto.config.has_section("Boto"):
            boto.config.add_section("Boto")
        boto.config.setbool("Boto", "https_validate_certificates", True)
        default = boto_util.ConfigureCertsFile()
        boto_util.configured_certs_file = trust or default
        client = boto_util.GetNewHttp()
        client.timeout = TIMEOUT
    elif transport == "pip":
        from pip._internal.commands import create_command
        command = create_command("index")
        options, _ = command.parse_args(["versions", "pip"])
        client = command._build_session(options, retries=0, timeout=TIMEOUT)
        client.trust_env = False
        if trust:
            client.verify = trust
    else:
        raise ValueError(f"Not an HTTP transport: {transport}")
    try:
        def request(url):
            if transport in ("gcloud", "pip"):
                response = client.get(url, timeout=TIMEOUT)
                try:
                    return response.status_code, response.content == b"OK"
                finally:
                    response.close()
            response, body = client.request(url)
            return int(response.status), body == b"OK"
        yield request
    finally:
        close = getattr(client, "close", None)
        if close:
            close()


@contextlib.contextmanager
def grpc_server(directory):
    import grpc
    with ThreadPoolExecutor(max_workers=2) as pool:
        server = grpc.server(pool)
        handler = grpc.unary_unary_rpc_method_handler(lambda request, context: request)
        server.add_generic_rpc_handlers((grpc.method_handlers_generic_handler(
            "loopback.Probe", {"Echo": handler}),))
        credentials = grpc.ssl_server_credentials(((
            (directory / "server.key").read_bytes(),
            (directory / "server.crt").read_bytes()),))
        port = server.add_secure_port("127.0.0.1:0", credentials)
        if not port:
            raise RuntimeError("Cannot bind TLS gRPC server")
        server.start()
        try:
            yield port
        finally:
            server.stop(0).wait()


def error_detail(error):
    """pip diagnostic errors keep the TLS reason in a Rich Text context."""
    context = getattr(error, "context", None)
    plain = getattr(context, "plain", None)
    return f"{error}: {plain}" if plain else str(error)


def certificate_failure(error, hostname):
    """Only certificate-specific errors count; timeouts/refusals are failures."""
    detail = error_detail(error).lower()
    if hostname:
        indicators = ("hostname mismatch", "ip address mismatch", "not valid for",
                      "doesn't match", "does not match", "not in peer certificate",
                      "hostname verification check failed")
    else:
        indicators = ("unable to get local issuer", "unable to verify the first",
                      "self-signed certificate", "self signed certificate", "unknown ca")
    return any(indicator in detail for indicator in indicators)


def run_worker(root, transport):
    report = {"transport": transport, "python": sys.executable,
              "python_version": sys.version, "openssl": ssl.OPENSSL_VERSION,
              "sdk_root": str(root), "results": {}, "passed": False}
    try:
        with tempfile.TemporaryDirectory(prefix="tls-loopback-") as temporary:
            directory = Path(temporary)
            make_certificates(directory)
            server = grpc_server if transport == "grpc" else https_server
            with server(directory) as port:
                cases = (("default-untrusted", None, "localhost", False),
                         ("explicit-ca", str(directory / "ca.crt"), "localhost", True),
                         ("wrong-hostname", str(directory / "ca.crt"), "127.0.0.1", False))
                for name, trust, host, expect_success in cases:
                    try:
                        if transport == "grpc":
                            import grpc
                            roots = Path(trust).read_bytes() if trust else None
                            credentials = grpc.ssl_channel_credentials(root_certificates=roots)
                            with grpc.secure_channel(f"{host}:{port}", credentials) as channel:
                                response = channel.unary_unary("/loopback.Probe/Echo")(
                                    b"OK", timeout=TIMEOUT)
                            success = response == b"OK"
                        else:
                            with http_request(root, transport, trust) as request:
                                code, body_ok = request(f"https://{host}:{port}/")
                                success = code == 200 and body_ok
                        outcome = {"passed": expect_success and success,
                                   "result": "request completed", "response_ok": success}
                    except Exception as error:
                        outcome = {"passed": not expect_success and certificate_failure(
                            error, hostname=name == "wrong-hostname"),
                            "error": type(error).__name__, "detail": error_detail(error)}
                    report["results"][name] = outcome
        report["passed"] = all(item["passed"] for item in report["results"].values())
    except Exception as error:
        report["error"] = f"Unsupported or failed setup: {type(error).__name__}: {error}"
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sdk-root", type=Path)
    parser.add_argument("--transport", action="append", choices=TRANSPORTS)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.sdk_root:
        root = args.sdk_root.resolve()
    else:
        launcher = shutil.which("gcloud")
        if not launcher:
            parser.error("gcloud not on PATH; specify --sdk-root")
        root = Path(launcher).resolve().parent.parent
    transports = list(dict.fromkeys(args.transport or TRANSPORTS))
    if args.worker:
        if len(transports) != 1:
            parser.error("worker requires exactly one transport")
        report = run_worker(root, transports[0])
        print(json.dumps(report, indent=2))
        return 0 if report["passed"] else 1

    reports = []
    for transport in transports:
        report = {"transport": transport, "passed": False}
        try:
            with tempfile.TemporaryDirectory(prefix="sdk-transport-") as temporary:
                directory = Path(temporary)
                result = subprocess.run(worker_command(root, transport),
                                        env=sandbox_environment(directory), cwd=directory,
                                        capture_output=True, text=True, timeout=90)
            try:
                report = json.loads(result.stdout)
            except ValueError:
                report["error"] = "Unsupported runtime or worker did not emit JSON"
                report["stdout"] = result.stdout[-4000:]
            if result.stderr:
                report["diagnostics"] = result.stderr[-8000:]
            if result.returncode:
                report["passed"] = False
                report["returncode"] = result.returncode
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            report["error"] = f"Unsupported or failed runtime: {error}"
        reports.append(report)
    passed = all(report["passed"] for report in reports)
    print(json.dumps({"passed": passed, "transports": reports}, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
