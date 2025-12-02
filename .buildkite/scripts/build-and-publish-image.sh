#!/bin/bash
set -euo pipefail

# Build and publish a GCP VM image
# Usage: ./build-and-publish-image.sh <arch>

ARCH=$1
PROJECT_ID="${GCP_PROJECT_ID:-buildkite-gcp-stack}"
BUILD_ZONE="${GCP_BUILD_ZONE:-us-central1-a}"
BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-local}"
COMMIT="${BUILDKITE_COMMIT:-unknown}"

echo "--- :hammer: Building ${ARCH} image"
echo "Project: ${PROJECT_ID}"
echo "Zone: ${BUILD_ZONE}"
echo "Build: ${BUILD_NUMBER}-${COMMIT:0:7}"

# Change to packer directory and run build
cd packer
./build \
  --project-id "$PROJECT_ID" \
  --arch "$ARCH" \
  --build-number "${BUILD_NUMBER}-${COMMIT:0:7}" \
  --zone "$BUILD_ZONE"

echo "--- :earth_americas: Making image public"

# Get the actual image name that was created (format: buildkite-ci-stack-ARCH-YYYY-MM-DD-HHMM)
# Look for images created in the last 5 minutes
# Use portable date syntax that works on both macOS (BSD) and Linux (GNU)
if date -v -5M &>/dev/null; then
  # macOS/BSD date
  FIVE_MIN_AGO=$(date -u -v -5M '+%Y-%m-%dT%H:%M:%S')
else
  # GNU date
  FIVE_MIN_AGO=$(date -u -d '5 minutes ago' '+%Y-%m-%dT%H:%M:%S')
fi

IMAGE_NAME=$(gcloud compute images list \
  --project="$PROJECT_ID" \
  --filter="name:buildkite-ci-stack-${ARCH} AND creationTimestamp>$FIVE_MIN_AGO" \
  --format="value(name)" \
  --sort-by="~creationTimestamp" \
  --limit=1)

if [[ -z "$IMAGE_NAME" ]]; then
  echo "Error: Could not find newly created image for ${ARCH}"
  echo "Searching for any recent buildkite-ci-stack-${ARCH} images:"
  gcloud compute images list \
    --project="$PROJECT_ID" \
    --filter="name:buildkite-ci-stack-${ARCH}" \
    --format="table(name,creationTimestamp)" \
    --sort-by="~creationTimestamp" \
    --limit=5
  exit 1
fi

echo "Found image: $IMAGE_NAME"

# Make the image public
echo "Granting public access to $IMAGE_NAME"
gcloud compute images add-iam-policy-binding "$IMAGE_NAME" \
  --project="$PROJECT_ID" \
  --member="allAuthenticatedUsers" \
  --role="roles/compute.imageUser"

# Add image to family for easy reference
echo "Adding image to family buildkite-ci-stack-${ARCH}"
gcloud compute images update "$IMAGE_NAME" \
  --project="$PROJECT_ID" \
  --family="buildkite-ci-stack-${ARCH}"

# Export image name for later steps
echo "Exporting image name for downstream steps"
mkdir -p .buildkite
echo "$IMAGE_NAME" > ".buildkite/${ARCH}-image-name.txt"

# Set buildkite metadata if running in Buildkite
if [[ -n "${BUILDKITE:-}" ]]; then
  buildkite-agent meta-data set "${ARCH}-image-name" "$IMAGE_NAME"
fi

echo "--- :white_check_mark: Successfully built and published ${ARCH} image: $IMAGE_NAME"
