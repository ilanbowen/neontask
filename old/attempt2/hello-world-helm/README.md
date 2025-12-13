# Hello World App - Helm Chart

Helm chart for deploying the Hello World Flask application to Kubernetes.

## Installation

### Install with default values

```bash
helm install hello-world-app ./helm-chart
```

### Install with custom values

```bash
helm install hello-world-app ./helm-chart \
  --set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-world-app \
  --set image.tag=v1.0.0 \
  --set replicaCount=3
```

### Install with custom values file

```bash
helm install hello-world-app ./helm-chart -f custom-values.yaml
```

## Upgrade

```bash
helm upgrade hello-world-app ./helm-chart \
  --set image.tag=v1.1.0
```

## Uninstall

```bash
helm uninstall hello-world-app
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hello-world-app` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `autoscaling.enabled` | Enable autoscaling | `true` |
| `autoscaling.minReplicas` | Minimum replicas | `2` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |

## Testing

```bash
# Lint the chart
helm lint ./helm-chart

# Dry run
helm install hello-world-app ./helm-chart --dry-run --debug

# Template rendering
helm template hello-world-app ./helm-chart
```

## Features

- ✅ Horizontal Pod Autoscaler (HPA)
- ✅ Health checks (liveness and readiness probes)
- ✅ Resource limits and requests
- ✅ Security context (non-root user)
- ✅ Service account
- ✅ Configurable environment variables
- ✅ Optional Ingress support
