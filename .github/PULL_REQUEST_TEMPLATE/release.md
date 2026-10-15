<!--
Release pull request template. Follow the Release Process section of CONTRIBUTING.md.

- Title this pull request "Release vX.Y.Z".
- Replace every vX.Y.Z, vA.B.C and X below.
- This pull request only changes versions. Merge feature changes and default image updates before opening it.
-->

## Release vX.Y.Z

- **Previous release:** vA.B.C
- **Release type:** <!-- major, minor or patch -->
- **Changes since the previous release:** <https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-gcp/compare/vA.B.C...main>

### Why this version

<!-- Name the changes that decide the release type, using the table in CONTRIBUTING.md. -->

### Every release

- [ ] `modules/compute/main.tf`: `stack_version = "vX.Y.Z"`, exactly matching the tag, including the leading `v`
- [ ] Nothing else in this pull request changes module behavior
- [ ] Default image: nothing under `packer/`, `templates/` or `goss.yaml` changed since vA.B.C, **or** the default `image` already points at an image published by a `main` build of the image-builder pipeline that includes those changes. Image build: <!-- link, or "not needed" -->
- [ ] The `image` defaults in `variables.tf` and `examples/compute/variables.tf` are identical

### Major releases only

<!-- Delete this section for minor and patch releases. -->

- [ ] `README.md`: the module example uses `version = "~> X.0"`
- [ ] `MODULE_MAJOR_VERSION="vX"` in `.buildkite/scripts/publish-image` is already on `main`, and the default image belongs to the `buildkite-ci-stack-vX-x86-64` family
- [ ] `docs/upgrading-to-vX.md` exists and `README.md` links to it
- [ ] Image family names in `docs/image-release-pipeline.md` use `vX`

### After merging

- [ ] Draft the GitHub release `vX.Y.Z`, targeting this pull request's merge commit, with generated notes. For a major release, start the notes with an upgrade callout that links `docs/upgrading-to-vX.md`.
- [ ] Publish the release. This creates the tag, and the Terraform Registry publishes the version.
- [ ] `vX.Y.Z` appears on the [Terraform Registry](https://registry.terraform.io/modules/buildkite/elastic-ci-stack-for-gcp/buildkite)
