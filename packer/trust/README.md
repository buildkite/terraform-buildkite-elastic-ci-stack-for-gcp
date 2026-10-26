# Image trust checks

The image build updates Debian system trust before downloading third-party
software, pins Buildkite Agent 4.7.0 (`4.7.0-15166`), and pins Google Cloud CLI
590.0.1 (`590.0.1-0`, including its GKE authentication plugin). Both x86-64 and
arm64 images use the existing module-v1/Agent-v4 release contract.

The builder uses Packer 1.16.2, compiled with Go 1.26.10, and requires Alpine
`ca-certificates` and `ca-certificates-bundle >=20261020-r0`. Its SDK installation
uses architecture-specific 590.0.1 archives and checks their pinned SHA-256
before extraction. These hashes were recorded from Google's HTTPS versioned
downloads, not a separately signed checksum manifest. Google's download page
lists different hashes for the unversioned archives.

## System trust

`remediate-trust` requires Debian `ca-certificates >=20250419+deb13u1`, persists
the incident root exclusions in `/etc/ca-certificates.conf`, and runs
`update-ca-certificates --fresh`. It installs the checkers and public fixtures
under `/usr/local/share/buildkite-trust`.

`check-image` checks the CA-package floor, the installed agent package and binary
versions (`>=4.7.0`, `<5`), and the system, Python-default, Debian certifi and pip
Requests CA bundles. It also runs `check-sdk.py` against the guest SDK. Debian's
certifi and pip use the system bundle; upstream SDK libraries have independent
stores and are checked separately. No SDK bundles are rewritten, and no custom
CA settings or verification bypasses are installed.

Agent upgrades must update the release and apt-build pins together. Renovate is
constrained to patched v4 and disabled for this dependency until it can update
both. Image labels are derived from the installer rather than a separate version
selector. No Buildkite CLI is installed.

## Offline SDK gate

```sh
python3 packer/trust/check-sdk.py --sdk-root /usr/lib/google-cloud-sdk
```

Without `--sdk-root`, the checker resolves `gcloud` on PATH without executing it.
It requires SDK 590.0.1 or later, all twelve known CA-store paths, and valid,
nonempty bundles. It scans certificate PEM blocks throughout the installation
for four blocked root fingerprints and checks additional named CA bundles too.

Each bundle must reject all twelve archived incident chains with unknown issuer
at fixed capture time `1792497600`, using server-auth purpose and the fixture's
hostname. A contaminated control must first accept those same chains, so broken
fixtures or expiry cannot make the negative checks pass. ISRG Root X1 is the
normal positive control. The two legacy bq httplib2 fallback files lack ISRG;
only those paths may instead use their fingerprint-pinned DigiCert Global Root
G2 as an explicitly reported root-loading control.

These checks use the system OpenSSL executable against bundle files. They do
not establish which store a runtime selects or replay the chains through each
SDK TLS implementation. The archived chains have no private keys and cannot
serve as loopback server certificates.

## Runtime TLS controls

```sh
# Debian guest: includes SDK bundled pip and gRPC.
python3 packer/trust/check-sdk-transports.py --sdk-root /usr/lib/google-cloud-sdk

# Alpine builder: these launchers select system Python.
python3 packer/trust/check-sdk-transports.py \
  --sdk-root /usr/local/google-cloud-sdk \
  --transport gcloud --transport httplib2 --transport bq --transport gsutil
```

The harness starts ephemeral loopback servers and runs each selected transport
in a separate process with isolated configuration and no inherited credentials,
proxy, Python, SDK or CA overrides. It requires rejection of an untrusted test
CA, success with that CA explicitly supplied, and rejection of a wrong hostname.
The gRPC test uses a real TLS HTTP/2 server and unary RPC rather than treating a
connection timeout as certificate rejection. No external network is needed.

The SDK launchers select the interpreter for gcloud, httplib2, bq and gsutil.
The pip and gRPC checks require the SDK's bundled Python. The Linux archives'
glibc interpreter cannot run in the Alpine builder, where it is dormant; asking
for these modes there fails rather than silently switching to another runtime.
These tests cover transport controls, not every CLI flag, mTLS mode or customer
configuration override.

Goss runs both the offline guest gate and runtime controls on actual test
instances. The image-build script runs the builder's system, SDK-bundle and
selected transport checks before invoking Packer or gcloud.

## Local tests

```sh
python3 -m unittest discover -s tests/trust -v
```

The suite needs Python 3, OpenSSL 3+ and Debian `dpkg` for the version tests.
Both CI pipelines run it in `python:3.12-bookworm` without cloud credentials.
The optional `check-trust.py --sanitize` mode is exercised only on disposable
test bundles; provisioning never applies it to an SDK installation.

## Qualification and release status

Google's [590.0.1 release notes](https://docs.cloud.google.com/sdk/docs/release-notes)
explicitly update certifi, bundled pip/gRPC, bq and gsutil certificate stores.
Local checks on 26 October 2026 verified the following without cloud credentials:

- Both Debian SDK package hashes matched their architecture indices, and the
  indices matched Google's signed Release metadata. All twelve SDK bundles
  rejected the archived chains. The legacy bq fallback controls passed using
  DigiCert Global Root G2; effective bq defaults selected clean certifi.
- Actual gcloud Requests, httplib2, bq, initialized gsutil, vendored boto and
  bundled pip transports accepted ordinary Google HTTPS and rejected three
  representative live incident hosts on both architectures.
- All six loopback transport modes, including a real gRPC RPC, passed on both
  extracted Debian SDK packages. The builder's four selected modes passed on
  both locally built architectures. Builder system trust passed the offline
  checks, and Packer's Go build version was verified on both architectures.

These results qualify the tested packages and local builder environments, not
finished GCP images. Publication remains unconditionally blocked until actual
x86-64 and arm64 image builds pass Goss and lifecycle validation. Review the
builder archive checksum provenance above before approving publication. Remove
the publication stop only after those checks and release review; preserve the
module-v1/Agent-v4 family guard. Then publish verified images, update module
image pins, and plan controlled replacement of existing MIG workers.

The pre-existing Ops Agent TLS-verification finding is outside this remediation
and is not a release criterion. Customer containers, plugins, user-installed
runtimes, custom trust stores and verification overrides remain outside these
host-image checks. No GCP images or releases have been published by this work.

## Fixtures

The public fixtures come from <https://emudhra.we-have-a-problem.com/>, captured
20 October 2026. They were copied from the AWS stack's trust checks at commit
`430da796`. `roots/*.crt` pins the four published incident anchors by SHA-256 DER
fingerprint, and `chains/*.pem` contains the twelve published TLS chains. ISRG
Root X1 is a fingerprint-pinned positive control from
<https://letsencrypt.org/certs/isrgrootx1.pem>. No credentials or private keys are
stored in this directory.
