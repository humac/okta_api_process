# Container Deployment Guide

This guide shows how to run the Okta API Keep Me Signed In updater in a container, eliminating the need to manage Python dependencies on your UCD agents or local machines.

## Why Use Containers?

✅ **No Python dependency management** - Everything bundled in the container
✅ **Consistent environment** - Same runtime across dev, test, stage, and prod
✅ **Easier UCD integration** - Just run a container, no setup needed
✅ **Portable** - Works with Docker, Podman, or any OCI-compatible runtime
✅ **Smaller footprint** - Only ~100MB image size

## Container Runtimes Supported

- **Docker** - Most common
- **Podman** - Rootless, daemonless alternative
- **Any OCI-compatible runtime** - Kubernetes, OpenShift, etc.

## Quick Start

### Option 1: Using Docker Compose (Recommended for Local Testing)

```bash
# 1. Set environment variables
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_token"
export ENVIRONMENT="dev1"

# 2. Build and run with docker-compose
docker-compose run okta-api-updater

# 3. For actual updates (remove --dry-run)
docker-compose run okta-api-updater \
    src/update_keepmesignedin.py \
    --csv-file /app/config/dev1/policy_rule_ids.csv
```

### Option 2: Using Docker Directly

```bash
# 1. Build the container image
docker build -t okta-api-updater:latest .

# 2. Run with your environment variables
docker run --rm \
    -e OKTA_DOMAIN="dev1-ontsignin.oktapreview.com" \
    -e OKTA_API_TOKEN="your_token" \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    src/update_keepmesignedin.py \
    --csv-file /app/config/dev1/policy_rule_ids.csv \
    --dry-run
```

### Option 3: Using Podman

```bash
# 1. Build with Podman
podman build -t okta-api-updater:latest .

# 2. Run with Podman
podman run --rm \
    -e OKTA_DOMAIN="dev1-ontsignin.oktapreview.com" \
    -e OKTA_API_TOKEN="your_token" \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    src/update_keepmesignedin.py \
    --csv-file /app/config/dev1/policy_rule_ids.csv \
    --dry-run
```

### Option 4: Using the Container Script (Auto-detects Runtime)

```bash
# Set environment variables
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_token"
export ENVIRONMENT="dev1"

# Run the script (auto-detects docker or podman)
./scripts/container_update_keepmesignedin.sh

# For dry-run
export DRY_RUN=true
./scripts/container_update_keepmesignedin.sh
```

## Building the Container Image

### Standard Build

```bash
docker build -t okta-api-updater:latest .
```

### Build with Custom Tag

```bash
docker build -t myregistry.com/okta-api-updater:1.0.0 .
```

### Build for Specific Platform

```bash
# For ARM64 (Apple Silicon, ARM servers)
docker build --platform linux/arm64 -t okta-api-updater:latest-arm64 .

# For AMD64 (Intel/AMD servers)
docker build --platform linux/amd64 -t okta-api-updater:latest-amd64 .

# Multi-platform build
docker buildx build --platform linux/amd64,linux/arm64 -t okta-api-updater:latest .
```

## Pushing to Container Registry

### Docker Hub

```bash
# Tag the image
docker tag okta-api-updater:latest yourusername/okta-api-updater:latest

# Login
docker login

# Push
docker push yourusername/okta-api-updater:latest
```

### Private Registry

```bash
# Tag for private registry
docker tag okta-api-updater:latest myregistry.company.com/okta-api-updater:latest

# Login to private registry
docker login myregistry.company.com

# Push
docker push myregistry.company.com/okta-api-updater:latest
```

### Artifactory

```bash
# Tag for Artifactory
docker tag okta-api-updater:latest artifactory.company.com/docker-local/okta-api-updater:latest

# Login
docker login artifactory.company.com

# Push
docker push artifactory.company.com/docker-local/okta-api-updater:latest
```

## UrbanCode Deploy Integration

### Prerequisites

1. **Container runtime installed** on UCD agent (Docker or Podman)
2. **Container image** available (built locally or pulled from registry)
3. **UCD variables** configured (same as before)

### Option A: Using Auto-Detect Script

**UCD Process Step:**

```bash
#!/bin/bash
cd ${p:component/workDir}

# Map UCD variables
export OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
export OKTA_API_TOKEN="${pubsecure.okta.api_token}"
export ENVIRONMENT="${pubsecure.okta.env}"

# Optional: specify container runtime
export CONTAINER_RUNTIME="docker"  # or "podman" or "auto"

# Optional: use custom image from registry
export CONTAINER_IMAGE="myregistry.com/okta-api-updater:latest"

# Run the container script
./scripts/container_update_keepmesignedin.sh
```

### Option B: Using UCD Container Wrapper

Even simpler! The wrapper automatically maps UCD variables:

**UCD Process Step:**

```bash
#!/bin/bash
cd ${p:component/workDir}

# Just run the UCD wrapper - it handles everything!
./scripts/ucd_container_wrapper.sh
```

The wrapper automatically:
- Constructs `OKTA_DOMAIN` from `pubsecure.okta.org_name` and `pubsecure.okta.base_url`
- Passes `pubsecure.okta.api_token` as `OKTA_API_TOKEN`
- Uses `pubsecure.okta.env` as `ENVIRONMENT`
- Detects available container runtime (Docker or Podman)
- Builds image if not found
- Runs the update process

### Option C: Direct Docker/Podman Command

**UCD Process Step:**

```bash
#!/bin/bash
cd ${p:component/workDir}

# Map UCD variables
OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
OKTA_API_TOKEN="${pubsecure.okta.api_token}"
ENVIRONMENT="${pubsecure.okta.env}"

# Run with Docker
docker run --rm \
    -e OKTA_DOMAIN="$OKTA_DOMAIN" \
    -e OKTA_API_TOKEN="$OKTA_API_TOKEN" \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    src/update_keepmesignedin.py \
    --csv-file "/app/config/${ENVIRONMENT}/policy_rule_ids.csv"
```

## Advanced Container Usage

### Running Interactive Shell

Useful for debugging:

```bash
docker run --rm -it \
    -e OKTA_DOMAIN="dev1-ontsignin.oktapreview.com" \
    -e OKTA_API_TOKEN="your_token" \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    /bin/bash
```

Inside the container:

```bash
# List policies
python3 src/okta_api_client.py

# Run update with debug logging
python3 src/update_keepmesignedin.py \
    --csv-file /app/config/dev1/policy_rule_ids.csv \
    --log-level DEBUG \
    --dry-run
```

### Update Single Rule by ID

```bash
docker run --rm \
    -e OKTA_DOMAIN="dev1-ontsignin.oktapreview.com" \
    -e OKTA_API_TOKEN="your_token" \
    okta-api-updater:latest \
    src/update_keepmesignedin.py \
    --policy-id "00p1a2b3c4d5e6f7g8h9" \
    --rule-id "0pr9i8h7g6f5e4d3c2b1" \
    --dry-run
```

### Custom Configuration File

```bash
docker run --rm \
    -e OKTA_DOMAIN="dev1-ontsignin.oktapreview.com" \
    -e OKTA_API_TOKEN="your_token" \
    -v $(pwd)/config:/app/config:ro \
    -v $(pwd)/my-custom-config.json:/app/custom-config.json:ro \
    okta-api-updater:latest \
    src/update_keepmesignedin.py \
    --csv-file /app/config/dev1/policy_rule_ids.csv \
    --config /app/custom-config.json
```

## Kubernetes Deployment

### Option 1: Kubernetes Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: okta-api-update-dev1
  namespace: devops
spec:
  template:
    spec:
      containers:
      - name: okta-api-updater
        image: myregistry.com/okta-api-updater:latest
        command:
          - python3
          - src/update_keepmesignedin.py
          - --csv-file
          - /app/config/dev1/policy_rule_ids.csv
        env:
        - name: OKTA_DOMAIN
          valueFrom:
            secretKeyRef:
              name: okta-credentials
              key: domain
        - name: OKTA_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: okta-credentials
              key: api_token
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: okta-policy-rules
      restartPolicy: Never
  backoffLimit: 3
```

### Option 2: Kubernetes CronJob

Run automatically after Terraform deployments:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: okta-api-update-schedule
  namespace: devops
spec:
  # Run every day at 2 AM
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: okta-api-updater
            image: myregistry.com/okta-api-updater:latest
            command:
              - python3
              - src/update_keepmesignedin.py
              - --csv-file
              - /app/config/prod/policy_rule_ids.csv
            env:
            - name: OKTA_DOMAIN
              valueFrom:
                secretKeyRef:
                  name: okta-credentials-prod
                  key: domain
            - name: OKTA_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: okta-credentials-prod
                  key: api_token
            volumeMounts:
            - name: config
              mountPath: /app/config
              readOnly: true
          volumes:
          - name: config
            configMap:
              name: okta-policy-rules-prod
          restartPolicy: OnFailure
```

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OKTA_DOMAIN` | Yes | - | Your Okta domain (e.g., `dev1-ontsignin.oktapreview.com`) |
| `OKTA_API_TOKEN` | Yes | - | Okta API token with policy management permissions |
| `ENVIRONMENT` | No | `dev1` | Environment name (for script mode) |
| `LOG_LEVEL` | No | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `CONTAINER_RUNTIME` | No | `auto` | Container runtime (docker, podman, auto) |
| `CONTAINER_IMAGE` | No | `okta-api-updater:latest` | Container image name |
| `DRY_RUN` | No | `false` | Set to `true` for dry-run mode |

## Volume Mounts

| Container Path | Description | Required |
|---------------|-------------|----------|
| `/app/config` | Configuration directory containing CSV files | Yes |
| `/app/custom-config.json` | Custom keepMeSignedIn configuration | No |

## Container Image Details

- **Base Image:** `python:3.11-slim`
- **Size:** ~100MB
- **Python Version:** 3.11
- **Included Dependencies:**
  - requests==2.31.0
  - python-dotenv==1.0.0
  - pyyaml==6.0.1

## Troubleshooting

### Issue: Container image not found

```bash
# Build the image first
docker build -t okta-api-updater:latest .

# Or pull from registry
docker pull myregistry.com/okta-api-updater:latest
docker tag myregistry.com/okta-api-updater:latest okta-api-updater:latest
```

### Issue: Permission denied on config volume

```bash
# Ensure config directory has read permissions
chmod -R 755 config/

# Or run container with specific user
docker run --rm --user $(id -u):$(id -g) \
    -e OKTA_DOMAIN="..." \
    -e OKTA_API_TOKEN="..." \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    src/update_keepmesignedin.py --csv-file /app/config/dev1/policy_rule_ids.csv
```

### Issue: Container runtime not found on UCD agent

```bash
# Install Docker on UCD agent
curl -fsSL https://get.docker.com | sh

# Or install Podman
# RHEL/CentOS
sudo yum install podman

# Ubuntu/Debian
sudo apt-get install podman
```

### Issue: CSV file not found in container

```bash
# Verify volume mount is correct
docker run --rm \
    -v $(pwd)/config:/app/config:ro \
    okta-api-updater:latest \
    ls -la /app/config/dev1/

# Check absolute path
docker run --rm \
    -v /absolute/path/to/config:/app/config:ro \
    okta-api-updater:latest \
    cat /app/config/dev1/policy_rule_ids.csv
```

## Best Practices

1. **Use Container Registry:**
   - Build once, deploy everywhere
   - Version your images (e.g., `okta-api-updater:1.0.0`)
   - Use semantic versioning

2. **Security:**
   - Never bake credentials into images
   - Always pass secrets via environment variables
   - Use read-only volume mounts for config
   - Scan images for vulnerabilities

3. **CI/CD Integration:**
   - Build image in CI pipeline
   - Tag with git commit SHA
   - Push to registry
   - Deploy via UCD

4. **Image Tagging:**
   ```bash
   # Development
   docker tag okta-api-updater:latest okta-api-updater:dev

   # Specific version
   docker tag okta-api-updater:latest okta-api-updater:1.2.3

   # Git commit
   docker tag okta-api-updater:latest okta-api-updater:$(git rev-parse --short HEAD)
   ```

5. **Health Checks:**
   ```dockerfile
   # Add to Dockerfile
   HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
     CMD python3 -c "import requests; exit(0)"
   ```

## Comparison: Native vs Container

| Aspect | Native Python | Container |
|--------|--------------|-----------|
| Setup Time | 5-10 minutes | 1 minute (pull) or 2 minutes (build) |
| Dependencies | Must install on each agent | Bundled in image |
| Python Version | Must match (3.7+) | Guaranteed (3.11) |
| Consistency | Varies by agent | 100% consistent |
| UCD Agent Impact | Python packages on agent | Minimal (just container runtime) |
| Portability | Agent-dependent | Runs anywhere |
| Updates | Update packages on each agent | Build new image once |
| Isolation | Shares agent environment | Fully isolated |

## Migration from Native to Container

### Step 1: Test Locally

```bash
# Build image
docker build -t okta-api-updater:latest .

# Test with your dev environment
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_token"
export ENVIRONMENT="dev1"
./scripts/container_update_keepmesignedin.sh
```

### Step 2: Update UCD Process

Change your UCD process step from:

```bash
# Old (native Python)
./scripts/update_keepmesignedin.sh --csv-file config/${ENVIRONMENT}/policy_rule_ids.csv
```

To:

```bash
# New (container)
./scripts/ucd_container_wrapper.sh
```

### Step 3: Deploy to Dev1

Test in dev1 environment first before rolling out to other environments.

### Step 4: Rollout

Once validated, deploy to:
- Dev2
- Test1
- Test2
- Stage
- Prod

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Podman Documentation](https://docs.podman.io/)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [OCI Image Specification](https://github.com/opencontainers/image-spec)
