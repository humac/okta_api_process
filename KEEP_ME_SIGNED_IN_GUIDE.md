# Keep Me Signed In - Update Guide

This guide shows you how to update existing Okta Access Policy rules with the "Keep Me Signed In" feature using policy IDs and rule IDs.

## What is "Keep Me Signed In"?

The "Keep Me Signed In" feature allows users to stay authenticated for an extended period. This feature requires setting the `keepMeSignedIn` configuration in access policy rules:

```json
"actions": {
  "appSignOn": {
    "keepMeSignedIn": {
      "postAuth": "ALLOWED",
      "postAuthPromptFrequency": "PT15M"
    }
  }
}
```

**Parameters:**
- `postAuth`: `ALLOWED` or `DENIED` - Whether to allow Keep Me Signed In
- `postAuthPromptFrequency`: Duration in ISO 8601 format (e.g., `PT15M` = 15 minutes, `PT1H` = 1 hour)

## Prerequisites

1. **Okta API Token** with policy management permissions
2. **Policy IDs and Rule IDs** for the rules you want to update
3. Python 3.7+ installed

## Step 1: Get Your Policy and Rule IDs

### Option A: Using Okta Admin Console

1. Log into Okta Admin Console
2. Navigate to **Security** > **Authentication Policies**
3. Click on your policy name
4. The Policy ID is in the URL: `https://your-domain.okta.com/admin/access/policies/{POLICY_ID}`
5. Click on a rule name
6. The Rule ID is in the URL: `https://your-domain.okta.com/admin/access/policies/{POLICY_ID}/rules/{RULE_ID}`

### Option B: Using the API Client

```bash
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_token"

# List all access policies
python3 src/okta_api_client.py

# Or use this script to list policies and rules
python3 << 'EOF'
import os
from okta_api_client import OktaAPIClient

client = OktaAPIClient(os.getenv('OKTA_DOMAIN'), os.getenv('OKTA_API_TOKEN'))

# Get all access policies
policies = client.get_policies(policy_type='ACCESS_POLICY')

for policy in policies:
    print(f"\nPolicy: {policy['name']}")
    print(f"  Policy ID: {policy['id']}")

    # Get rules for this policy
    rules = client.get_policy_rules(policy['id'])
    for rule in rules:
        print(f"  Rule: {rule['name']}")
        print(f"    Rule ID: {rule['id']}")
        print(f"    Priority: {rule.get('priority', 'N/A')}")
EOF
```

## Step 2: Update Rules

### Method 1: Update a Single Rule

Use this when you need to update just one policy rule:

```bash
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_token"

./scripts/update_keepmesignedin.sh \
  --policy-id "00p1a2b3c4d5e6f7g8h9" \
  --rule-id "0pr9i8h7g6f5e4d3c2b1"
```

**With custom configuration:**

```bash
./scripts/update_keepmesignedin.sh \
  --policy-id "00p1a2b3c4d5e6f7g8h9" \
  --rule-id "0pr9i8h7g6f5e4d3c2b1" \
  --config examples/keep_me_signed_in_patch.json
```

### Method 2: Bulk Update from CSV File

Use this when you need to update multiple policy rules at once.

#### Step 2.1: Create CSV File

Edit `config/policy_rule_ids.csv` and add your policy/rule ID pairs:

```csv
policyId,ruleId,description
00p1a2b3c4d5e6f7g8h9,0pr9i8h7g6f5e4d3c2b1,Production App Access Policy - Default Rule
00p9z8y7x6w5v4u3t2s1,0pr1s2t3u4v5w6x7y8z9,Dev App Access Policy - Allow All Rule
00pXXXXXXXXXXXXXXXXX,0prYYYYYYYYYYYYYYYYY,Staging App Access Policy - MFA Rule
```

**Column Definitions:**
- `policyId` - The Okta policy ID (starts with `00p`)
- `ruleId` - The Okta rule ID (starts with `0pr`)
- `description` - Optional description for your reference

#### Step 2.2: Run Bulk Update

**Dry run first (recommended):**

```bash
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_token"

./scripts/update_keepmesignedin.sh \
  --csv-file config/policy_rule_ids.csv \
  --dry-run
```

This will show you what changes would be made WITHOUT actually updating anything.

**Apply changes:**

```bash
./scripts/update_keepmesignedin.sh \
  --csv-file config/policy_rule_ids.csv
```

## Step 3: Verify Changes

### In Okta Admin Console

1. Log into Okta Admin Console
2. Navigate to **Security** > **Authentication Policies**
3. Click on your policy
4. Click on the rule you updated
5. Scroll to **Keep Me Signed In** section
6. Verify settings are correct

### Using the API

```bash
python3 << 'EOF'
import os
import json
from okta_api_client import OktaAPIClient

client = OktaAPIClient(os.getenv('OKTA_DOMAIN'), os.getenv('OKTA_API_TOKEN'))

# Replace with your policy and rule IDs
policy_id = "00p1a2b3c4d5e6f7g8h9"
rule_id = "0pr9i8h7g6f5e4d3c2b1"

rule = client.get_policy_rule(policy_id, rule_id)

# Check if Keep Me Signed In is configured
kmsi = rule.get('actions', {}).get('appSignOn', {}).get('keepMeSignedIn', {})

if kmsi:
    print(f"Keep Me Signed In configuration for rule '{rule['name']}':")
    print(json.dumps(kmsi, indent=2))
else:
    print("Keep Me Signed In not configured")
EOF
```

## Configuration Options

### Default Configuration

If you don't specify a `--config` file, the default configuration is:

```json
{
  "actions": {
    "appSignOn": {
      "keepMeSignedIn": {
        "postAuth": "ALLOWED",
        "postAuthPromptFrequency": "PT15M"
      }
    }
  }
}
```

### Custom Configuration

Create a JSON file (e.g., `my_kmsi_config.json`):

```json
{
  "actions": {
    "appSignOn": {
      "keepMeSignedIn": {
        "postAuth": "ALLOWED",
        "postAuthPromptFrequency": "PT1H"
      }
    }
  }
}
```

Then use it:

```bash
./scripts/update_keepmesignedin.sh \
  --policy-id "00p..." \
  --rule-id "0pr..." \
  --config my_kmsi_config.json
```

### Frequency Options

Common `postAuthPromptFrequency` values:

- `PT5M` - 5 minutes
- `PT15M` - 15 minutes (default)
- `PT30M` - 30 minutes
- `PT1H` - 1 hour
- `PT2H` - 2 hours
- `PT4H` - 4 hours
- `PT8H` - 8 hours
- `PT12H` - 12 hours
- `PT24H` - 24 hours

## Integration with UrbanCode Deploy

### Option 1: Update After Terraform Deployment

Add this step after your Terraform apply in UrbanCode Deploy:

```bash
# In your UrbanCode Deploy process step
cd ${p:component/workDir}

# Run the update
./scripts/update_keepmesignedin.sh \
  --csv-file config/${ENVIRONMENT}/policy_rule_ids.csv
```

### Option 2: Separate Process

Create a dedicated UrbanCode Deploy component process:

**Process Name:** Update Okta Keep Me Signed In

**Step Configuration:**
```bash
cd ${p:component/workDir}

# Check if CSV file exists
CSV_FILE="config/${ENVIRONMENT}/policy_rule_ids.csv"
if [ ! -f "$CSV_FILE" ]; then
    echo "No policy/rule IDs configured for ${ENVIRONMENT}, skipping"
    exit 0
fi

# Run update
./scripts/update_keepmesignedin.sh --csv-file "$CSV_FILE"
```

## Environment-Specific Configuration

Organize your CSV files by environment:

```
config/
├── dev/
│   └── policy_rule_ids.csv       # Dev policy/rule IDs
├── staging/
│   └── policy_rule_ids.csv       # Staging policy/rule IDs
└── prod/
    └── policy_rule_ids.csv       # Production policy/rule IDs
```

In your deployment script:

```bash
ENVIRONMENT="${ENVIRONMENT:-dev}"
CSV_FILE="config/${ENVIRONMENT}/policy_rule_ids.csv"

./scripts/update_keepmesignedin.sh --csv-file "$CSV_FILE"
```

## Troubleshooting

### Issue: Policy or Rule Not Found (404)

**Error:** `404 Client Error: Not Found`

**Causes:**
1. Incorrect policy ID or rule ID
2. Policy/rule was deleted
3. Wrong Okta domain

**Solution:**
- Verify IDs using Okta Admin Console or API client
- Check you're connected to the correct Okta domain

### Issue: Permission Denied (403)

**Error:** `403 Client Error: Forbidden`

**Causes:**
1. API token doesn't have policy management permissions
2. API token expired

**Solution:**
- Regenerate API token with correct permissions
- Update `OKTA_API_TOKEN` environment variable

### Issue: Rule Update Fails Validation

**Error:** `400 Client Error: Bad Request`

**Causes:**
1. Invalid `postAuthPromptFrequency` format
2. Conflicting configuration with existing rule settings

**Solution:**
- Use ISO 8601 duration format (e.g., `PT15M`)
- Review error message for specific validation issues
- Use `--dry-run` to preview changes before applying

### Issue: CSV File Not Found

**Error:** `CSV file not found: config/policy_rule_ids.csv`

**Solution:**
- Create the CSV file with proper headers
- Check file path is correct
- Ensure file has proper permissions

## Best Practices

1. **Always dry run first:**
   ```bash
   ./scripts/update_keepmesignedin.sh --csv-file config/policy_rule_ids.csv --dry-run
   ```

2. **Test in dev environment first:**
   - Update rules in dev
   - Test user experience
   - Then promote to staging/production

3. **Document your policy/rule IDs:**
   - Use descriptive descriptions in CSV files
   - Keep CSV files in version control
   - Update as policies/rules change

4. **Use environment-specific CSV files:**
   - Separate CSV files for dev/staging/prod
   - Different policies may exist in each environment

5. **Monitor Okta System Log:**
   - Review API calls in Okta System Log
   - Verify changes were applied correctly
   - Check for any errors or warnings

## Python API Usage

If you prefer to use Python directly:

```python
#!/usr/bin/env python3
import os
from okta_api_client import OktaAPIClient
from update_keepmesignedin import KeepMeSignedInUpdater, load_keep_me_signed_in_config

# Initialize
client = OktaAPIClient(
    os.getenv('OKTA_DOMAIN'),
    os.getenv('OKTA_API_TOKEN')
)
updater = KeepMeSignedInUpdater(client)

# Load configuration
kmsi_config = load_keep_me_signed_in_config()

# Update single rule
result = updater.update_rule_by_id(
    policy_id="00p1a2b3c4d5e6f7g8h9",
    rule_id="0pr9i8h7g6f5e4d3c2b1",
    keep_me_signed_in_config=kmsi_config,
    dry_run=False
)

print(f"Updated rule: {result.get('name')}")
```

## Examples

### Example 1: Update Production Rule

```bash
# Set credentials
export OKTA_DOMAIN="mycompany.okta.com"
export OKTA_API_TOKEN="00abc...xyz"

# Update single production rule
./scripts/update_keepmesignedin.sh \
  --policy-id "00p1a2b3c4d5e6f7g8h9" \
  --rule-id "0pr9i8h7g6f5e4d3c2b1"
```

### Example 2: Bulk Update Multiple Environments

```bash
# Create CSV files for each environment
cat > config/dev/policy_rule_ids.csv << EOF
policyId,ruleId,description
00pDEV1111111111111,0prDEV2222222222222,Dev Policy - Default Rule
EOF

cat > config/prod/policy_rule_ids.csv << EOF
policyId,ruleId,description
00pPROD111111111111,0prPROD222222222222,Prod Policy - Default Rule
EOF

# Update dev
ENVIRONMENT=dev
./scripts/update_keepmesignedin.sh --csv-file config/${ENVIRONMENT}/policy_rule_ids.csv

# Update prod (after testing in dev)
ENVIRONMENT=prod
./scripts/update_keepmesignedin.sh --csv-file config/${ENVIRONMENT}/policy_rule_ids.csv
```

### Example 3: Custom Frequency

```bash
# Create custom config with 1-hour frequency
cat > config/kmsi_1hour.json << EOF
{
  "actions": {
    "appSignOn": {
      "keepMeSignedIn": {
        "postAuth": "ALLOWED",
        "postAuthPromptFrequency": "PT1H"
      }
    }
  }
}
EOF

# Apply custom config
./scripts/update_keepmesignedin.sh \
  --policy-id "00p..." \
  --rule-id "0pr..." \
  --config config/kmsi_1hour.json
```

## Next Steps

After updating your rules:

1. **Test the feature:**
   - Log into an application protected by the policy
   - Verify "Keep me signed in" checkbox appears
   - Test that sessions persist as expected

2. **Monitor usage:**
   - Check Okta System Log for authentication events
   - Review user feedback
   - Adjust frequency settings if needed

3. **Document changes:**
   - Update your runbooks
   - Inform security team
   - Update user documentation

## Additional Resources

- [Okta Access Policies Documentation](https://help.okta.com/en-us/content/topics/security/policies.htm)
- [Okta Management API - Policies](https://developer.okta.com/docs/api/openapi/okta-management/management/tag/Policy/)
- [ISO 8601 Duration Format](https://en.wikipedia.org/wiki/ISO_8601#Durations)
