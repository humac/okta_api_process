#!/bin/bash
###############################################################################
# UrbanCode Deploy Container Wrapper
#
# This script runs the Okta API updater in a container from UrbanCode Deploy.
# No Python dependencies need to be installed on the UCD agent!
#
# Required UCD Variables:
#   pubsecure.okta.org_name     - Okta org name
#   pubsecure.okta.base_url     - Okta base URL
#   pubsecure.okta.api_token    - Okta API token (secure)
#   pubsecure.okta.env          - Environment name
#
# Optional UCD Variables:
#   container.runtime           - Container runtime (docker, podman, auto)
#   container.image             - Custom image name
#   okta.dry_run                - Set to "true" for dry-run mode
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Map UCD variables to script variables
if [ -n "${pubsecure.okta.org_name:-}" ] && [ -n "${pubsecure.okta.base_url:-}" ]; then
    export OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
else
    log_error "Required UCD variables not set:"
    log_error "  - pubsecure.okta.org_name"
    log_error "  - pubsecure.okta.base_url"
    exit 1
fi

if [ -n "${pubsecure.okta.api_token:-}" ]; then
    export OKTA_API_TOKEN="${pubsecure.okta.api_token}"
else
    log_error "Required UCD variable not set: pubsecure.okta.api_token"
    exit 1
fi

if [ -n "${pubsecure.okta.env:-}" ]; then
    export ENVIRONMENT="${pubsecure.okta.env}"
else
    log_error "Required UCD variable not set: pubsecure.okta.env"
    exit 1
fi

# Optional UCD variables
export CONTAINER_RUNTIME="${container.runtime:-auto}"
export CONTAINER_IMAGE="${container.image:-okta-api-updater:latest}"
export DRY_RUN="${okta.dry_run:-false}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Validate constructed OKTA_DOMAIN
if [ "$OKTA_DOMAIN" == "." ] || [ -z "$OKTA_DOMAIN" ]; then
    log_error "OKTA_DOMAIN could not be constructed from UCD variables"
    exit 1
fi

log_info "UCD Container Wrapper - Okta Keep Me Signed In Update"
log_info "Okta Domain: $OKTA_DOMAIN"
log_info "Environment: $ENVIRONMENT"
log_info "Container Runtime: $CONTAINER_RUNTIME"
log_info "Container Image: $CONTAINER_IMAGE"
echo ""

# Call the container script
exec "${SCRIPT_DIR}/container_update_keepmesignedin.sh"
