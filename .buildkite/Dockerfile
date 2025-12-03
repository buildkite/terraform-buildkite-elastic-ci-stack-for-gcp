# Custom Docker image with both Packer and gcloud CLI for building GCP VM images
FROM hashicorp/packer:1.14

# Install dependencies for gcloud CLI
RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    curl \
    jq

# Install gcloud CLI
RUN curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/usr/local

# Add gcloud to PATH
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

# Verify installations
RUN packer version && gcloud version

# Set the working directory
WORKDIR /workspace

ENTRYPOINT [ "" ]
