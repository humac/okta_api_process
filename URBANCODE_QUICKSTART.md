# UrbanCode Deploy 7.3.2 - Quick Start Guide

This guide provides step-by-step instructions for integrating the Okta API Access Policy Manager into your existing UrbanCode Deploy pipeline.

## Overview

Your current setup:
- **Jenkins** - Sets up remote Terraform server
- **UrbanCode Deploy 7.3.2.7.1168134** - Manages variables
- **Velocity** - Executes Terraform plan and apply
- **This tool** - Applies Okta policy rules via API (NEW)

## Integration Steps

### Step 1: Create UrbanCode Deploy Component

1. Log into UrbanCode Deploy
2. Navigate to **Components** > **Create Component**
3. Configure:
   - **Name:** `okta-api-policy-manager`
   - **Type:** Standard Component
   - **Source Config Type:** File System (Copy)
   - **Base Path:** Path to this repository

### Step 2: Define Component Properties

Add these properties to your component (or inherit from application/environment):

| Property Name | Type | Required | Default | Description |
|--------------|------|----------|---------|-------------|
| `OKTA_DOMAIN` | String | Yes | - | Your Okta domain (e.g., `your-domain.okta.com`) |
| `OKTA_API_TOKEN` | Secure String | Yes | - | Okta API token with policy management permissions |
| `POLICY_NAME` | String | Yes | - | Name of the access policy to update |
| `ENVIRONMENT` | String | Yes | `dev1` | Environment name (dev1, dev2, test1, test2, stage, prod) |
| `LOG_LEVEL` | String | No | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

**Setting Properties:**

```
Component Properties:
  - POLICY_NAME = "My Application Access Policy"

Environment Properties (dev):
  - OKTA_DOMAIN = "dev-12345.okta.com"
  - OKTA_API_TOKEN = "00abc...xyz" (secure)
  - ENVIRONMENT = "dev"

Environment Properties (prod):
  - OKTA_DOMAIN = "your-domain.okta.com"
  - OKTA_API_TOKEN = "00def...uvw" (secure)
  - ENVIRONMENT = "prod"
```

### Step 3: Create Component Process

1. In your component, go to **Processes** > **Create Process**
2. **Process Name:** `Apply Okta Access Policies`
3. **Process Type:** Deployment
4. Add process step:

**Step Configuration:**

```
Step Name: Apply Okta Policy Rules
Step Type: Shell
Working Directory: ${p:component/workDir}
Command:
  chmod +x scripts/*.sh
  ./scripts/urbancode_wrapper.sh
```

**Environment Variables:**
The script will automatically read these from UrbanCode Deploy properties:
- `${OKTA_DOMAIN}`
- `${OKTA_API_TOKEN}`
- `${POLICY_NAME}`
- `${ENVIRONMENT}`

### Step 4: Integrate with Existing Application Process

Update your application process to include the new component:

```
Your Existing Process:
1. [Existing] Jenkins - Setup Terraform Server
2. [Existing] Terraform - Plan
3. [Existing] Terraform - Apply
4. [NEW] Install Component: okta-api-policy-manager
5. [NEW] Run Process: Apply Okta Access Policies
```

**Process Flow:**

```
┌──────────────────────────┐
│ Terraform Apply          │
│ (Existing Step)          │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Install okta-api-        │
│ policy-manager           │
│ Component                │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Apply Okta Access        │
│ Policies                 │
│ (New Process)            │
└──────────────────────────┘
```

### Step 5: Prepare Rule Configuration Files

Place your rule JSON files in the appropriate environment directory within the component:

```
okta_api_process/
└── config/
    ├── dev1/
    │   └── rules/
    │       ├── 01_keep_me_signed_in.json
    │       └── 02_default_rule.json
    ├── dev2/
    │   └── rules/
    ├── test1/
    │   └── rules/
    ├── test2/
    │   └── rules/
    ├── stage/
    │   └── rules/
    │       └── keep_me_signed_in.json
    └── prod/
        └── rules/
            └── keep_me_signed_in.json
```

**Example Rule File:**

`config/prod/rules/01_keep_me_signed_in.json`:
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

### Step 6: Version and Import Component

1. **Create Component Version:**
   ```bash
   # On your build server
   cd okta_api_process
   tar -czf okta-api-policy-manager-v1.0.0.tar.gz .
   ```

2. **Import to UrbanCode Deploy:**
   - Go to **Components** > `okta-api-policy-manager` > **Versions**
   - Click **Import Version**
   - Upload `okta-api-policy-manager-v1.0.0.tar.gz`
   - Version name: `1.0.0`

### Step 7: Test Deployment

1. **Deploy to Dev Environment:**
   - Go to **Applications** > Your App > **Dev**
   - Click **Request Process**
   - Select your updated application process
   - Click **Submit**

2. **Monitor Logs:**
   Look for output like:
   ```
   [INFO] ==================================================
   [INFO] Okta Access Policy Rule Deployment
   [INFO] ==================================================
   [INFO] Environment:     dev
   [INFO] Policy Name:     My Application Access Policy
   [INFO] Okta Domain:     dev-12345.okta.com
   [INFO] Rules Directory: config/dev/rules
   [INFO] ==================================================
   [INFO] Creating Python virtual environment...
   [INFO] Installing Python dependencies...
   [INFO] Applying access policy rules...
   [INFO] Found policy: My Application Access Policy (ID: 00p...)
   [INFO] Creating new rule: Allow with Keep Me Signed In
   [SUCCESS] Access policy rules applied successfully!
   ```

3. **Verify in Okta:**
   - Log into Okta Admin Console
   - Navigate to **Security** > **Authentication Policies**
   - Find your policy
   - Verify rules are created/updated

## Troubleshooting

### Issue: Python not found

**Error:** `python3: command not found`

**Solution:** Install Python 3.7+ on your UrbanCode Deploy agent:
```bash
# RHEL/CentOS
sudo yum install python3

# Ubuntu/Debian
sudo apt-get install python3
```

### Issue: Permission denied

**Error:** `Permission denied: ./scripts/urbancode_wrapper.sh`

**Solution:** Ensure scripts are executable before packaging:
```bash
chmod +x scripts/*.sh
```

Or add to your process step:
```bash
chmod +x scripts/*.sh
./scripts/urbancode_wrapper.sh
```

### Issue: Property not found

**Error:** `POLICY_NAME must be set by UrbanCode Deploy`

**Solution:**
1. Check property is defined at component/environment/application level
2. Verify property name matches exactly (case-sensitive)
3. Check property is not empty/null

### Issue: Rules directory not found

**Warning:** `Rules directory not found: config/dev/rules`

**Solution:**
1. Ensure `config/${ENVIRONMENT}/rules/` exists in component
2. Check `ENVIRONMENT` variable is set correctly
3. Verify JSON files exist in the directory

### Issue: API token expired

**Error:** `401 Unauthorized`

**Solution:**
1. Generate new API token in Okta
2. Update `OKTA_API_TOKEN` secure property in UrbanCode Deploy
3. Re-run deployment

## Advanced Configuration

### Running Only on Specific Environments

Add a precondition to the step:

```groovy
// Only run on production
if (environment.name != "Production") {
    println "Skipping Okta API updates for non-production environment"
    return 0
}
```

### Multiple Policies

If you need to update multiple policies:

1. **Option A:** Run step multiple times with different `POLICY_NAME`
2. **Option B:** Create separate component processes for each policy
3. **Option C:** Modify wrapper script to accept multiple policies

Example for Option C:
```bash
# In urbancode_wrapper.sh, loop through multiple policies
POLICIES=("Policy A" "Policy B" "Policy C")
for POLICY in "${POLICIES[@]}"; do
    ./scripts/apply_access_policies.sh \
        --env "$ENVIRONMENT" \
        --policy "$POLICY" \
        --rules-dir "$RULES_DIR"
done
```

### Conditional Deployment

Skip API updates if Terraform didn't change policies:

```bash
# Check if Terraform output indicates policy changes
if [ "$TF_POLICY_CHANGED" != "true" ]; then
    echo "No policy changes detected, skipping API updates"
    exit 0
fi

./scripts/urbancode_wrapper.sh
```

## Velocity Integration

Since Velocity executes your Terraform, you can also trigger this from Velocity:

1. **Velocity Pipeline:**
   ```yaml
   stages:
     - name: terraform-apply
       tasks:
         - name: Apply Infrastructure
           type: terraform

     - name: okta-policy-config
       tasks:
         - name: Apply Policy Rules
           type: urbancode-deploy
           component: okta-api-policy-manager
           process: Apply Okta Access Policies
   ```

2. **Pass Variables:**
   Velocity can pass environment variables to UrbanCode Deploy

## Rollback Strategy

If API updates fail or need rollback:

1. **Automatic Rollback:**
   - Set process step to fail on error (default)
   - UrbanCode Deploy will not mark deployment as successful
   - Previous rules remain unchanged

2. **Manual Rollback:**
   ```bash
   # Save previous rule state before changes
   python3 src/okta_api_client.py > previous_rules.json

   # Apply changes
   ./scripts/apply_access_policies.sh ...

   # If needed, restore from backup
   ./scripts/apply_access_policies.sh \
     --policy "My Policy" \
     --rule-file previous_rules.json
   ```

3. **Okta Rollback:**
   - Rules are updated, not replaced
   - Manual rollback via Okta Admin Console if needed
   - Check Okta System Log for change history

## Best Practices

1. **Version Control:**
   - Keep rule JSON files in Git alongside Terraform code
   - Use same branching strategy
   - Review rule changes in PRs

2. **Environment Parity:**
   - Test rules in dev before promoting
   - Use consistent rule names across environments
   - Document any environment-specific differences

3. **Monitoring:**
   - Check UrbanCode Deploy logs after each deployment
   - Monitor Okta System Log for API calls
   - Set up alerts for failed deployments

4. **Security:**
   - Use separate API tokens per environment
   - Rotate tokens quarterly
   - Audit token permissions regularly
   - Never log API tokens

## Support

For assistance:
1. Check UrbanCode Deploy process logs
2. Review `README.md` for detailed documentation
3. Consult Okta API documentation
4. Contact your DevOps team

## Next Steps

After successful integration:
1. ✅ Verify rules in Okta Admin Console
2. ✅ Test "Keep Me Signed In" functionality
3. ✅ Document any custom configurations
4. ✅ Train team on new process
5. ✅ Add to runbook/procedures
