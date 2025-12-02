#!/bin/bash
###############################################################################
# UrbanCode Deploy Wrapper for Keep Me Signed In Updates
#
# This script maps UCD environment variables to the format expected by
# update_keepmesignedin.sh and runs the update process.
#
# Required UCD Variables:
#   pubsecure.okta.org_name     - Okta org name (e.g., "dev1-ontsignin")
#   pubsecure.okta.base_url     - Okta base URL (e.g., "oktapreview.com")
#   pubsecure.okta.api_token    - Okta API token (secure)
#   pubsecure.okta.env          - Environment name (e.g., "dev1")
#
# Usage:
#   This script is intended to be called from a UCD process step.
#   It automatically reads UCD variables and constructs OKTA_DOMAIN.
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

# Validate constructed OKTA_DOMAIN
if [ "$OKTA_DOMAIN" == "." ] || [ -z "$OKTA_DOMAIN" ]; then
    log_error "OKTA_DOMAIN could not be constructed from UCD variables"
    log_error "Check that pubsecure.okta.org_name and pubsecure.okta.base_url are set correctly"
    exit 1
fi

# Display configuration
log_info "=================================================="
log_info "Okta Keep Me Signed In Update (UCD Integration)"
log_info "=================================================="
log_info "Okta Domain:     $OKTA_DOMAIN"
log_info "Environment:     $ENVIRONMENT"
log_info "Working Dir:     $(pwd)"
log_info "=================================================="

# Check if CSV file exists for this environment
CSV_FILE="${PROJECT_ROOT}/config/${ENVIRONMENT}/policy_rule_ids.csv"

if [ ! -f "$CSV_FILE" ]; then
    log_warn "=================================================="
    log_warn "No policy/rule ID configuration found"
    log_warn "=================================================="
    log_warn "Expected file: $CSV_FILE"
    log_warn ""
    log_warn "Skipping Keep Me Signed In updates for $ENVIRONMENT"
    log_warn ""
    log_warn "To enable updates for this environment:"
    log_warn "  1. Create file: $CSV_FILE"
    log_warn "  2. Add your policy/rule IDs (format: policyId,ruleId,description)"
    log_warn "  3. Commit and create new component version"
    log_warn "  4. Re-deploy"
    log_warn "=================================================="
    exit 0
fi

log_info "Using configuration file: $CSV_FILE"

# Count non-comment, non-empty lines in CSV (excluding header)
RULE_COUNT=$(grep -v '^#' "$CSV_FILE" | grep -v '^$' | tail -n +2 | wc -l)

if [ "$RULE_COUNT" -eq 0 ]; then
    log_warn "=================================================="
    log_warn "No rules configured in CSV file"
    log_warn "=================================================="
    log_warn "The CSV file exists but contains no rule entries."
    log_warn "Add your policy/rule IDs to: $CSV_FILE"
    log_warn "Skipping Keep Me Signed In updates."
    log_warn "=================================================="
    exit 0
fi

log_info "Found $RULE_COUNT rule(s) to update"
log_info "=================================================="
echo ""

# Call the main update script
log_info "Starting Keep Me Signed In update process..."
echo ""

if "${SCRIPT_DIR}/update_keepmesignedin.sh" --csv-file "$CSV_FILE"; then
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
    log_error "=================================================="
    log_error "Exit code: $EXIT_CODE"
    log_error ""
    log_error "Troubleshooting:"
    log_error "  1. Check Okta API token has correct permissions"
    log_error "  2. Verify policy/rule IDs in $CSV_FILE"
    log_error "  3. Check Okta System Log for API errors"
    log_error "  4. Review detailed logs above"
    log_error "=================================================="
    exit $EXIT_CODE
fi
