#!/usr/bin/env python3
"""Credential-free, read-only SDK bundle gate (not a runtime transport test).

Usage: python3 check-sdk.py [--sdk-root /usr/lib/google-cloud-sdk]
Without --sdk-root, resolve bin/gcloud on PATH; never execute SDK code. Requires
OpenSSL 3+. VERSION must be >=590.0.1. Scan certificate PEM blocks anywhere in
the tree, regardless of suffix, and qualify expected and additional CA bundles.

All verification uses fixed capture time and isolated CAfile trust. Incident
leaves use server-auth purpose and their fixture hostname. Positive controls are
CA certificates, not HTTPS leaves, so leaf purpose/hostname checks do not apply.
The two legacy bq httplib2 fallbacks may lack ISRG Root X1: explicitly report this
and verify their own fingerprint-pinned DigiCert Global Root G2 instead. This is
a narrower root-loading control, not evidence of a working ordinary HTTPS path.
No bundles are changed, no configuration overrides or credentials are used, and
SDK runtime trust routing, TLS engines and system/default stores remain outside
this file scanner's scope.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("sdk_trust", ROOT / "check-trust.py")
trust = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trust)

MIN_VERSION = (590, 0, 1)
CAPTURE_TIME = "1792497600"
ISRG = "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6"
DIGICERT_G2 = "cb3ccbb76031e5e0138f8dd39a23f9de47ffc35e43c1144cea27d46a5ab1cb5f"
LEGACY = {
    f"platform/bq/third_party/httplib2/python{v}/cacerts.txt" for v in (2, 3)
}
EXPECTED = (
    "lib/third_party/botocore/cacert.pem",
    "lib/third_party/certifi/cacert.pem",
    "lib/third_party/httplib2/python2/httplib2/cacerts.txt",
    "lib/third_party/httplib2/python3/httplib2/cacerts.txt",
    "platform/bq/third_party/certifi/cacert.pem",
    *sorted(LEGACY),
    "platform/gsutil/gslib/data/cacerts.txt",
    "platform/gsutil/gslib/vendored/boto/boto/cacerts/cacerts.txt",
    "platform/gsutil/third_party/certifi/certifi/cacert.pem",
    "platform/bundledpythonunix/lib/python*/site-packages/grpc/_cython/_credentials/roots.pem",
    "platform/bundledpythonunix/lib/python*/site-packages/pip/_vendor/certifi/cacert.pem",
)
CA_NAMES = {"cacert.pem", "cacerts.pem", "cacert.txt", "cacerts.txt", "roots.pem"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sdk_root(explicit=None):
    if explicit is not None:
        root = Path(explicit).resolve()
    else:
        gcloud = shutil.which("gcloud")
        require(gcloud, "gcloud not found on PATH; specify --sdk-root")
        root = Path(gcloud).resolve().parent.parent
    require(root.is_dir(), f"SDK root is not a directory: {root}")
    return root


def sdk_version(root):
    version = (root / "VERSION").read_text().strip()
    require(re.fullmatch(r"\d+\.\d+\.\d+", version), f"Invalid SDK VERSION: {version!r}")
    require(tuple(map(int, version.split("."))) >= MIN_VERSION,
            f"SDK {version} is below required 590.0.1")
    return version


def inventory(root):
    """Scan all PEM-bearing files; require known stores even if empty/missing."""
    expected = set()
    for pattern in EXPECTED:
        matches = list(root.glob(pattern))
        require(matches and all(p.is_file() for p in matches),
                f"Missing expected SDK CA bundle: {pattern}")
        expected.update(matches)
    bundles = {}
    pem_files = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        # Binary libraries can embed PEM too; do not restrict the scan to .pem.
        data = path.read_bytes()
        if b"-----BEGIN CERTIFICATE-----" not in data:
            require(path not in expected and path.name not in CA_NAMES,
                    f"Empty CA bundle: {path}")
            continue
        # Source files also contain PEM delimiters in regexes and examples.
        # Only actual base64-shaped PEM blocks belong in the fingerprint scan;
        # expected/named stores additionally reject unmatched or invalid blocks.
        certs = [cert for cert in trust.PEM.findall(data.decode("utf-8", errors="replace"))
                 if re.fullmatch(r"-----BEGIN CERTIFICATE-----\s+[A-Za-z0-9+/=\s]+"
                                 r"-----END CERTIFICATE-----", cert)]
        relative = path.relative_to(root)
        if certs:
            pem_files += 1
            fingerprints = {trust.fingerprint(cert): cert for cert in certs}
            require(not (fingerprints.keys() & trust.BLOCKED), f"Affected root in {path}")
        else:
            fingerprints = {}
        # Test certificates are scanned for blocked roots but are not CA stores.
        fixture = any(part in {"test", "tests", "dummyserver"} for part in relative.parts)
        if path in expected or (path.name in CA_NAMES and not fixture):
            require(certs, f"Empty CA bundle: {path}")
            require(data.count(b"-----BEGIN CERTIFICATE-----") == len(certs),
                    f"Malformed CA bundle: {path}")
            bundles[path] = fingerprints
    require(expected <= bundles.keys(), "Expected SDK bundles were not scanned")
    return bundles, pem_files


def verify(bundle, certificate, hostname=None, chain=False):
    command = ["openssl", "verify", "-attime", CAPTURE_TIME,
               "-no-CApath", "-no-CAstore", "-CAfile", str(bundle)]
    if hostname:
        command += ["-purpose", "sslserver", "-verify_hostname", hostname]
    if chain:
        command += ["-untrusted", str(certificate)]
    return subprocess.run(command + [str(certificate)], text=True,
                          capture_output=True, check=False)


def fixtures(directory):
    """Prove incident fixtures work with their anchors, purpose and hostname."""
    chains = sorted((ROOT / "chains").glob("*.pem"))
    require(len(chains) == 12, "Expected exactly 12 incident chains")
    positive = ROOT / "isrg-root-x1.crt"
    require(trust.fingerprint(positive.read_text()) == ISRG, "Invalid ISRG control")
    anchors = [p.read_text() for p in sorted((ROOT / "roots").glob("*.crt"))]
    require({trust.fingerprint(pem) for pem in anchors} == trust.BLOCKED,
            "Invalid incident anchor fixtures")
    contaminated = directory / "contaminated.pem"
    contaminated.write_text(positive.read_text() + "\n".join(anchors))
    for chain in chains:
        result = verify(contaminated, chain, chain.stem, chain=True)
        require(result.returncode == 0,
                f"Incident fixture/control failed: {chain}: {result.stdout}{result.stderr}")
    return chains


def check_bundle(root, bundle, certificates, chains, directory):
    relative = str(bundle.relative_to(root))
    control = ROOT / "isrg-root-x1.crt"
    description = "ISRG Root X1 trusted"
    if ISRG not in certificates:
        require(relative in LEGACY,
                f"Missing clean ISRG positive control in {bundle}")
        require(DIGICERT_G2 in certificates,
                f"Missing clean DigiCert Global Root G2 positive control in {bundle}")
        control = directory / "digicert-g2.pem"
        control.write_text(certificates[DIGICERT_G2])
        description = "ISRG absent; own pinned DigiCert Global Root G2 trusted (legacy fallback)"
    result = verify(bundle, control)
    require(result.returncode == 0,
            f"Positive control failed for {bundle}: {result.stdout}{result.stderr}")
    for chain in chains:
        result = verify(bundle, chain, chain.stem, chain=True)
        require(result.returncode != 0 and "error 20 " in result.stderr,
                f"Expected unknown issuer for {bundle}, {chain.name}: {result.stdout}{result.stderr}")
    print(f"PASS: {relative}: blocked roots absent, 12 incident chains rejected; {description}")


def check(root):
    version = sdk_version(root)
    bundles, pem_files = inventory(root)
    with tempfile.TemporaryDirectory(prefix="sdk-trust-") as temporary:
        directory = Path(temporary)
        chains = fixtures(directory)
        for bundle, certificates in bundles.items():
            check_bundle(root, bundle, certificates, chains, directory)
    print(f"PASS: SDK {version}: {len(bundles)} CA bundles qualified; "
          f"{pem_files} PEM-bearing files scanned. Offline file/OpenSSL checks only; "
          "SDK transport/default runtime trust is not validated.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", type=Path)
    args = parser.parse_args()
    try:
        check(sdk_root(args.sdk_root))
    except (ValueError, OSError) as error:
        parser.exit(1, f"FAIL: {error}\n")


if __name__ == "__main__":
    main()
