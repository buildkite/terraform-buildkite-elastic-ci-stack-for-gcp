"""Offline regression tests; run with python3 -m unittest discover -s tests/trust."""
import importlib.util
import re
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TRUST = ROOT / "packer/trust"
spec = importlib.util.spec_from_file_location("trust", TRUST / "check-trust.py")
trust = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trust)


class TrustTests(unittest.TestCase):
    def test_fixture_fingerprints(self):
        self.assertEqual(
            {trust.fingerprint(p.read_text()) for p in (TRUST / "roots").glob("*.crt")},
            trust.BLOCKED,
        )
        self.assertEqual(
            trust.fingerprint((TRUST / "isrg-root-x1.crt").read_text()),
            "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6",
        )

    def test_contaminated_bundle_rejected_and_sanitized(self):
        import subprocess
        control = (TRUST / "isrg-root-x1.crt").read_text()
        roots = "\n".join(p.read_text() for p in (TRUST / "roots").glob("*.crt"))
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "cacert.pem"
            bundle.write_text(control + roots)
            # Prove the archived chains really validate before removing trust;
            # otherwise malformed fixtures could make every negative pass.
            for chain in sorted((TRUST / "chains").glob("*.pem")):
                result = subprocess.run(
                    ["openssl", "verify", "-attime", "1792497600", "-no-CApath",
                     "-no-CAstore", "-CAfile", str(bundle), "-untrusted", str(chain), str(chain)],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            with self.assertRaisesRegex(AssertionError, "Affected root"):
                trust.check(bundle)
            subprocess.run(["python3", str(TRUST / "check-trust.py"), "--sanitize", str(bundle)], check=True)
            self.assertEqual(trust.PEM.findall(bundle.read_text()), [control.strip()])
            # Re-running the remediation must be safe.
            subprocess.run(["python3", str(TRUST / "check-trust.py"), "--sanitize", str(bundle)], check=True)

    def test_empty_bundle_rejected(self):
        with tempfile.NamedTemporaryFile() as file:
            with self.assertRaisesRegex(AssertionError, "Empty CA bundle"):
                trust.check(Path(file.name))

    def test_agent_pin_and_oldstable(self):
        installer = (ROOT / "packer/linux/scripts/install-buildkite-agent").read_text()
        version = re.search(r"^AGENT_VERSION=(\d+)\.(\d+)\.(\d+)$", installer, re.M)
        self.assertIsNotNone(version)
        self.assertGreaterEqual(tuple(map(int, version.groups())), (3, 138, 2))
        self.assertLess(tuple(map(int, version.groups())), (4, 0, 0))
        package = re.search(r"^AGENT_PACKAGE_VERSION=(.+)$", installer, re.M).group(1)
        self.assertTrue(package.startswith(version.group(0).split("=")[1] + "-"))
        self.assertIn('"buildkite-agent=${AGENT_PACKAGE_VERSION}"', installer)
        self.assertIn("buildkite-agent oldstable main", installer)
        self.assertNotIn("buildkite-agent stable main", installer)

    def test_trust_provisioned_before_downloads(self):
        packer = (ROOT / "packer/linux/buildkite-vm-image.pkr.hcl").read_text()
        self.assertLess(packer.index('source      = "../trust"'), packer.index('scripts/remediate-trust'))
        self.assertLess(packer.index("scripts/remediate-trust"), packer.index("scripts/install-utils"))
        goss = (ROOT / "goss.yaml").read_text()
        self.assertIn("/usr/local/share/buildkite-trust/check-image:", goss)
        self.assertIn('agent_version = replace(local.agent_version, ".", "-")', packer)
        import subprocess
        result = subprocess.run(
            ["bash", str(ROOT / "packer/build"), "--agent-version", "4.0.0"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must match installer version", result.stdout)

    def test_image_version_gates(self):
        import os
        import subprocess
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            # Exercise real dpkg version semantics (including apt build suffixes)
            # while replacing only installed package/binary discovery and trust.
            for name, script in {
                "dpkg-query": '#!/bin/sh\ncase "$*" in *ca-certificates*) echo 20250419+deb13u1;; *) echo "$TEST_AGENT";; esac\n',
                "buildkite-agent": '#!/bin/sh\necho "buildkite-agent version $TEST_BINARY"\n',
                "python3": '#!/bin/sh\nprintf "%s\\n" /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt\n',
            }.items():
                path = directory / name
                path.write_text(script)
                path.chmod(0o755)
            for version, binary, passes in [
                ("3.138.1-15100", "3.138.1", False),
                ("3.138.2-15170", "3.138.2", True),
                ("3.139.0-16000", "3.139.0", True),
                ("4.0.0-16000", "4.0.0", False),
                ("3.138.2-15170", "3.138.1", False),
                ("3.138.2-15170", "4.0.0", False),
            ]:
                with self.subTest(version=version, binary=binary):
                    result = subprocess.run(
                        ["bash", str(TRUST / "check-image")], capture_output=True,
                        env={**os.environ, "PATH": str(directory) + os.pathsep + os.environ["PATH"],
                             "TEST_AGENT": version, "TEST_BINARY": binary},
                    )
                    self.assertEqual(result.returncode == 0, passes, result.stderr)


if __name__ == "__main__":
    unittest.main()
