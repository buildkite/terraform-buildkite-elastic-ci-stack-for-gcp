# Packer and Google Cloud CLI for building GCP VM images.
FROM hashicorp/packer:1.16.2

# Update CA certificates before downloading the SDK.
RUN apk add --no-cache --upgrade \
    'ca-certificates>=20261020-r0' \
    'ca-certificates-bundle>=20261020-r0' \
    python3 \
    py3-pip \
    bash \
    curl \
    jq \
    && update-ca-certificates

# Pin the SDK version and hashes from Google's versioned HTTPS downloads.
# These are locally recorded hashes, not signed upstream checksums.
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

# SDK launchers use system Python on Alpine, not the bundled glibc Python.
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

# Check that each CLI starts without credentials.
RUN packer version && gcloud version && gsutil version && bq version

WORKDIR /workspace

ENTRYPOINT [ "" ]
