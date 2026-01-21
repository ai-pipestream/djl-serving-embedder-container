# DJL Serving Embedder Container

Pre-warmed Docker container for serving text embedding models using [DJL Serving](https://github.com/deepjavalibrary/djl-serving) with the optimized Rust inference engine.

## Features

- **Pre-converted models**: Models are converted to Rust format at build time for fastest startup
- **CPU and CUDA support**: Build for CPU-only or GPU-accelerated inference
- **Any HuggingFace model**: Supports any sentence-transformers compatible model
- **Optimized Rust engine**: Uses DJL's Rust engine for efficient text embedding inference
- **REST API**: Simple HTTP API for single and batch embeddings

## Quick Start

### Pull from Docker Hub

```bash
# CPU version (default model: all-MiniLM-L6-v2)
docker pull pipestreamai/djl-serving-embedder:latest

# Run
docker run -p 8080:8080 pipestreamai/djl-serving-embedder:latest
```

### Test the API

```bash
# Health check
curl http://localhost:8080/ping

# Single embedding
curl -X POST http://localhost:8080/predictions/all_MiniLM_L6_v2 \
    -H 'Content-Type: application/json' \
    -d '{"inputs": "Hello world"}'

# Batch embeddings
curl -X POST http://localhost:8080/predictions/all_MiniLM_L6_v2 \
    -H 'Content-Type: application/json' \
    -d '{"inputs": ["Hello world", "This is a test", "Machine learning"]}'
```

## Build Your Own Image

### Default Model (all-MiniLM-L6-v2)

```bash
# CPU
docker build -t my-embedder:cpu .

# CUDA (requires NVIDIA GPU)
docker build -t my-embedder:cuda --build-arg VARIANT=cuda .
```

### Custom Model

```bash
# E5 Small
docker build -t my-embedder:e5-small \
    --build-arg MODEL_ID=intfloat/e5-small-v2 \
    --build-arg MODEL_NAME=e5-small-v2 .

# BGE Large with CUDA
docker build -t my-embedder:bge-large-cuda \
    --build-arg VARIANT=cuda \
    --build-arg MODEL_ID=BAAI/bge-large-en-v1.5 \
    --build-arg MODEL_NAME=bge-large-en .
```

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VARIANT` | `cpu` | `cpu` or `cuda` |
| `MODEL_ID` | `sentence-transformers/all-MiniLM-L6-v2` | HuggingFace model ID |
| `MODEL_NAME` | `all-MiniLM-L6-v2` | Endpoint name (used in URL) |
| `DJL_VERSION` | `0.31.0` | DJL Serving version |

## API Reference

### Health Check

```
GET /ping
```

Returns health status of loaded models.

### Single Embedding

```
POST /predictions/{model_name}
Content-Type: application/json

{"inputs": "Your text here"}
```

Returns: Array of floats (embedding vector)

### Batch Embeddings

```
POST /predictions/{model_name}
Content-Type: application/json

{"inputs": ["Text 1", "Text 2", "Text 3"]}
```

Returns: Array of arrays (one embedding per input)

**Note**: Model names in URLs use underscores instead of hyphens (e.g., `all_MiniLM_L6_v2`).

## Docker Compose

```bash
# CPU
docker compose --profile cpu up

# CUDA
docker compose --profile cuda up
```

## Using as Test Container

### Testcontainers (Java)

```java
@Container
static GenericContainer<?> djlServing = new GenericContainer<>("pipestreamai/djl-serving-embedder:latest")
    .withExposedPorts(8080)
    .waitingFor(Wait.forHttp("/ping").forStatusCode(200)
        .withStartupTimeout(Duration.ofMinutes(2)));

@Test
void testEmbedding() {
    String host = djlServing.getHost();
    int port = djlServing.getMappedPort(8080);
    // Use http://{host}:{port}/predictions/all_MiniLM_L6_v2
}
```

### Testcontainers (Python)

```python
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs

container = DockerContainer("pipestreamai/djl-serving-embedder:latest")
container.with_exposed_ports(8080)
container.start()
wait_for_logs(container, "BOTH API bind to")
```

## Supported Models

Any HuggingFace model compatible with sentence-transformers should work. Popular options:

| Model | Dimensions | Size | Use Case |
|-------|------------|------|----------|
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | 80MB | General purpose, fast |
| `sentence-transformers/all-mpnet-base-v2` | 768 | 420MB | Higher quality |
| `intfloat/e5-small-v2` | 384 | 130MB | Multilingual |
| `intfloat/e5-large-v2` | 1024 | 1.3GB | Best quality |
| `BAAI/bge-small-en-v1.5` | 384 | 130MB | Fast, English |
| `BAAI/bge-large-en-v1.5` | 1024 | 1.3GB | High quality, English |

## License

Apache 2.0
