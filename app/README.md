# SRE Showcase Application

A simple FastAPI application designed to demonstrate SRE practices including observability, health checks, and incident simulation.

---

## Overview

This is a Python-based REST API that exposes:

- Health and readiness endpoints for Kubernetes probes
- Prometheus metrics for monitoring
- Sample API endpoints for load testing
- Intentionally flaky/slow endpoints for incident simulation

---

## Tech Stack

- **Python 3.11**
- **FastAPI** - Modern web framework
- **Uvicorn** - ASGI server
- **Prometheus Client** - Metrics exposition

---

## Local Development

### Prerequisites

- Python 3.11+
- pip

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run Locally

```bash
# Start the application
python main.py

# Or with uvicorn directly
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The application will be available at: <http://localhost:8000>

### Test Locally

```bash
# Run unit tests
PYTHONPATH=. pytest tests/ -v

# Run all tests with script
./test_local.sh
```

### Available Endpoints

- `GET /` - Root endpoint with API info
- `GET /health` - Liveness probe
- `GET /ready` - Readiness probe
- `GET /metrics` - Prometheus metrics
- `GET /docs` - Interactive API documentation
- `GET /api/data` - Sample data endpoint
- `GET /api/status` - Application status
- `GET /api/slow` - Intentionally slow endpoint (for testing)
- `GET /api/flaky` - Randomly fails 10% of the time (for testing)
- `POST /admin/break` - Break health check (for incident simulation)
- `POST /admin/fix` - Fix health check (for incident recovery)

---

## Docker

### Build Image

```bash
# Build for linux/amd64 (AWS EKS platform)
docker build --platform linux/amd64 -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest .
```

### Test Docker Image

```bash
# Run container
docker run -d -p 8000:8000 --name sre-app ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest

# Test endpoints
curl http://localhost:8000/health

# Check logs
docker logs sre-app

# Stop and remove
docker stop sre-app
docker rm sre-app
```

### Test with Script

```bash
./test_docker.sh
```

---

## GitHub Container Registry

### Login to GHCR

```bash
# Create GitHub Personal Access Token with write:packages scope
# Then login
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Push to Registry

```bash
# Build
docker build --platform linux/amd64 -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest .

# Push
docker push ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest
```

> [!IMPORTANT]
> Please note that if you want to use your own application, you must reference the image in the `kustomization.yaml` file inside the `k8s/app` folder.

### Make Package Public

1. Go to: <https://github.com/YOUR_USERNAME?tab=packages>
2. Click on `sre-app` package
3. Click "Package settings"
4. Scroll to "Danger Zone"
5. Click "Change visibility" → "Public"

---

## CI/CD

The application is automatically built and pushed to GHCR via GitHub Actions when code is pushed to the `main` branch.

See `.github/workflows/ci-build-test.yaml` for the CI/CD pipeline.

---

## Observability

### Metrics Exposed

The `/metrics` endpoint exposes Prometheus-format metrics:

- `http_requests_total` - Total HTTP requests (counter)
- `http_request_duration_seconds` - Request latency (histogram)
- `http_requests_in_progress` - In-flight requests (gauge)
- `http_errors_total` - Total errors (counter)
- `app_info` - Application metadata (gauge)

### Health Checks

- **Liveness** (`/health`): Returns 200 if app is alive
- **Readiness** (`/ready`): Returns 200 if app is ready to serve traffic

Both are used by Kubernetes probes.

---

## Testing

### Unit Tests

```bash
PYTHONPATH=. pytest tests/ -v
```

### Load Testing

Load tests are available in `../incidents/load-tests/`:

```bash
cd ../incidents/load-tests
./run-spike-test.sh
```

---

## Incident Simulation

### Break the Application

```bash
# Make health check fail
curl -X POST http://localhost:8000/admin/break

# Verify it's broken
curl http://localhost:8000/health
# Returns: 503
```

### Fix the Application

```bash
# Restore health check
curl -X POST http://localhost:8000/admin/fix

# Verify it's fixed
curl http://localhost:8000/health
# Returns: 200
```

---

## Development

### Code Structure

- `main.py` - Main application with all endpoints
- `requirements.txt` - Python dependencies
- `Dockerfile` - Multi-stage container build
- `tests/` - Unit tests
- `test_local.sh` - Local testing script
- `test_docker.sh` - Docker testing script

### Adding New Endpoints

```python
@app.get("/api/new-endpoint")
async def new_endpoint():
    return {"message": "New endpoint"}
```

Metrics are automatically tracked by the middleware.

---

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 8000
lsof -i :8000

# Kill process
kill -9 PID
```

### Import Errors

```bash
# Ensure PYTHONPATH is set
export PYTHONPATH=.

# Or run with python -m
python -m pytest tests/
```

### Docker Build Fails

```bash
# Clean Docker cache
docker builder prune -f

# Rebuild without cache
docker build --no-cache --platform linux/amd64 -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest .
```

---

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
