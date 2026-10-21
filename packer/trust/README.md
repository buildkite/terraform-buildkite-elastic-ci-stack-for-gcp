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

Agent installation uses **v3 oldstable**, exact apt package `3.138.2-15170` for
amd64 and arm64. Future updates must change both release and apt-build pins;
Renovate is constrained to v3 and disabled for this dependency until it can
update the exact apt build suffix together with the release. The image's `agent_version` label is read directly
from the installer; the legacy build flag rejects contradictory labels. No Buildkite CLI is installed or added.

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
agent package and binary versions `>=3.138.2` and `<4`, and offline trust checks.
The optional validator `--sanitize` is exercised only on local test bundles here;
it is not wired to any SDK or runtime bundle.

## Required before release

Latest main now targets module v1/Agent v4, unlike the initial investigation
baseline. This draft deliberately implements the requested patched **v3** agent.
Its config uses v3's supported `cancel-grace-period=10` (9 seconds before SIGKILL),
not the v4-only cancellation keys. The publish script refuses to publish this v3
agent to the v1/Agent v4 families, before any cloud mutation. Resolve the intended
maintenance/release branch and family targeting before enabling publication;
this draft does not change families or claim compatibility with the v1 contract.

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
