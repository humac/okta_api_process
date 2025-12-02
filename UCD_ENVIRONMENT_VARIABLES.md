# UrbanCode Deploy Integration Guide - Environment Variables

This guide shows how to integrate the Okta API Keep Me Signed In updater with UrbanCode Deploy using your existing environment variables.

## Your UCD Environment Variables

Based on your existing UCD setup, you have variables like this for each environment:

**Example: Dev1 Environment**
```
pubsecure.okta.org_name=dev1-ontsignin
pubsecure.okta.base_url=oktapreview.com
pubsecure.okta.api_token=****
pubsecure.okta.custom_domain=https://dev1.signin.ontario.ca
pubsecure.okta.profilemgmt_domain=dev1.profile.signin.ontario.ca
pubsecure.okta.env=dev1
```

## Variable Mapping

The script requires these environment variables:

| Script Variable | UCD Variable Mapping | Example Value |
|----------------|---------------------|---------------|
| `OKTA_DOMAIN` | `${pubsecure.okta.org_name}.${pubsecure.okta.base_url}` | `dev1-ontsignin.oktapreview.com` |
| `OKTA_API_TOKEN` | `${pubsecure.okta.api_token}` | `00abc...xyz` |
| `ENVIRONMENT` | `${pubsecure.okta.env}` | `dev1` |

## Setup Instructions

### Step 1: Prepare Policy/Rule ID CSV Files for Each Environment

Create CSV files with your policy and rule IDs for each environment:

```bash
# Directory structure (all 6 environments)
config/
├── dev1/
│   └── policy_rule_ids.csv
├── dev2/
│   └── policy_rule_ids.csv
├── test1/
│   └── policy_rule_ids.csv
├── test2/
│   └── policy_rule_ids.csv
├── staging/  (also accessible as stage/)
│   └── policy_rule_ids.csv
└── prod/
    └── policy_rule_ids.csv
```

**Example: `config/dev1/policy_rule_ids.csv`**
```csv
policyId,ruleId,description
00pDEV1POLICY00001,0prDEV1RULE000001,Dev1 App Access Policy - Default Rule
00pDEV1POLICY00002,0prDEV1RULE000002,Dev1 Admin Access Policy - MFA Rule
```

**Example: `config/prod/policy_rule_ids.csv`**
```csv
policyId,ruleId,description
00pPRODPOLICY0001,0prPRODRULE00001,Production App Access Policy - Default Rule
00pPRODPOLICY0002,0prPRODRULE00002,Production Admin Access Policy - MFA Rule
```

### Step 2: Add Component to UrbanCode Deploy

1. **Create Component:**
   - Name: `okta-keepmesignedin-updater`
   - Type: Standard Component
   - Source Config Type: File System (Copy) or Git

2. **Import Component Version:**
   - Upload the `okta_api_process` directory as a version
   - Include all files and scripts

### Step 3: Create Component Process

1. **Go to:** Components → `okta-keepmesignedin-updater` → Processes
2. **Click:** Create Process
3. **Process Name:** `Update Keep Me Signed In`
4. **Process Type:** Deployment

### Step 4: Add Process Step

**Step Name:** Update Okta Keep Me Signed In Configuration

**Step Type:** Shell

**Working Directory:** `${p:component/workDir}`

**Command:**

```bash
#!/bin/bash
set -e

# Map UCD variables to script variables
export OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
export OKTA_API_TOKEN="${pubsecure.okta.api_token}"
export ENVIRONMENT="${pubsecure.okta.env}"

# Log configuration (without sensitive data)
echo "=================================================="
echo "Okta Keep Me Signed In Update"
echo "=================================================="
echo "Okta Domain:     $OKTA_DOMAIN"
echo "Environment:     $ENVIRONMENT"
echo "Working Dir:     $(pwd)"
echo "=================================================="

# Check if CSV file exists for this environment
CSV_FILE="config/${ENVIRONMENT}/policy_rule_ids.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo "WARNING: No policy/rule ID configuration found at: $CSV_FILE"
    echo "Skipping Keep Me Signed In updates for $ENVIRONMENT"
    exit 0
fi

echo "Using configuration file: $CSV_FILE"

# Make scripts executable (in case permissions were lost)
chmod +x scripts/*.sh

# Run the update script
./scripts/update_keepmesignedin.sh \
    --csv-file "$CSV_FILE"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "=================================================="
    echo "Keep Me Signed In configuration updated successfully!"
    echo "=================================================="
else
    echo "=================================================="
    echo "ERROR: Keep Me Signed In update failed with exit code: $exit_code"
    echo "=================================================="
    exit $exit_code
fi
```

**Step Properties:**
- **Run on Failure:** Unchecked (fail deployment if this fails)
- **Precondition:** None (or add condition if you only want to run in certain environments)

### Step 5: Integrate into Application Process

Add the new component to your existing application deployment process:

```
┌──────────────────────────┐
│ Install Terraform        │
│ Component                │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Terraform Apply          │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Install okta-            │
│ keepmesignedin-updater   │
│ Component                │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Update Keep Me Signed In │
│ (Run Component Process)  │
└──────────────────────────┘
```

**To add the step:**

1. Open your Application Process
2. Add step: **Install Component**
   - Component: `okta-keepmesignedin-updater`
   - Select Version: Latest
3. Add step: **Run Component Process**
   - Component: `okta-keepmesignedin-updater`
   - Process: `Update Keep Me Signed In`
   - Run After: Install Component step

## Environment-Specific Configuration

### For Each Environment, Configure:

#### Dev1 Environment
```
UCD Variables:
  pubsecure.okta.org_name = dev1-ontsignin
  pubsecure.okta.base_url = oktapreview.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = dev1

CSV File:
  config/dev1/policy_rule_ids.csv
```

#### Dev2 Environment
```
UCD Variables:
  pubsecure.okta.org_name = dev2-ontsignin
  pubsecure.okta.base_url = oktapreview.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = dev2

CSV File:
  config/dev2/policy_rule_ids.csv
```

#### Test1 Environment
```
UCD Variables:
  pubsecure.okta.org_name = test1-ontsignin
  pubsecure.okta.base_url = oktapreview.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = test1

CSV File:
  config/test1/policy_rule_ids.csv
```

#### Test2 Environment
```
UCD Variables:
  pubsecure.okta.org_name = test2-ontsignin
  pubsecure.okta.base_url = oktapreview.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = test2

CSV File:
  config/test2/policy_rule_ids.csv
```

#### Stage Environment
```
UCD Variables:
  pubsecure.okta.org_name = stage-ontsignin
  pubsecure.okta.base_url = okta.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = stage  (or "staging" - both work)

CSV File:
  config/staging/policy_rule_ids.csv
  (also accessible via config/stage/policy_rule_ids.csv symlink)
```

#### Production Environment
```
UCD Variables:
  pubsecure.okta.org_name = ontsignin
  pubsecure.okta.base_url = okta.com
  pubsecure.okta.api_token = <secure-token>
  pubsecure.okta.env = prod

CSV File:
  config/prod/policy_rule_ids.csv
```

## Dry Run Mode (Recommended for First Deployment)

For your first deployment to each environment, use dry-run mode to verify configuration:

**Modify the process step command to add `--dry-run`:**

```bash
# Run the update script in dry-run mode
./scripts/update_keepmesignedin.sh \
    --csv-file "$CSV_FILE" \
    --dry-run
```

This will show what changes would be made without actually updating anything.

Once verified, remove the `--dry-run` flag for actual updates.

## Example: Complete UCD Process Step

Here's a complete example of the shell script for the UCD process step:

```bash
#!/bin/bash
###############################################################################
# UCD Process Step: Update Okta Keep Me Signed In Configuration
#
# This script reads UCD environment variables and updates Okta Access Policy
# rules with the Keep Me Signed In feature.
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Map UCD variables to script variables
export OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
export OKTA_API_TOKEN="${pubsecure.okta.api_token}"
export ENVIRONMENT="${pubsecure.okta.env}"

# Validate required variables
if [ -z "$OKTA_DOMAIN" ] || [ "$OKTA_DOMAIN" == "." ]; then
    echo "ERROR: OKTA_DOMAIN could not be constructed from UCD variables"
    echo "Check that pubsecure.okta.org_name and pubsecure.okta.base_url are set"
    exit 1
fi

if [ -z "$OKTA_API_TOKEN" ]; then
    echo "ERROR: OKTA_API_TOKEN is not set (pubsecure.okta.api_token)"
    exit 1
fi

if [ -z "$ENVIRONMENT" ]; then
    echo "ERROR: ENVIRONMENT is not set (pubsecure.okta.env)"
    exit 1
fi

# Log configuration (without sensitive data)
echo "=================================================="
echo "Okta Keep Me Signed In Update"
echo "=================================================="
echo "Okta Domain:     $OKTA_DOMAIN"
echo "Environment:     $ENVIRONMENT"
echo "Working Dir:     $(pwd)"
echo "Component:       ${p:component/name}"
echo "Version:         ${p:version/name}"
echo "=================================================="

# Check if CSV file exists for this environment
CSV_FILE="config/${ENVIRONMENT}/policy_rule_ids.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo ""
    echo "WARNING: No policy/rule ID configuration found at: $CSV_FILE"
    echo "Skipping Keep Me Signed In updates for $ENVIRONMENT"
    echo ""
    echo "To enable updates for this environment:"
    echo "  1. Create file: $CSV_FILE"
    echo "  2. Add your policy/rule IDs (see examples/)"
    echo "  3. Re-run this deployment"
    echo ""
    exit 0
fi

echo "Using configuration file: $CSV_FILE"
echo ""

# Count non-comment, non-empty lines in CSV (excluding header)
RULE_COUNT=$(grep -v '^#' "$CSV_FILE" | grep -v '^$' | tail -n +2 | wc -l)
echo "Found $RULE_COUNT rule(s) to update"
echo ""

# Make scripts executable (in case permissions were lost)
chmod +x scripts/*.sh src/*.py

# Run the update script
echo "Starting update process..."
echo ""

./scripts/update_keepmesignedin.sh \
    --csv-file "$CSV_FILE"

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "=================================================="
    echo "✓ Keep Me Signed In configuration updated successfully!"
    echo "=================================================="
else
    echo "=================================================="
    echo "✗ ERROR: Keep Me Signed In update failed"
    echo "Exit code: $exit_code"
    echo "=================================================="
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Okta API token has correct permissions"
    echo "  2. Verify policy/rule IDs in $CSV_FILE"
    echo "  3. Check Okta System Log for API errors"
    echo "  4. Review detailed logs above"
    exit $exit_code
fi
```

## Getting Policy and Rule IDs

You need to get the policy and rule IDs for each environment. Here's how:

### Method 1: Using Okta Admin Console

1. Log into your Okta tenant (e.g., `https://dev1-ontsignin.oktapreview.com/admin`)
2. Navigate to **Security** > **Authentication Policies**
3. Click on your policy name
4. The **Policy ID** is in the URL:
   ```
   https://dev1-ontsignin.oktapreview.com/admin/access/policies/00p1a2b3c4d5e6f7g8h9
                                                                 ^^^^^^^^^^^^^^^^^^^^
                                                                      Policy ID
   ```
5. Click on a rule name
6. The **Rule ID** is in the URL:
   ```
   https://dev1-ontsignin.oktapreview.com/admin/access/policies/00p.../rules/0pr9i8h7g6f5e4d3c2b1
                                                                              ^^^^^^^^^^^^^^^^^^^^
                                                                                   Rule ID
   ```

### Method 2: Using the API Client Script

Run this on your local machine or UCD agent:

```bash
# Set credentials for your environment
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_token_here"

# Run the script to list all policies and rules
python3 << 'EOF'
import os
import sys
sys.path.insert(0, 'src')
from okta_api_client import OktaAPIClient

client = OktaAPIClient(os.getenv('OKTA_DOMAIN'), os.getenv('OKTA_API_TOKEN'))

print("Okta Access Policies and Rules")
print("=" * 80)

policies = client.get_policies(policy_type='ACCESS_POLICY')

for policy in policies:
    print(f"\nPolicy: {policy['name']}")
    print(f"  Policy ID: {policy['id']}")
    print(f"  Status:    {policy.get('status', 'N/A')}")

    try:
        rules = client.get_policy_rules(policy['id'])
        print(f"  Rules ({len(rules)}):")

        for rule in rules:
            print(f"    - {rule['name']}")
            print(f"      Rule ID:  {rule['id']}")
            print(f"      Priority: {rule.get('priority', 'N/A')}")
            print(f"      Status:   {rule.get('status', 'N/A')}")
    except Exception as e:
        print(f"    Error fetching rules: {e}")

print("\n" + "=" * 80)
EOF
```

Copy the output and use it to populate your CSV files.

## Running Locally (Outside of UCD)

**YES!** You can absolutely run this script locally outside of UrbanCode Deploy. This is highly recommended for testing and development.

### Prerequisites for Local Testing

1. Python 3.7+ installed
2. Repository cloned locally
3. Okta API token for the environment you want to test

### Method 1: Using the Standard Script (Recommended for Local Testing)

This method uses the standard script with explicit environment variables:

```bash
# Clone the repository (if not already done)
cd okta_api_process

# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set environment variables for the tenant you want to test
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_dev1_api_token"
export ENVIRONMENT="dev1"

# Dry run first (recommended)
./scripts/update_keepmesignedin.sh \
    --csv-file "config/dev1/policy_rule_ids.csv" \
    --dry-run

# If dry run looks good, run without --dry-run
./scripts/update_keepmesignedin.sh \
    --csv-file "config/dev1/policy_rule_ids.csv"
```

### Method 2: Using the UCD Wrapper Locally

If you want to test the UCD wrapper script locally, you need to set the UCD variable format:

```bash
# Set variables in UCD format
export pubsecure.okta.org_name="dev1-ontsignin"
export pubsecure.okta.base_url="oktapreview.com"
export pubsecure.okta.api_token="your_dev1_api_token"
export pubsecure.okta.env="dev1"

# Note: Bash doesn't like dots in variable names, so use this instead:
export pubsecure_okta_org_name="dev1-ontsignin"
export pubsecure_okta_base_url="oktapreview.com"
export pubsecure_okta_api_token="your_dev1_api_token"
export pubsecure_okta_env="dev1"

# Then manually construct OKTA_DOMAIN
export OKTA_DOMAIN="${pubsecure_okta_org_name}.${pubsecure_okta_base_url}"
export OKTA_API_TOKEN="${pubsecure_okta_api_token}"
export ENVIRONMENT="${pubsecure_okta_env}"

# Run the standard script
./scripts/update_keepmesignedin.sh \
    --csv-file "config/${ENVIRONMENT}/policy_rule_ids.csv" \
    --dry-run
```

### Method 3: Direct Python Execution

For even more control, run the Python script directly:

```bash
# Set environment variables
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_dev1_api_token"

# Activate venv
source venv/bin/activate

# Add src to PYTHONPATH
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Run for a single rule
python3 src/update_keepmesignedin.py \
    --policy-id "00p1a2b3c4d5e6f7g8h9" \
    --rule-id "0pr9i8h7g6f5e4d3c2b1" \
    --dry-run

# Or run for bulk update
python3 src/update_keepmesignedin.py \
    --csv-file "config/dev1/policy_rule_ids.csv" \
    --dry-run

# With custom configuration
python3 src/update_keepmesignedin.py \
    --csv-file "config/dev1/policy_rule_ids.csv" \
    --config "examples/keep_me_signed_in_patch.json" \
    --dry-run
```

### Local Testing Workflow (Recommended)

Here's the recommended workflow for testing locally before deploying via UCD:

```bash
# 1. Get policy/rule IDs for your environment (run once per environment)
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_dev1_token"

python3 << 'EOF'
import os, sys
sys.path.insert(0, 'src')
from okta_api_client import OktaAPIClient

client = OktaAPIClient(os.getenv('OKTA_DOMAIN'), os.getenv('OKTA_API_TOKEN'))
policies = client.get_policies(policy_type='ACCESS_POLICY')

for policy in policies:
    print(f"\nPolicy: {policy['name']} (ID: {policy['id']})")
    rules = client.get_policy_rules(policy['id'])
    for rule in rules:
        print(f"  Rule: {rule['name']} (ID: {rule['id']})")
EOF

# 2. Add the IDs to your CSV file
# Edit config/dev1/policy_rule_ids.csv

# 3. Dry run to verify
./scripts/update_keepmesignedin.sh \
    --csv-file "config/dev1/policy_rule_ids.csv" \
    --dry-run

# 4. Review the output carefully

# 5. If it looks good, run without dry-run
./scripts/update_keepmesignedin.sh \
    --csv-file "config/dev1/policy_rule_ids.csv"

# 6. Verify in Okta Admin Console
# Log into dev1-ontsignin.oktapreview.com/admin
# Check Security > Authentication Policies > Your Policy > Rule
# Verify Keep Me Signed In settings are applied

# 7. Commit the CSV file to version control
git add config/dev1/policy_rule_ids.csv
git commit -m "Add Dev1 policy/rule IDs for Keep Me Signed In"

# 8. Now you're ready to deploy via UCD!
```

### Testing All Environments Locally

You can test all 6 environments locally before deploying to UCD:

```bash
# Dev1
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="$DEV1_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/dev1/policy_rule_ids.csv" --dry-run

# Dev2
export OKTA_DOMAIN="dev2-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="$DEV2_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/dev2/policy_rule_ids.csv" --dry-run

# Test1
export OKTA_DOMAIN="test1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="$TEST1_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/test1/policy_rule_ids.csv" --dry-run

# Test2
export OKTA_DOMAIN="test2-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="$TEST2_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/test2/policy_rule_ids.csv" --dry-run

# Stage
export OKTA_DOMAIN="stage-ontsignin.okta.com"
export OKTA_API_TOKEN="$STAGE_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/staging/policy_rule_ids.csv" --dry-run

# Prod
export OKTA_DOMAIN="ontsignin.okta.com"
export OKTA_API_TOKEN="$PROD_TOKEN"
./scripts/update_keepmesignedin.sh --csv-file "config/prod/policy_rule_ids.csv" --dry-run
```

## Testing Your Setup (UCD Deployment)

### Step 1: Test Locally First (see section above)

Before deploying through UCD, always test locally first using the methods described above.

### Step 2: Deploy to Dev1 Environment via UCD

Once local testing is successful:

```bash
# Set your environment variables
export OKTA_DOMAIN="dev1-ontsignin.oktapreview.com"
export OKTA_API_TOKEN="your_dev1_token"
export ENVIRONMENT="dev1"

# Dry run to verify configuration
./scripts/update_keepmesignedin.sh \
    --csv-file "config/dev1/policy_rule_ids.csv" \
    --dry-run
```

### Step 2: Deploy to Dev1 Environment

1. Go to UCD Application → Dev1 Environment
2. Click **Request Process**
3. Select your application process
4. Click **Submit**
5. Monitor the logs for the "Update Keep Me Signed In" step

### Step 3: Verify in Okta

1. Log into Dev1 Okta tenant
2. Navigate to **Security** > **Authentication Policies**
3. Click on your policy
4. Click on a rule you updated
5. Verify **Keep Me Signed In** section shows:
   - Post Auth: Allowed
   - Prompt Frequency: 15 minutes (or your configured value)

### Step 4: Promote to Other Environments

Once verified in Dev1, promote to:
- Dev2
- Staging
- Production

Each environment will use its own CSV file with environment-specific policy/rule IDs.

## Troubleshooting

### Issue: "OKTA_DOMAIN could not be constructed"

**Cause:** UCD variables `pubsecure.okta.org_name` or `pubsecure.okta.base_url` are not set for this environment.

**Solution:**
1. Check environment properties in UCD
2. Verify the variable names match exactly
3. Ensure variables are defined at the environment or application level

### Issue: "OKTA_API_TOKEN is not set"

**Cause:** The `pubsecure.okta.api_token` variable is not defined or is empty.

**Solution:**
1. Check the secure property is set for this environment
2. Verify the variable name matches exactly
3. Ensure the token is valid and not expired

### Issue: "No policy/rule ID configuration found"

**Cause:** The CSV file doesn't exist for this environment.

**Solution:**
1. Create `config/${ENVIRONMENT}/policy_rule_ids.csv`
2. Add your policy/rule IDs (see examples above)
3. Commit and create a new component version

### Issue: "Policy or Rule not found (404)"

**Cause:** Policy ID or Rule ID in CSV is incorrect or doesn't exist in this tenant.

**Solution:**
1. Verify IDs using Okta Admin Console
2. Ensure you're using the correct tenant's IDs
3. Update the CSV file with correct IDs

### Issue: "Permission denied (403)"

**Cause:** API token doesn't have required permissions.

**Solution:**
1. Log into Okta Admin Console
2. Go to **Security** > **API** > **Tokens**
3. Regenerate token with `okta.policies.manage` permission
4. Update `pubsecure.okta.api_token` in UCD

## Best Practices

1. **Use Dry Run First:**
   - Always test with `--dry-run` in a new environment first
   - Verify the output before running actual updates

2. **Environment-Specific CSV Files:**
   - Keep separate CSV files for each environment
   - Don't copy policy/rule IDs between environments
   - Each tenant has unique IDs

3. **Version Control CSV Files:**
   - Keep CSV files in version control
   - Review changes in pull requests
   - Document why IDs are added/removed

4. **Secure Token Management:**
   - Use UCD secure properties for API tokens
   - Rotate tokens quarterly
   - Use separate tokens per environment

5. **Monitor Deployments:**
   - Check UCD logs after each deployment
   - Verify changes in Okta Admin Console
   - Review Okta System Log for API calls

6. **Gradual Rollout:**
   - Test in Dev1 first
   - Then Dev2
   - Then Staging
   - Finally Production

## Component Versioning

When updating CSV files or scripts:

1. Make changes in your repository
2. Commit and push changes
3. Create new component version in UCD
4. Test in Dev1 environment
5. Promote version through environments

## Additional Resources

- [KEEP_ME_SIGNED_IN_GUIDE.md](KEEP_ME_SIGNED_IN_GUIDE.md) - Detailed guide for the update tool
- [URBANCODE_QUICKSTART.md](URBANCODE_QUICKSTART.md) - General UCD integration guide
- [README.md](README.md) - Main documentation
- [Okta Management API](https://developer.okta.com/docs/api/openapi/okta-management/management/tag/Policy/)

## Support Checklist

Before requesting support, verify:

- [ ] UCD variables are set for the environment (`pubsecure.okta.*`)
- [ ] CSV file exists for the environment (`config/${ENVIRONMENT}/policy_rule_ids.csv`)
- [ ] Policy and Rule IDs are correct for this tenant
- [ ] API token has correct permissions and is not expired
- [ ] Scripts are executable (`chmod +x scripts/*.sh`)
- [ ] Python 3.7+ is installed on the UCD agent
- [ ] Network connectivity from UCD agent to Okta

## Example CSV Files by Environment

### config/dev1/policy_rule_ids.csv
```csv
policyId,ruleId,description
00pDEV1POLICY00001,0prDEV1RULE000001,Dev1 App Access Policy - Default Rule
00pDEV1POLICY00001,0prDEV1RULE000002,Dev1 App Access Policy - MFA Rule
```

### config/dev2/policy_rule_ids.csv
```csv
policyId,ruleId,description
00pDEV2POLICY00001,0prDEV2RULE000001,Dev2 App Access Policy - Default Rule
00pDEV2POLICY00001,0prDEV2RULE000002,Dev2 App Access Policy - MFA Rule
```

### config/staging/policy_rule_ids.csv
```csv
policyId,ruleId,description
00pSTGPOLICY00001,0prSTGRULE0000001,Staging App Access Policy - Default Rule
00pSTGPOLICY00001,0prSTGRULE0000002,Staging App Access Policy - MFA Rule
```

### config/prod/policy_rule_ids.csv
```csv
policyId,ruleId,description
00pPRODPOLICY0001,0prPRODRULE000001,Production App Access Policy - Default Rule
00pPRODPOLICY0001,0prPRODRULE000002,Production App Access Policy - MFA Rule
00pPRODPOLICY0002,0prPRODRULE000003,Production Admin Access Policy - MFA Rule
```

---

## Quick Reference Card

**UCD Variable Mapping:**
```bash
OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
OKTA_API_TOKEN="${pubsecure.okta.api_token}"
ENVIRONMENT="${pubsecure.okta.env}"
```

**CSV File Location:**
```
config/${ENVIRONMENT}/policy_rule_ids.csv
```

**Process Step Command:**
```bash
export OKTA_DOMAIN="${pubsecure.okta.org_name}.${pubsecure.okta.base_url}"
export OKTA_API_TOKEN="${pubsecure.okta.api_token}"
export ENVIRONMENT="${pubsecure.okta.env}"

./scripts/update_keepmesignedin.sh \
    --csv-file "config/${ENVIRONMENT}/policy_rule_ids.csv"
```
