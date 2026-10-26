# Custom Docker image with both Packer and gcloud CLI for building GCP VM images
# Packer 1.16.2 is built with Go 1.26.10; 1.16.1 used Go 1.26.8.
FROM hashicorp/packer:1.16.2

# Upgrade the base bundle as well as installing the CA update tooling. Enforce
# the patched Alpine CA floor before downloading third-party tools.
RUN apk add --no-cache --upgrade \
    'ca-certificates>=20261020-r0' \
    'ca-certificates-bundle>=20261020-r0' \
    python3 \
    py3-pip \
    openssl \
    bash \
    curl \
    jq \
    && update-ca-certificates

# Versioned downloads must not silently advance when Google publishes a release.
# SHA-256 values were recorded from Google's HTTPS versioned downloads. They
# pin these exact bytes; they are not separately signed upstream checksums.
# The download page's unversioned archives have different hashes.
RUN set -eu; \
    case "$(apk --print-arch)" in \
        x86_64) sdk_arch=x86_64; sdk_sha256=d1ae7be7e12c4e7d8286fab4774f5441020aca89dc7793ddacbace8d11d20f06 ;; \
        aarch64) sdk_arch=arm; sdk_sha256=fd760d8b1c2c4c484d7b659964994b07aaefddc6ac4350e681940477dbdbb22c ;; \
        *) echo 'Unsupported Google Cloud CLI architecture' >&2; exit 1 ;; \
    esac; \
    curl --fail --show-error --location --retry 3 \
        "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-590.0.1-linux-${sdk_arch}.tar.gz" \
        --output /tmp/google-cloud-cli.tar.gz; \
    echo "${sdk_sha256}  /tmp/google-cloud-cli.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/google-cloud-cli.tar.gz -C /usr/local; \
    rm /tmp/google-cloud-cli.tar.gz; \
    test "$(cat /usr/local/google-cloud-sdk/VERSION)" = 590.0.1

# The Linux archive ships glibc Python, not the optional musl component. On
# Alpine the SDK launchers select system Python; leave their selection intact.
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

# Verify installations without credentials or cloud operations.
RUN packer version && gcloud version && gsutil version && bq version

WORKDIR /workspace

ENTRYPOINT [ "" ]
