#!/bin/bash
###############################################################################
# UrbanCode Deploy Wrapper Script
#
# This script is specifically designed to be called from UrbanCode Deploy
# after your Terraform deployment completes.
#
# UrbanCode Deploy should provide the following as component properties:
#   - OKTA_DOMAIN
#   - OKTA_API_TOKEN
#   - POLICY_NAME
#   - ENVIRONMENT
#
# Place your rule JSON files in: config/${ENVIRONMENT}/rules/
###############################################################################

set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# UrbanCode Deploy sets these variables
ENVIRONMENT="${ENVIRONMENT:-dev}"
POLICY_NAME="${POLICY_NAME:-}"

# Validate UrbanCode Deploy provided variables
if [ -z "$POLICY_NAME" ]; then
    echo "ERROR: POLICY_NAME must be set by UrbanCode Deploy"
    exit 1
fi

if [ -z "$OKTA_DOMAIN" ]; then
    echo "ERROR: OKTA_DOMAIN must be set by UrbanCode Deploy"
    exit 1
fi

if [ -z "$OKTA_API_TOKEN" ]; then
    echo "ERROR: OKTA_API_TOKEN must be set by UrbanCode Deploy"
    exit 1
fi

# Determine rules directory based on environment
RULES_DIR="${PROJECT_ROOT}/config/${ENVIRONMENT}/rules"

if [ ! -d "$RULES_DIR" ]; then
    echo "WARNING: Rules directory not found: $RULES_DIR"
    echo "Skipping Okta API policy updates"
    exit 0
fi

# Call the main script
echo "Calling Okta policy update script..."
exec "${SCRIPT_DIR}/apply_access_policies.sh" \
    --env "$ENVIRONMENT" \
    --policy "$POLICY_NAME" \
    --rules-dir "$RULES_DIR"
