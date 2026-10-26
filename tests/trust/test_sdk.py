"""Offline SDK gate tests: python3 -m unittest discover -s tests/trust -p test_sdk.py -v."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

TRUST = Path(__file__).resolve().parents[2] / "packer/trust"
spec = importlib.util.spec_from_file_location("sdk", TRUST / "check-sdk.py")
sdk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdk)

# Public root copied verbatim from the legacy SDK bundle. Its fingerprint is
# pinned by the gate; no SDK download or network access is needed by these tests.
DIGICERT = """-----BEGIN CERTIFICATE-----
MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBH
MjAeFw0xMzA4MDExMjAwMDBaFw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IEcyMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/RrohCgiN9RlUyfuI
2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxpsMNzaHxmx
1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ
q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5Wz
tCO7TG1F8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQ
vIOlCsRnKPZzFBQ9RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAP
BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV
5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcNAQELBQADggEBAGBnKJRvDkhj6zHd6mcY
1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVnNeyIv/iPsGEMNKSuIEyExtv4
NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2ZL7tcu7XUIOGZX1NG
Fdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUTFy8bJZ91
8rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe
pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTfl
MrY=
-----END CERTIFICATE-----
"""


class SDKTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "VERSION").write_text("590.0.1\n")
        self.positive = (TRUST / "isrg-root-x1.crt").read_text()
        self.paths = []
        for pattern in sdk.EXPECTED:
            path = self.root / pattern.replace("python*", "python3.14")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(self.positive)
            self.paths.append(path)

    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            sdk.check(self.root)
        return output.getvalue()

    def test_clean_sdk_and_legacy_positive(self):
        self.assertEqual(sdk.trust.fingerprint(DIGICERT), sdk.DIGICERT_G2)
        for name in sdk.LEGACY:
            (self.root / name).write_text(DIGICERT)
        # Malformed delimiter examples in source are not certificates/stores.
        (self.root / "example.py").write_text(
            'pattern = "-----BEGIN CERTIFICATE-----.+-----END CERTIFICATE-----"')
        output = self.run_gate()
        self.assertIn("12 CA bundles qualified", output)
        self.assertEqual(output.count("ISRG absent; own pinned DigiCert"), 2)
        self.assertIn("SDK transport/default runtime trust is not validated", output)
        for name in sdk.LEGACY:
            self.assertEqual((self.root / name).read_text(), DIGICERT)

    def test_version_floor_and_invalid_metadata(self):
        for version in ("590.0.1", "590.0.2", "591.0.0", "600.0.0"):
            (self.root / "VERSION").write_text(version)
            self.assertEqual(sdk.sdk_version(self.root), version)
        for version in ("590.0.0", "589.99.99", "invalid", "590.0.1-0", "590.0.1\nother"):
            with self.subTest(version=version):
                (self.root / "VERSION").write_text(version)
                with self.assertRaises(ValueError):
                    sdk.sdk_version(self.root)
        (self.root / "VERSION").unlink()
        with self.assertRaises(FileNotFoundError):
            sdk.sdk_version(self.root)

    def test_each_expected_bundle_required_and_nonempty(self):
        for path in self.paths:
            with self.subTest(path=path):
                path.unlink()
                with self.assertRaisesRegex(ValueError, "Missing expected"):
                    sdk.inventory(self.root)
                path.write_text("")
                with self.assertRaisesRegex(ValueError, "Empty CA bundle"):
                    sdk.inventory(self.root)
                path.write_text(self.positive)

    def test_contamination_scanned_anywhere_including_txt_and_python_roots(self):
        locations = [self.paths[-2], self.paths[-1],
                     self.root / "arbitrary.txt", self.root / "unknown.extension",
                     self.root / "tests/fixture.pem"]
        for anchor in (TRUST / "roots").glob("*.crt"):
            for path in locations:
                with self.subTest(anchor=anchor, path=path):
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(self.positive + anchor.read_text())
                    with self.assertRaisesRegex(ValueError, "Affected root"):
                        sdk.inventory(self.root)
                    if path in self.paths:
                        path.write_text(self.positive)
                    else:
                        path.unlink()

    def test_additional_bundle_and_malformed_store(self):
        path = self.root / "new-client/roots.pem"
        path.parent.mkdir()
        path.write_text(self.positive)
        bundles, _ = sdk.inventory(self.root)
        self.assertIn(path, bundles)
        path.write_text(self.positive + "\n-----BEGIN CERTIFICATE-----\nbroken\n")
        with self.assertRaisesRegex(ValueError, "Malformed CA bundle"):
            sdk.inventory(self.root)

    def test_no_positive_control_is_not_silently_skipped(self):
        for name in (next(iter(sdk.LEGACY)), "lib/third_party/certifi/cacert.pem"):
            path = self.root / name
            path.write_text(DIGICERT if name not in sdk.LEGACY else
                            next((TRUST / "chains").glob("*.pem")).read_text())
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, "Missing clean .*positive control"):
                    self.run_gate()
            path.write_text(self.positive)

    def test_discovery_resolves_symlink_without_running_gcloud(self):
        binary = self.root / "bin/gcloud"
        binary.parent.mkdir()
        binary.write_text("#!/bin/sh\nexit 99\n")
        link = self.root / "gcloud-link"
        link.symlink_to(binary)
        with patch.object(sdk.shutil, "which", return_value=str(link)), \
                patch.object(sdk.subprocess, "run", side_effect=AssertionError("must not run")):
            self.assertEqual(sdk.sdk_root(), self.root.resolve())
        with patch.object(sdk.shutil, "which", return_value=None):
            with self.assertRaisesRegex(ValueError, "specify --sdk-root"):
                sdk.sdk_root()
        self.assertEqual(sdk.sdk_root(self.root), self.root.resolve())

    def test_verifier_flags_and_non_issuer_failure_rejected(self):
        chain = next((TRUST / "chains").glob("*.pem"))
        bundle = self.paths[0]
        with patch.object(sdk.subprocess, "run") as run:
            sdk.verify(bundle, chain, chain.stem, chain=True)
            command = run.call_args.args[0]
            for flag in ("-no-CApath", "-no-CAstore", "sslserver", chain.stem, sdk.CAPTURE_TIME):
                self.assertIn(flag, command)
        certs = {sdk.ISRG: self.positive}
        for result in (subprocess.CompletedProcess([], 0, "accepted", ""),
                       subprocess.CompletedProcess([], 2, "", "error 10 certificate expired")):
            with patch.object(sdk, "verify", side_effect=[
                    subprocess.CompletedProcess([], 0, "OK", ""), result]):
                with self.assertRaisesRegex(ValueError, "Expected unknown issuer"):
                    sdk.check_bundle(self.root, bundle, certs, [chain], self.root)

    def test_failed_positive_control_is_fatal(self):
        with patch.object(sdk, "verify", return_value=
                          subprocess.CompletedProcess([], 2, "", "verification failed")):
            with self.assertRaisesRegex(ValueError, "Positive control failed"):
                sdk.check_bundle(self.root, self.paths[0], {sdk.ISRG: self.positive},
                                 [], self.root)

    def test_broken_incident_fixtures_cannot_make_negatives_pass(self):
        with patch.object(sdk, "verify", return_value=
                          subprocess.CompletedProcess([], 2, "", "error 20")):
            with self.assertRaisesRegex(ValueError, "Incident fixture/control failed"):
                sdk.fixtures(self.root)


if __name__ == "__main__":
    unittest.main()
