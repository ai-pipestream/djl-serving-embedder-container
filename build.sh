#!/bin/bash
set -e

# Build and optionally push the pre-warmed DJL Serving embedder container
#
# Usage:
#   ./build.sh                          # Build CPU image with default model
#   ./build.sh cuda                     # Build CUDA image
#   ./build.sh cpu 1.0.0                # Build CPU with version tag
#   ./build.sh cuda 1.0.0 intfloat/e5-small-v2 e5-small-v2  # Custom model

IMAGE_NAME="pipestreamai/djl-serving-embedder"
VARIANT="${1:-cpu}"
VERSION="${2:-latest}"
MODEL_ID="${3:-sentence-transformers/all-MiniLM-L6-v2}"
MODEL_NAME="${4:-all-MiniLM-L6-v2}"

# Construct full tag
if [ "${VARIANT}" = "cpu" ]; then
    FULL_TAG="${IMAGE_NAME}:${VERSION}"
else
    FULL_TAG="${IMAGE_NAME}:${VERSION}-${VARIANT}"
fi

echo "Building DJL Serving Embedder image"
echo "  Image: ${FULL_TAG}"
echo "  Variant: ${VARIANT}"
echo "  Model: ${MODEL_ID}"
echo "  Model Name: ${MODEL_NAME}"
echo ""

# Build the image
docker build \
    --build-arg VARIANT="${VARIANT}" \
    --build-arg MODEL_ID="${MODEL_ID}" \
    --build-arg MODEL_NAME="${MODEL_NAME}" \
    -t "${FULL_TAG}" .

# Also tag as latest variant if a version was specified
if [ "${VERSION}" != "latest" ]; then
    if [ "${VARIANT}" = "cpu" ]; then
        docker tag "${FULL_TAG}" "${IMAGE_NAME}:latest"
    else
        docker tag "${FULL_TAG}" "${IMAGE_NAME}:latest-${VARIANT}"
    fi
fi

echo ""
echo "Build complete!"
echo ""
echo "To run locally:"
echo "  docker run -p 8080:8080 ${FULL_TAG}"
echo ""
echo "To push to Docker Hub:"
echo "  docker push ${FULL_TAG}"
if [ "${VERSION}" != "latest" ]; then
    if [ "${VARIANT}" = "cpu" ]; then
        echo "  docker push ${IMAGE_NAME}:latest"
    else
        echo "  docker push ${IMAGE_NAME}:latest-${VARIANT}"
    fi
fi
echo ""
echo "To test embeddings:"
echo "  curl -X POST http://localhost:8080/predictions/${MODEL_NAME//-/_} \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"inputs\": \"Hello world\"}'"
