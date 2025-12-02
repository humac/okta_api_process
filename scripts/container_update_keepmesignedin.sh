#!/bin/bash
###############################################################################
# Container-based Okta Keep Me Signed In Updater
#
# This script runs the update process in a container, eliminating the need
# to manage Python dependencies on the UCD agent.
#
# Supports: Docker, Podman, or any OCI-compatible container runtime
#
# Required Environment Variables:
#   OKTA_DOMAIN           Your Okta domain
#   OKTA_API_TOKEN        Okta API token
#   ENVIRONMENT           Environment name (dev1, dev2, test1, test2, stage, prod)
#
# Optional Environment Variables:
#   CONTAINER_RUNTIME     Container runtime to use (docker, podman, auto)
#   CONTAINER_IMAGE       Custom image name (default: okta-api-updater:latest)
#   LOG_LEVEL             Logging level (default: INFO)
#   DRY_RUN               Set to "true" for dry-run mode
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-auto}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-okta-api-updater:latest}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
DRY_RUN="${DRY_RUN:-false}"

# Validate required environment variables
if [ -z "${OKTA_DOMAIN:-}" ]; then
    log_error "OKTA_DOMAIN environment variable is not set"
    exit 1
fi

if [ -z "${OKTA_API_TOKEN:-}" ]; then
    log_error "OKTA_API_TOKEN environment variable is not set"
    exit 1
fi

if [ -z "${ENVIRONMENT:-}" ]; then
    log_error "ENVIRONMENT environment variable is not set"
    exit 1
fi

# Detect container runtime
detect_runtime() {
    if [ "$CONTAINER_RUNTIME" != "auto" ]; then
        echo "$CONTAINER_RUNTIME"
        return
    fi

    if command -v docker &> /dev/null; then
        echo "docker"
    elif command -v podman &> /dev/null; then
        echo "podman"
    else
        log_error "No container runtime found. Install docker or podman."
        exit 1
    fi
}

RUNTIME=$(detect_runtime)
log_info "Using container runtime: $RUNTIME"

# Check if image exists, build if not
check_and_build_image() {
    if ! $RUNTIME image inspect "$CONTAINER_IMAGE" &> /dev/null; then
        log_warn "Container image '$CONTAINER_IMAGE' not found"
        log_info "Building container image..."

        cd "$PROJECT_ROOT"
        $RUNTIME build -t "$CONTAINER_IMAGE" .

        if [ $? -eq 0 ]; then
            log_success "Container image built successfully"
        else
            log_error "Failed to build container image"
            exit 1
        fi
    else
        log_info "Using existing container image: $CONTAINER_IMAGE"
    fi
}

# Display configuration
log_info "=================================================="
log_info "Okta Keep Me Signed In Update (Container Mode)"
log_info "=================================================="
log_info "Container Runtime:  $RUNTIME"
log_info "Container Image:    $CONTAINER_IMAGE"
log_info "Okta Domain:        $OKTA_DOMAIN"
log_info "Environment:        $ENVIRONMENT"
log_info "Dry Run:            $DRY_RUN"
log_info "=================================================="

# Check if CSV file exists
CSV_FILE="${PROJECT_ROOT}/config/${ENVIRONMENT}/policy_rule_ids.csv"

if [ ! -f "$CSV_FILE" ]; then
    log_warn "=================================================="
    log_warn "No policy/rule ID configuration found"
    log_warn "=================================================="
    log_warn "Expected file: $CSV_FILE"
    log_warn "Skipping Keep Me Signed In updates for $ENVIRONMENT"
    exit 0
fi

# Count rules
RULE_COUNT=$(grep -v '^#' "$CSV_FILE" | grep -v '^$' | tail -n +2 | wc -l)

if [ "$RULE_COUNT" -eq 0 ]; then
    log_warn "No rules configured in CSV file"
    exit 0
fi

log_info "Found $RULE_COUNT rule(s) to update"

# Check and build image if needed
check_and_build_image

# Build container command
CONTAINER_ARGS=(
    "run"
    "--rm"
    "--name" "okta-api-updater-${ENVIRONMENT}-$$"
    "-e" "OKTA_DOMAIN=${OKTA_DOMAIN}"
    "-e" "OKTA_API_TOKEN=${OKTA_API_TOKEN}"
    "-e" "LOG_LEVEL=${LOG_LEVEL}"
    "-v" "${PROJECT_ROOT}/config:/app/config:ro"
)

# Add dry-run flag if enabled
if [ "$DRY_RUN" = "true" ]; then
    CONTAINER_CMD=(
        "src/update_keepmesignedin.py"
        "--csv-file" "/app/config/${ENVIRONMENT}/policy_rule_ids.csv"
        "--dry-run"
    )
else
    CONTAINER_CMD=(
        "src/update_keepmesignedin.py"
        "--csv-file" "/app/config/${ENVIRONMENT}/policy_rule_ids.csv"
    )
fi

# Run container
log_info "Starting container update process..."
echo ""

if $RUNTIME "${CONTAINER_ARGS[@]}" "$CONTAINER_IMAGE" "${CONTAINER_CMD[@]}"; then
    echo ""
    log_success "=================================================="
    log_success "Keep Me Signed In configuration updated successfully!"
    log_success "=================================================="
    exit 0
else
    EXIT_CODE=$?
    echo ""
    log_error "=================================================="
    log_error "Keep Me Signed In update failed"
    log_error "Exit code: $EXIT_CODE"
    log_error "=================================================="
    exit $EXIT_CODE
fi
