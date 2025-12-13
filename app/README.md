# Hello World Flask Application

Simple Flask application for Kubernetes deployment.

## Endpoints

- `GET /` - Main endpoint, returns JSON with app info
- `GET /health` - Health check endpoint (for Kubernetes liveness probe)
- `GET /ready` - Readiness check endpoint (for Kubernetes readiness probe)
- `GET /info` - Detailed application information

## Local Development

### Setup

```bash
cd app

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Linux/Mac:
source venv/bin/activate
# Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Run

```bash
# Development mode
python app.py

# Production mode with Gunicorn
gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
```

### Test

```bash
# Test main endpoint
curl http://localhost:5000/

# Test health endpoint
curl http://localhost:5000/health

# Test readiness endpoint
curl http://localhost:5000/ready

# Test info endpoint
curl http://localhost:5000/info
```

## Docker

### Build

```bash
cd app
docker build -t hello-world-app:latest .
```

### Run

```bash
docker run -p 5000:5000 hello-world-app:latest
```

### Test

```bash
curl http://localhost:5000/
```

## Kubernetes Deployment

The application is deployed to Kubernetes using Helm chart in `../helm-chart/`.

### Environment Variables

- `PORT` - Port to listen on (default: 5000)
- `ENVIRONMENT` - Environment name (development, staging, production)

## CI/CD

The application is automatically built and deployed via GitHub Actions when changes are pushed to the `app/` directory.

See `.github/workflows/app-deploy.yml` for pipeline configuration.
