#!/bin/bash
###############################################################################
# Update Keep Me Signed In Configuration for Okta Access Policy Rules
#
# This script updates existing Okta Access Policy rules to enable the
# "Keep Me Signed In" feature.
#
# Usage:
#   # Single rule update
#   ./update_keepmesignedin.sh --policy-id 00p... --rule-id 0pr...
#
#   # Bulk update from CSV file
#   ./update_keepmesignedin.sh --csv-file config/policy_rule_ids.csv
#
#   # Dry run (preview changes)
#   ./update_keepmesignedin.sh --csv-file config/policy_rule_ids.csv --dry-run
#
# Environment Variables Required:
#   OKTA_DOMAIN           Your Okta domain (e.g., your-domain.okta.com)
#   OKTA_API_TOKEN        Okta API token with policy management permissions
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
LOG_LEVEL="${LOG_LEVEL:-INFO}"

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate environment variables
if [ -z "${OKTA_DOMAIN:-}" ]; then
    log_error "OKTA_DOMAIN environment variable is not set"
    exit 1
fi

if [ -z "${OKTA_API_TOKEN:-}" ]; then
    log_error "OKTA_API_TOKEN environment variable is not set"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    log_error "python3 is not installed or not in PATH"
    exit 1
fi

# Check if virtual environment exists, create if not
VENV_DIR="${PROJECT_ROOT}/venv"
if [ ! -d "$VENV_DIR" ]; then
    log_info "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source "${VENV_DIR}/bin/activate"

# Install/upgrade dependencies
log_info "Installing Python dependencies..."
pip install -q --upgrade pip
pip install -q -r "${PROJECT_ROOT}/requirements.txt"

# Add src directory to Python path
export PYTHONPATH="${PROJECT_ROOT}/src:${PYTHONPATH:-}"

# Execute the Python script with all arguments passed through
log_info "Updating Keep Me Signed In configuration..."
log_info "Okta Domain: $OKTA_DOMAIN"
echo ""

if python3 "${PROJECT_ROOT}/src/update_keepmesignedin.py" "$@"; then
    echo ""
    log_success "Operation completed successfully!"
    exit 0
else
    EXIT_CODE=$?
    echo ""
    log_error "Operation failed (exit code: $EXIT_CODE)"
    exit $EXIT_CODE
fi
