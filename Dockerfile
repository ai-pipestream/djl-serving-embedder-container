# Pre-warmed DJL Serving container for embedding models
# This container pre-downloads and pre-converts the sentence-transformers models at build time
# so they're ready to serve immediately on startup using the optimized Rust engine.
#
# Build args:
#   VARIANT: cpu (default) or cuda
#   MODEL_ID: HuggingFace model ID (default: sentence-transformers/all-MiniLM-L6-v2)
#   MODEL_NAME: Model name for the endpoint (default: all-MiniLM-L6-v2)
#
# Usage:
#   CPU:  docker build -t pipestreamai/djl-serving-embedder:cpu .
#   CUDA: docker build -t pipestreamai/djl-serving-embedder:cuda --build-arg VARIANT=cuda .
#
# Custom model:
#   docker build -t pipestreamai/djl-serving-embedder:e5-small \
#     --build-arg MODEL_ID=intfloat/e5-small-v2 \
#     --build-arg MODEL_NAME=e5-small-v2 .

ARG VARIANT=cpu
ARG DJL_VERSION=0.31.0
ARG MODEL_ID=sentence-transformers/all-MiniLM-L6-v2
ARG MODEL_NAME=all-MiniLM-L6-v2

# ============================================================================
# Stage 1: CPU base
# ============================================================================
FROM deepjavalibrary/djl-serving:${DJL_VERSION}-cpu-full AS base-cpu

ARG DJL_VERSION

# Install conversion tools with CPU-only torch
RUN pip3 install torch --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install huggingface_hub transformers sentence-transformers onnx && \
    pip3 install https://publish.djl.ai/djl_converter/djl_converter-${DJL_VERSION}-py3-none-any.whl --no-deps && \
    pip3 cache purge

# ============================================================================
# Stage 2: CUDA base (uses lmi image which has CUDA torch)
# ============================================================================
FROM deepjavalibrary/djl-serving:${DJL_VERSION}-lmi AS base-cuda

ARG DJL_VERSION

# lmi image already has torch with CUDA, just add conversion tools
RUN pip3 install sentence-transformers onnx && \
    pip3 install https://publish.djl.ai/djl_converter/djl_converter-${DJL_VERSION}-py3-none-any.whl --no-deps && \
    pip3 cache purge

# ============================================================================
# Stage 3: Final image (selected by VARIANT)
# ============================================================================
FROM base-${VARIANT} AS final

ARG VARIANT
ARG MODEL_ID
ARG MODEL_NAME

# Set environment for caching
ENV HF_HOME=/tmp/.cache/huggingface
ENV TRANSFORMERS_CACHE=/tmp/.cache/huggingface/transformers
ENV DJL_CACHE_DIR=/tmp/.djl.ai
ENV SERVING_DOWNLOAD_DIR=/tmp/djl-download

# Create model directory
RUN mkdir -p /opt/ml/model && \
    mkdir -p /tmp/djl-download

# Pre-download and convert the model to Rust format at build time
# This eliminates the need for runtime conversion
RUN djl-convert --output-dir /opt/ml/model/${MODEL_NAME} \
    --output-format Rust \
    -m ${MODEL_ID}

# Add pooling configuration to the generated serving.properties
RUN echo 'pooling=mean' >> /opt/ml/model/${MODEL_NAME}/serving.properties && \
    echo 'batch_size=32' >> /opt/ml/model/${MODEL_NAME}/serving.properties

# Configure DJL Serving
RUN echo 'inference_address=http://0.0.0.0:8080' > /opt/djl/conf/config.properties && \
    echo 'management_address=http://0.0.0.0:8080' >> /opt/djl/conf/config.properties && \
    echo 'model_store=/opt/ml/model' >> /opt/djl/conf/config.properties && \
    echo 'load_models=ALL' >> /opt/djl/conf/config.properties

# Expose the serving port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/ping || exit 1

LABEL maintainer="pipestream"
LABEL description="Pre-warmed DJL Serving for sentence-transformers embeddings with Rust engine"
LABEL model="${MODEL_ID}"
LABEL model-name="${MODEL_NAME}"
LABEL variant="${VARIANT}"
LABEL engine="Rust"
