# Packer and Google Cloud CLI for building GCP VM images.
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:590.0.1-alpine@sha256:59ba5e37c389a180e2621fe4a3c229cdb1eb3b41b3328b1b8af481a368bbed7c AS cloud-cli
FROM hashicorp/packer:1.16.2

# Keep the builder's CA certificates on the patched trust store.
RUN apk add --no-cache --upgrade \
    'ca-certificates>=20261020-r0' \
    'ca-certificates-bundle>=20261020-r0' \
    python3 \
    py3-pip \
    bash \
    curl \
    jq \
    && update-ca-certificates

# The multi-architecture image digest pins both SDK variants. Renovate updates
# the version and digest together, without separate archive checksum pins.
COPY --from=cloud-cli /google-cloud-sdk /usr/local/google-cloud-sdk

# SDK launchers use system Python on Alpine, not the bundled glibc Python.
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

# Check that each CLI starts without credentials.
RUN packer version && gcloud version && gsutil version && bq version

WORKDIR /workspace

ENTRYPOINT [ "" ]
