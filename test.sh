#!/bin/bash
set -e

# Test script for the DJL Serving Embedder container
# Usage:
#   ./test.sh              # Test CPU image
#   ./test.sh cuda         # Test CUDA image

VARIANT="${1:-cpu}"

if [ "${VARIANT}" = "cpu" ]; then
    IMAGE_NAME="pipestreamai/djl-serving-embedder:latest"
else
    IMAGE_NAME="pipestreamai/djl-serving-embedder:latest-${VARIANT}"
fi

CONTAINER_NAME="djl-embedder-test-${VARIANT}"
PORT=8080

# Cleanup any existing container
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

echo "Starting DJL Serving Embedder container (${VARIANT})..."
echo "Image: ${IMAGE_NAME}"

if [ "${VARIANT}" = "cuda" ]; then
    docker run -d --name ${CONTAINER_NAME} -p ${PORT}:8080 --gpus all ${IMAGE_NAME}
else
    docker run -d --name ${CONTAINER_NAME} -p ${PORT}:8080 ${IMAGE_NAME}
fi

# Wait for container to be healthy
echo "Waiting for container to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:${PORT}/ping > /dev/null 2>&1; then
        echo "Container is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "  Attempt ${ATTEMPT}/${MAX_ATTEMPTS}..."
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "ERROR: Container failed to become ready"
    docker logs ${CONTAINER_NAME}
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
    exit 1
fi

# Test health endpoint
echo ""
echo "Testing health endpoint..."
curl -s http://localhost:${PORT}/ping | head -c 500
echo ""

# Test single embedding (model name uses underscores in endpoint)
echo ""
echo "Testing single embedding..."
RESPONSE=$(curl -s -X POST http://localhost:${PORT}/predictions/all_MiniLM_L6_v2 \
    -H 'Content-Type: application/json' \
    -d '{"inputs": "Hello world"}')

DIMENSION=$(echo $RESPONSE | tr ',' '\n' | wc -l)
echo "Response dimension: ${DIMENSION}"
echo "Response (first 200 chars): ${RESPONSE:0:200}..."

# Test batch embeddings
echo ""
echo "Testing batch embeddings..."
BATCH_RESPONSE=$(curl -s -X POST http://localhost:${PORT}/predictions/all_MiniLM_L6_v2 \
    -H 'Content-Type: application/json' \
    -d '{"inputs": ["Hello world", "This is a test", "Machine learning is powerful"]}')

echo "Batch response length: ${#BATCH_RESPONSE} characters"
echo "Batch response (first 200 chars): ${BATCH_RESPONSE:0:200}..."

# Cleanup
echo ""
echo "Cleaning up..."
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

echo ""
echo "Test complete!"
