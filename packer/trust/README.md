# Partial eMudhra remediation (20 October 2026)

**Not release-ready. Google Cloud SDK trust in the guest and builder remains a
review/release blocker.** Updating the SDK alone does not remove all affected
bundled roots. No speculative SDK bundle edits, redirects or custom CA settings
are included here.

## Source and scope

Source: <https://emudhra.we-have-a-problem.com/> (consulted 21 October 2026).
Fixtures and validator originate from `buildkite/elastic-ci-stack-for-aws`, branch
`fix/emudhra-trust-remediation`, commit `430da796` (copied with `git archive`).
`roots/*.crt` are the four public incident anchors from `roots.json`, pinned by
SHA-256 DER fingerprints. `chains/*.pem` are all twelve published TLS chains from
`chains.zip`, captured 20 October 2026. ISRG Root X1 is an unrelated positive
control from <https://letsencrypt.org/certs/isrgrootx1.pem>, fingerprint-pinned in
the tests. No credentials or private keys are included.

Both Debian 13 image architectures require `ca-certificates >=20250419+deb13u1`
and persistent incident root exclusions in `/etc/ca-certificates.conf`, followed
by `update-ca-certificates --fresh`, before third-party HTTPS downloads. The
validator checks all four roots, twelve rejected chains (specifically unknown
issuer/error 20) and the positive control at fixed capture time `1792497600`.
Contaminated-bundle tests first prove every archived chain validates, preventing
malformed fixtures or expiry from producing false negatives.

Agent installation retains the released module-v1/Agent-v4 contract and pins
**4.7.0**, exact stable apt package **4.7.0-15166**, available for amd64 and arm64.
Future updates must change both release and apt-build pins; Renovate is
constrained to patched v4 and disabled for this dependency until it can update
both together. The image's `agent_version` label is read directly from the
installer; the legacy build flag rejects contradictory labels. No Buildkite CLI
is installed or added. The recovered v3 work remains in branch history; no v0.x
maintenance release is being prepared in this change.

Debian's distro certifi and pip use `/etc/ssl/certs/ca-certificates.crt`; dormant
vendored pip PEM files are not necessarily effective trust stores. Do not install
upstream pip solely to match an advisory version. Image gates inspect system,
Python default, distro certifi and pip Requests effective bundle paths. SDK runtimes and their
bundles are **not** covered by that check.

## Validation

Credential-free tests (Python 3, OpenSSL 3+, and Debian `dpkg` for version tests):

```sh
python3 -m unittest discover -s tests/trust -v
```

For example, run those tests in `python:3.12-bookworm` with this checkout mounted.
Both CI pipelines run them without GCP credentials. Goss on both actual test
images runs `/usr/local/share/buildkite-trust/check-image`: CA package floor,
agent package and binary versions `>=4.7.0` and `<5`, and offline trust checks.
The optional validator `--sanitize` is exercised only on local test bundles here;
it is not wired to any SDK or runtime bundle.

Local continuation checks (21 October 2026): all eight trust unit tests passed
in `python:3.12-bookworm`; the six shell lifecycle/bootstrap harnesses passed
with gettext-base available. The systemd semantics test skipped because systemd
was not running. Changed shell scripts passed ShellCheck; Packer format and full
configuration validation passed for x86-64 and arm64 using a dummy project ID.
The arm64 4.7.0 apt package matched its repository SHA-256 and its binary reported
`4.7.0+15166.413a004b6a7aa607fa718fe2f64cc960c42d4419` in an isolated container.
These are local checks, not live GCP image or lifecycle qualification.

## Required before release

The published v1.1.0 release already targets Agent v4 (installer pin 4.5.0);
main pins 4.6.0. This change updates that existing major to patched 4.7.0,
retaining main's `cancel-signal-timeout=10s` and `cancel-cleanup-timeout=5s`.
The publish script preserves the v1/Agent-v4 family guard and **unconditionally
blocks publication while SDK trust is unqualified**, before metadata lookup or
cloud mutation. Do not remove that release stop until guest and builder SDK
trust pass qualification. No downstream SDK bundle workaround is planned;
wait for and verify an upstream fix.

- Resolve and validate guest **and builder Google Cloud SDK** trust, including
  independent certifi, pip/grpc, gsutil/boto and httplib2 stores/fallbacks. The
  Alpine/Packer builder's system trust is also unverified in this change.
- Build and run actual GCP image/lifecycle validation on **both architectures**;
  local tests are not evidence of GCP lifecycle behavior.
- Separately review upstream Ops Agent 2.72.0 `confgenerator/logging.go`, which
  generates Fluent Bit `tls.verify Off`. Do not hand-edit generated files; this
  separate TLS-verification concern is not fixed here.
- Publish verified images, then update module image pins in a separate change.
  Existing published-image pins are intentionally unchanged. No images or
  releases are published by this draft work.

Removing roots also distrusts unrelated certificates beneath them. Customer
containers, plugins, custom CA stores, TLS overrides and user-installed runtimes
are outside this host system-trust change. This is not complete remediation.

## SDK qualification evidence (21 October 2026)

Google Cloud CLI amd64 Debian package `590.0.0-0` contains the release-noted
pyOpenSSL 26.4.0 and cryptography 50.0.1, but its main certifi copy reports
2026.02.25 and still includes the incident emSign ECC root. Its certifi and
vendored boto bundles validate representative archived incident chains offline.
The release notes do not explicitly claim eMudhra remediation.

An isolated, network-disabled amd64 Docker inspection executed the SDK's own
bundled Python 3.14.8 (Python ssl linked to OpenSSL 3.5.9). The real gcloud
Requests session's selected adapter SSLContext had certificate and hostname
verification enabled, but loaded the incident emSign ECC root from SDK certifi.
Reconstructing a PyOpenSSL store from those loaded roots accepted six non-AAA
incident chains and rejected six AAA variants at the fixed capture time; the
ISRG positive control passed. **This was not an end-to-end SDK handshake test**:
PyOpenSSL used a different OpenSSL build (4.0.2), and the reconstructed store did
not reproduce every adapter verification flag. This evidence does not qualify
gsutil, bq, pip, grpc, arm64, or the builder.

A candidate upstream SDK fix must be qualified in the exact guest and builder
environments on both architectures, without cloud credentials:

1. Record versions, effective trust paths, adapter contexts, and default/override
   behavior for gcloud Requests/httplib2, gsutil/boto, bq, bundled pip and grpc.
   Include fallback stores; file presence alone does not establish effective use.
2. Require all twelve archived chains to fail with issuer rejection at the fixed
   capture time through each effective verifier. Preserve server-auth purpose,
   hostname and verification flags; do not silently substitute another TLS
   library. Require the unrelated positive control to pass and contaminated
   control to accept the chains, excluding fixture/setup failures.
3. Exercise actual transports against a loopback-only TLS server with ephemeral
   test certificates to verify trust routing and hostname checking. Archived
   incident chains have no private keys and cannot back this test server.
4. Re-run the host trust gates and actual GCP lifecycle tests before publication.

## Separate Ops Agent finding

Ops Agent 2.72.0 release source `confgenerator/logging.go` and its Linux golden
runtime configuration generate `tls On` with `tls.verify Off` for application
and self-log Stackdriver outputs. Its systemd service regenerates these files
at startup. The pinned Fluent Bit implementation maps disabled verification to
`SSL_VERIFY_NONE`; encryption alone does not authenticate the logging endpoint.
Hostname verification is a separate setting and also defaults off.

No documented Ops Agent 2.72 logging-output TLS override was found. Underlying
Fluent Bit settings are not exposed as supported Ops Agent YAML options here.
Seek an official Google remedy; do not patch generated runtime files or present
an experimental logging backend as a supported fix. This is a separate concern,
not proof of interception or a claim about every Ops Agent connection. Actual
GCP runtime configuration has not been checked by this local work.
