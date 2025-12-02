# Okta API Access Policy Manager

This project provides tools to manage Okta Access Policy rules via the native Okta Management API. It's designed to complement Terraform by handling features not yet supported by the Terraform Okta provider, such as the "Keep Me Signed In" feature for access policy rules.

## Problem Statement

The Okta Terraform provider doesn't support all features available in the native Okta Management API. Specifically, access policy rules lack support for:
- `usePersistentCookie` (Keep Me Signed In feature)
- Advanced session management settings
- Some verification method constraints

This project fills that gap by providing API-based management that runs after Terraform deployment.

## Solution

This project provides **two approaches** for managing Okta Access Policy rules:

### Approach 1: Update Existing Rules by ID (Recommended)
**Use this when:** You have existing policy rules created by Terraform and need to add the "Keep Me Signed In" feature.

- Update rules using policy ID and rule ID
- Merges `keepMeSignedIn` configuration into existing rules
- Supports single rule updates or bulk updates from CSV
- **See: [KEEP_ME_SIGNED_IN_GUIDE.md](KEEP_ME_SIGNED_IN_GUIDE.md)** for detailed instructions

### Approach 2: Create/Update Rules by Name
**Use this when:** You want to manage complete rule configurations from JSON files.

- Creates new rules or updates existing ones by name
- Manages full rule configuration including conditions, actions, priority
- Useful for deploying new rules alongside Terraform
- Integrates into Jenkins/UrbanCode Deploy/Velocity pipeline

Both approaches integrate into your existing pipeline:

1. **Jenkins** - Sets up remote Terraform server
2. **UrbanCode Deploy** - Manages variables
3. **Velocity** - Executes Terraform plan and apply
4. **This Tool** - Applies Okta policy rules via API (post-Terraform)

## Architecture

```
okta_api_process/
├── src/
│   ├── okta_api_client.py             # Core Okta API client
│   ├── access_policy_manager.py       # Policy rule management (by name)
│   └── update_keepmesignedin.py       # Keep Me Signed In updater (by ID)
├── scripts/
│   ├── update_keepmesignedin.sh       # Update existing rules by ID
│   ├── apply_access_policies.sh       # Create/update rules by name
│   └── urbancode_wrapper.sh           # UrbanCode Deploy integration
├── config/
│   ├── policy_rule_ids.csv            # Policy/Rule ID mappings for bulk updates
│   ├── dev1/
│   │   ├── policy_rule_ids.csv        # Dev1 policy/rule IDs
│   │   └── rules/                     # Dev1 rule JSON files
│   ├── dev2/
│   │   ├── policy_rule_ids.csv        # Dev2 policy/rule IDs
│   │   └── rules/                     # Dev2 rule JSON files
│   ├── test1/
│   │   ├── policy_rule_ids.csv        # Test1 policy/rule IDs
│   │   └── rules/                     # Test1 rule JSON files
│   ├── test2/
│   │   ├── policy_rule_ids.csv        # Test2 policy/rule IDs
│   │   └── rules/                     # Test2 rule JSON files
│   ├── stage/
│   │   ├── policy_rule_ids.csv        # Stage policy/rule IDs
│   │   └── rules/                     # Stage rule JSON files
│   └── prod/
│       ├── policy_rule_ids.csv        # Production policy/rule IDs
│       └── rules/                     # Production rule JSON files
├── examples/
│   ├── access_policy_rule_keep_me_signed_in.json
│   ├── access_policy_rule_basic.json
│   └── keep_me_signed_in_patch.json   # Minimal config for KMSI updates
├── requirements.txt                   # Python dependencies
├── KEEP_ME_SIGNED_IN_GUIDE.md         # Detailed guide for updating by ID
└── URBANCODE_QUICKSTART.md            # UrbanCode Deploy integration guide
```

## Prerequisites

- Python 3.7 or higher
- Okta API token with policy management permissions
- Access to your Okta domain

### Creating an Okta API Token

1. Log into your Okta admin console
2. Navigate to **Security** > **API** > **Tokens**
3. Click **Create Token**
4. Name it (e.g., "Terraform Post-Deployment")
5. Save the token securely (you'll only see it once)

Required permissions:
- `okta.policies.manage`
- `okta.policies.read`

## Quick Start

### Update Existing Rules with "Keep Me Signed In" Feature

If you have existing Okta Access Policy rules and want to add the "Keep Me Signed In" feature:

```bash
# Set credentials
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_api_token"

# Update a single rule by ID
./scripts/update_keepmesignedin.sh \
  --policy-id "00p1a2b3c4d5e6f7g8h9" \
  --rule-id "0pr9i8h7g6f5e4d3c2b1"

# Or bulk update from CSV file
./scripts/update_keepmesignedin.sh \
  --csv-file config/policy_rule_ids.csv
```

**📖 See [KEEP_ME_SIGNED_IN_GUIDE.md](KEEP_ME_SIGNED_IN_GUIDE.md) for complete instructions including:**
- How to get your policy and rule IDs
- CSV file format for bulk updates
- Custom configuration options
- UrbanCode Deploy integration

### UrbanCode Deploy Integration with Custom Variables

If you have custom UCD environment variables (e.g., `pubsecure.okta.*`), use the UCD-specific wrapper:

```bash
# In your UCD process step:
./scripts/ucd_keepmesignedin_wrapper.sh
```

The wrapper automatically maps your UCD variables:
- `OKTA_DOMAIN` ← `${pubsecure.okta.org_name}.${pubsecure.okta.base_url}`
- `OKTA_API_TOKEN` ← `${pubsecure.okta.api_token}`
- `ENVIRONMENT` ← `${pubsecure.okta.env}`

**📖 See [UCD_ENVIRONMENT_VARIABLES.md](UCD_ENVIRONMENT_VARIABLES.md) for:**
- Complete UCD integration guide with your variable naming convention
- Step-by-step setup instructions for all 6 environments (Dev1, Dev2, Test1, Test2, Stage, Prod)
- Environment-specific configuration examples
- **Complete local testing guide** - YES, you can run this outside of UCD!
- Troubleshooting for UCD deployments

### Create/Update Rules from JSON Files

If you want to deploy complete rule configurations:

```bash
# Set credentials
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_api_token"

# Apply a single rule
./scripts/apply_access_policies.sh \
  --policy "My Access Policy" \
  --rule-file "examples/access_policy_rule_keep_me_signed_in.json"

# Or apply all rules from a directory
./scripts/apply_access_policies.sh \
  --policy "My Access Policy" \
  --rules-dir "config/prod/rules"
```

## Installation

### Option 1: Direct Installation (Recommended for Testing)

```bash
# Clone or extract to your deployment server
cd okta_api_process

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your Okta credentials
```

### Option 2: UrbanCode Deploy Integration

In your UrbanCode Deploy component:

1. **Add Component Properties:**
   - `OKTA_DOMAIN` - Your Okta domain (e.g., `your-domain.okta.com`)
   - `OKTA_API_TOKEN` - Your Okta API token (mark as secure)
   - `POLICY_NAME` - Name of the access policy to update
   - `ENVIRONMENT` - Environment name (dev1, dev2, test1, test2, stage, prod)

2. **Add Component Process Step:**
   - **Step Type:** Shell
   - **Command:**
     ```bash
     cd ${p:component/workDir}
     ./scripts/urbancode_wrapper.sh
     ```
   - **Run After:** Your Terraform apply step

## Configuration

### Environment Variables

Required environment variables (set via UrbanCode Deploy or `.env` file):

```bash
OKTA_DOMAIN=your-domain.okta.com
OKTA_API_TOKEN=your_api_token_here
ENVIRONMENT=dev
LOG_LEVEL=INFO
```

### Rule JSON Files

Place your rule JSON files in the appropriate environment directory:
- `config/dev1/rules/*.json`
- `config/dev2/rules/*.json`
- `config/test1/rules/*.json`
- `config/test2/rules/*.json`
- `config/stage/rules/*.json`
- `config/prod/rules/*.json`

## Usage

### Standalone Usage

Apply a single rule from a file:

```bash
export OKTA_DOMAIN="your-domain.okta.com"
export OKTA_API_TOKEN="your_token"

./scripts/apply_access_policies.sh \
  --policy "My Access Policy" \
  --rule-file "examples/access_policy_rule_keep_me_signed_in.json"
```

Apply all rules from a directory:

```bash
./scripts/apply_access_policies.sh \
  --policy "My Access Policy" \
  --rules-dir "config/prod/rules"
```

### Python Module Usage

```python
#!/usr/bin/env python3
import os
from okta_api_client import OktaAPIClient
from access_policy_manager import AccessPolicyManager

# Initialize client
client = OktaAPIClient(
    domain=os.getenv('OKTA_DOMAIN'),
    api_token=os.getenv('OKTA_API_TOKEN')
)

# Create manager
manager = AccessPolicyManager(client)

# Apply rule from file
result = manager.apply_rule_from_file(
    policy_name="My Access Policy",
    rule_file="config/prod/rules/keep_me_signed_in.json",
    update_if_exists=True
)

print(f"Rule applied: {result.get('name')}")
```

### UrbanCode Deploy Integration

After configuring component properties and adding the process step, the script will automatically:

1. Read configuration from UrbanCode Deploy properties
2. Locate rule files in `config/${ENVIRONMENT}/rules/`
3. Apply all rules to the specified policy
4. Update existing rules or create new ones
5. Report success/failure back to UrbanCode Deploy

## Example: Keep Me Signed In Feature

The "Keep Me Signed In" feature requires setting `usePersistentCookie: true` in the session configuration. Here's an example rule:

```json
{
  "name": "Allow with Keep Me Signed In",
  "status": "ACTIVE",
  "priority": 1,
  "type": "ACCESS_POLICY",
  "conditions": {
    "network": {
      "connection": "ANYWHERE"
    },
    "people": {
      "users": {
        "include": ["EVERYONE"]
      }
    }
  },
  "actions": {
    "appSignOn": {
      "access": "ALLOW",
      "verificationMethod": {
        "type": "ASSURANCE",
        "factorMode": "1FA",
        "reauthenticateIn": "PT2H"
      },
      "session": {
        "usePersistentCookie": true,
        "maxSessionIdleMinutes": 120,
        "maxSessionLifetimeMinutes": 0
      }
    }
  }
}
```

Key settings:
- `usePersistentCookie: true` - Enables "Keep Me Signed In"
- `maxSessionIdleMinutes: 120` - Session expires after 2 hours of inactivity
- `maxSessionLifetimeMinutes: 0` - No maximum lifetime (stays signed in)

## Pipeline Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Jenkins                                                      │
│ - Sets up remote Terraform server                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ UrbanCode Deploy v7.3.2.7.1168134                           │
│ - Manages variables (OKTA_DOMAIN, OKTA_API_TOKEN, etc.)     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Velocity                                                     │
│ - Executes Terraform plan                                   │
│ - Executes Terraform apply                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ This Tool (Post-Terraform)                                  │
│ - Reads rules from config/${ENVIRONMENT}/rules/             │
│ - Applies access policy rules via Okta Management API       │
│ - Handles features not supported by Terraform                │
└─────────────────────────────────────────────────────────────┘
```

## Command Line Options

```
./scripts/apply_access_policies.sh [options]

Options:
  -e, --env ENV          Environment name (dev1, dev2, test1, test2, stage, prod)
  -p, --policy NAME      Policy name to update (required)
  -r, --rules-dir DIR    Directory containing rule JSON files
  -f, --rule-file FILE   Single rule JSON file to apply
  -c, --create-only      Only create new rules, don't update existing
  -h, --help             Show help message

Environment Variables:
  OKTA_DOMAIN           Your Okta domain (required)
  OKTA_API_TOKEN        Okta API token (required)
  LOG_LEVEL             Logging level (default: INFO)
  ENVIRONMENT           Environment name (default: dev)
```

## Behavior

- **Update by default:** If a rule with the same name exists, it will be updated
- **Create if missing:** If a rule doesn't exist, it will be created
- **Name matching:** Rules are matched by the `name` field in the JSON
- **Priority handling:** Ensure rule priorities don't conflict
- **Status:** Rules can be ACTIVE or INACTIVE

## API Reference

The tool uses the [Okta Management API for Policies](https://developer.okta.com/docs/api/openapi/okta-management/management/tag/Policy/).

Key endpoints:
- `GET /api/v1/policies` - List policies
- `GET /api/v1/policies/{policyId}/rules` - List rules
- `POST /api/v1/policies/{policyId}/rules` - Create rule
- `PUT /api/v1/policies/{policyId}/rules/{ruleId}` - Update rule

## Troubleshooting

### Common Issues

**Issue:** `Policy 'My Policy' not found`
- Ensure the policy exists in Okta (created by Terraform or manually)
- Check policy name spelling (case-sensitive)
- Verify API token has permission to read policies

**Issue:** `OKTA_DOMAIN environment variable is not set`
- In UrbanCode Deploy: Check component properties are set
- In standalone: Ensure `.env` file exists or variables are exported

**Issue:** `403 Forbidden` when calling API
- Verify API token is valid and not expired
- Check token has `okta.policies.manage` permission
- Ensure token is associated with correct Okta domain

**Issue:** Rule not updating as expected
- Check rule name matches exactly (case-sensitive)
- Review logs for API response details
- Verify JSON structure matches Okta API schema

### Debug Mode

Enable detailed logging:

```bash
export LOG_LEVEL=DEBUG
./scripts/apply_access_policies.sh --policy "My Policy" --rules-dir "config/dev/rules"
```

### Testing Individual Rules

Test a rule file before deployment:

```bash
# Validate JSON syntax
python3 -m json.tool examples/access_policy_rule_keep_me_signed_in.json

# Dry run (read existing rules without changes)
python3 src/access_policy_manager.py \
  --policy-name "My Policy" \
  --rule-file "examples/access_policy_rule_keep_me_signed_in.json" \
  --create-only
```

## Security Considerations

1. **API Token Storage:**
   - Never commit `.env` file to version control
   - Use UrbanCode Deploy secure properties for production
   - Rotate tokens regularly

2. **Least Privilege:**
   - Create dedicated API token for this tool
   - Grant only necessary permissions (`okta.policies.manage`)
   - Use separate tokens per environment if possible

3. **Audit Logging:**
   - All API calls are logged in Okta System Log
   - Review logs regularly for unexpected changes
   - Tool logs include timestamps and operation details

## Best Practices

1. **Version Control:**
   - Store rule JSON files in version control
   - Use separate directories for each environment
   - Review rule changes in pull requests

2. **Testing:**
   - Test rule changes in dev environment first
   - Validate JSON syntax before deployment
   - Use `--create-only` flag for initial testing

3. **Naming Conventions:**
   - Use descriptive rule names
   - Include environment in rule name if needed
   - Maintain consistent naming across environments

4. **Rule Priority:**
   - Number rules with gaps (1, 10, 20) for flexibility
   - Lower numbers = higher priority
   - Document priority scheme in rule files

## Migration from Terraform

If you have existing rules managed by Terraform:

1. **Export current rule configuration:**
   ```bash
   # Use the API client to read existing rules
   python3 -c "
   from okta_api_client import OktaAPIClient
   import json, os
   client = OktaAPIClient(os.getenv('OKTA_DOMAIN'), os.getenv('OKTA_API_TOKEN'))
   rules = client.get_policy_rules('YOUR_POLICY_ID')
   print(json.dumps(rules, indent=2))
   " > current_rules.json
   ```

2. **Create JSON files from Terraform state**
3. **Remove rule from Terraform configuration** (if migrating completely)
4. **Apply via this tool** to maintain state
5. **Add session configuration** for Keep Me Signed In feature

## Contributing

When adding features or fixing bugs:

1. Test changes in dev environment
2. Update documentation
3. Add example configurations
4. Follow existing code style
5. Include error handling and logging

## Support

For issues related to:
- **Okta API:** See [Okta Developer Documentation](https://developer.okta.com/docs/api/)
- **UrbanCode Deploy:** Consult IBM UrbanCode Deploy documentation
- **This Tool:** Check logs and troubleshooting section above

## License

This project is provided as-is for use in your organization's deployment pipeline.

## Additional Resources

- [Okta Management API Documentation](https://developer.okta.com/docs/api/openapi/okta-management/management/tag/Policy/)
- [Okta Access Policies](https://help.okta.com/en-us/content/topics/security/policies.htm)
- [UrbanCode Deploy Documentation](https://www.ibm.com/docs/en/urbancode-deploy/7.3.2)
- [Terraform Okta Provider](https://registry.terraform.io/providers/okta/okta/latest/docs)
