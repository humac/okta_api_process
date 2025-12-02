#!/bin/bash
###############################################################################
# Apply Okta Access Policy Rules After Terraform
#
# This script is designed to run in your Jenkins/UrbanCode/Velocity pipeline
# after Terraform has completed its deployment.
#
# Usage:
#   ./apply_access_policies.sh [options]
#
# Options:
#   -e, --env ENV          Environment name (dev, staging, prod)
#   -p, --policy NAME      Policy name to update
#   -r, --rules-dir DIR    Directory containing rule JSON files
#   -f, --rule-file FILE   Single rule JSON file to apply
#   -c, --create-only      Only create new rules, don't update existing
#   -h, --help             Show this help message
#
# Environment Variables Required:
#   OKTA_DOMAIN           Your Okta domain (e.g., your-domain.okta.com)
#   OKTA_API_TOKEN        Okta API token with policy management permissions
#
# These can be set via UrbanCode Deploy or environment configuration
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
ENV_NAME="${ENVIRONMENT:-dev}"
POLICY_NAME=""
RULES_DIR=""
RULE_FILE=""
CREATE_ONLY=""
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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENV_NAME="$2"
            shift 2
            ;;
        -p|--policy)
            POLICY_NAME="$2"
            shift 2
            ;;
        -r|--rules-dir)
            RULES_DIR="$2"
            shift 2
            ;;
        -f|--rule-file)
            RULE_FILE="$2"
            shift 2
            ;;
        -c|--create-only)
            CREATE_ONLY="--create-only"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate required parameters
if [ -z "$POLICY_NAME" ]; then
    log_error "Policy name is required. Use -p or --policy"
    exit 1
fi

if [ -z "$RULES_DIR" ] && [ -z "$RULE_FILE" ]; then
    log_error "Either --rules-dir or --rule-file must be specified"
    exit 1
fi

if [ -n "$RULES_DIR" ] && [ -n "$RULE_FILE" ]; then
    log_error "Cannot specify both --rules-dir and --rule-file"
    exit 1
fi

# Validate environment variables
if [ -z "${OKTA_DOMAIN:-}" ]; then
    log_error "OKTA_DOMAIN environment variable is not set"
    log_error "This should be provided by UrbanCode Deploy or your pipeline"
    exit 1
fi

if [ -z "${OKTA_API_TOKEN:-}" ]; then
    log_error "OKTA_API_TOKEN environment variable is not set"
    log_error "This should be provided by UrbanCode Deploy or your pipeline"
    exit 1
fi

# Display configuration
log_info "=================================================="
log_info "Okta Access Policy Rule Deployment"
log_info "=================================================="
log_info "Environment:     $ENV_NAME"
log_info "Policy Name:     $POLICY_NAME"
log_info "Okta Domain:     $OKTA_DOMAIN"
if [ -n "$RULES_DIR" ]; then
    log_info "Rules Directory: $RULES_DIR"
else
    log_info "Rule File:       $RULE_FILE"
fi
log_info "=================================================="

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

# Build command
CMD="python3 ${PROJECT_ROOT}/src/access_policy_manager.py"
CMD="$CMD --policy-name \"$POLICY_NAME\""
CMD="$CMD --log-level $LOG_LEVEL"

if [ -n "$RULES_DIR" ]; then
    CMD="$CMD --rules-dir \"$RULES_DIR\""
else
    CMD="$CMD --rule-file \"$RULE_FILE\""
fi

if [ -n "$CREATE_ONLY" ]; then
    CMD="$CMD $CREATE_ONLY"
fi

# Execute the Python script
log_info "Applying access policy rules..."
log_info "Command: $CMD"
echo ""

if eval "$CMD"; then
    echo ""
    log_success "Access policy rules applied successfully!"
    exit 0
else
    EXIT_CODE=$?
    echo ""
    log_error "Failed to apply access policy rules (exit code: $EXIT_CODE)"
    exit $EXIT_CODE
fi
