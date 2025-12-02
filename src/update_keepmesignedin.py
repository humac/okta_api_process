#!/usr/bin/env python3
"""
Update Keep Me Signed In Feature for Okta Access Policy Rules

This script updates existing Okta Access Policy rules to enable the
"Keep Me Signed In" feature by modifying the keepMeSignedIn configuration.

It can:
- Update a single policy rule by ID
- Bulk update multiple policy rules from a CSV file
- Merge keepMeSignedIn settings with existing rule configuration
"""

import os
import sys
import json
import csv
import logging
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from okta_api_client import OktaAPIClient


class KeepMeSignedInUpdater:
    """Updates Okta Access Policy rules with Keep Me Signed In configuration"""

    def __init__(self, client: OktaAPIClient):
        """
        Initialize Keep Me Signed In Updater

        Args:
            client: Initialized OktaAPIClient instance
        """
        self.client = client
        self.logger = logging.getLogger(__name__)

    def merge_keep_me_signed_in(
        self,
        existing_rule: Dict,
        keep_me_signed_in_config: Dict
    ) -> Dict:
        """
        Merge keepMeSignedIn configuration into existing rule

        Args:
            existing_rule: Current rule configuration from Okta
            keep_me_signed_in_config: keepMeSignedIn configuration to merge

        Returns:
            Updated rule configuration
        """
        # Deep copy to avoid modifying original
        updated_rule = json.loads(json.dumps(existing_rule))

        # Ensure actions.appSignOn exists
        if 'actions' not in updated_rule:
            updated_rule['actions'] = {}
        if 'appSignOn' not in updated_rule['actions']:
            updated_rule['actions']['appSignOn'] = {}

        # Merge the keepMeSignedIn configuration
        if 'appSignOn' in keep_me_signed_in_config.get('actions', {}):
            app_sign_on_config = keep_me_signed_in_config['actions']['appSignOn']

            # Merge each key from the config
            for key, value in app_sign_on_config.items():
                updated_rule['actions']['appSignOn'][key] = value

        return updated_rule

    def update_rule_by_id(
        self,
        policy_id: str,
        rule_id: str,
        keep_me_signed_in_config: Dict,
        dry_run: bool = False
    ) -> Dict:
        """
        Update a specific policy rule with Keep Me Signed In configuration

        Args:
            policy_id: ID of the policy containing the rule
            rule_id: ID of the rule to update
            keep_me_signed_in_config: Configuration to merge
            dry_run: If True, only show what would be updated without making changes

        Returns:
            Updated rule object (or current rule if dry_run)
        """
        self.logger.info(f"Fetching rule {rule_id} from policy {policy_id}")

        # Get current rule configuration
        current_rule = self.client.get_policy_rule(policy_id, rule_id)
        rule_name = current_rule.get('name', 'Unknown')

        self.logger.info(f"Current rule: {rule_name}")

        # Merge the configuration
        updated_rule = self.merge_keep_me_signed_in(
            current_rule,
            keep_me_signed_in_config
        )

        # Check if keepMeSignedIn is in the updated configuration
        has_kmsi = 'keepMeSignedIn' in updated_rule.get('actions', {}).get('appSignOn', {})

        if has_kmsi:
            kmsi_config = updated_rule['actions']['appSignOn']['keepMeSignedIn']
            self.logger.info(f"Keep Me Signed In config: {json.dumps(kmsi_config)}")
        else:
            self.logger.warning("Keep Me Signed In configuration not found in merged result")

        if dry_run:
            self.logger.info("[DRY RUN] Would update rule with configuration:")
            self.logger.info(json.dumps(updated_rule, indent=2))
            return current_rule

        # Update the rule
        self.logger.info(f"Updating rule {rule_id}...")
        result = self.client.update_policy_rule(policy_id, rule_id, updated_rule)
        self.logger.info(f"Successfully updated rule: {rule_name}")

        return result

    def bulk_update_from_csv(
        self,
        csv_file: str,
        keep_me_signed_in_config: Dict,
        dry_run: bool = False
    ) -> List[Tuple[str, str, bool, Optional[str]]]:
        """
        Bulk update policy rules from a CSV file

        Args:
            csv_file: Path to CSV file with policy_id,rule_id,description
            keep_me_signed_in_config: Configuration to merge
            dry_run: If True, only show what would be updated

        Returns:
            List of tuples: (policy_id, rule_id, success, error_message)
        """
        csv_path = Path(csv_file)
        if not csv_path.exists():
            raise FileNotFoundError(f"CSV file not found: {csv_file}")

        results = []

        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)

            # Check if file has required columns
            if reader.fieldnames is None or 'policyId' not in reader.fieldnames:
                raise ValueError("CSV must have 'policyId' and 'ruleId' columns")

            for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is 1)
                # Skip empty rows or comment lines
                policy_id = row.get('policyId', '').strip()
                if not policy_id or policy_id.startswith('#'):
                    continue

                rule_id = row.get('ruleId', '').strip()
                description = row.get('description', '').strip()

                if not rule_id:
                    self.logger.warning(f"Row {row_num}: Missing ruleId, skipping")
                    continue

                self.logger.info(f"\nProcessing: {description or f'Policy {policy_id}, Rule {rule_id}'}")

                try:
                    self.update_rule_by_id(
                        policy_id,
                        rule_id,
                        keep_me_signed_in_config,
                        dry_run
                    )
                    results.append((policy_id, rule_id, True, None))
                    self.logger.info("✓ Success")

                except Exception as e:
                    error_msg = str(e)
                    self.logger.error(f"✗ Failed: {error_msg}")
                    results.append((policy_id, rule_id, False, error_msg))

        return results


def load_keep_me_signed_in_config(config_file: Optional[str] = None) -> Dict:
    """
    Load Keep Me Signed In configuration from file or use default

    Args:
        config_file: Optional path to JSON file with configuration

    Returns:
        Configuration dictionary
    """
    if config_file:
        config_path = Path(config_file)
        if not config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_file}")

        with open(config_path, 'r') as f:
            return json.load(f)

    # Default configuration
    return {
        "actions": {
            "appSignOn": {
                "keepMeSignedIn": {
                    "postAuth": "ALLOWED",
                    "postAuthPromptFrequency": "PT15M"
                }
            }
        }
    }


def setup_logging(log_level: str = 'INFO'):
    """Configure logging"""
    numeric_level = getattr(logging, log_level.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f'Invalid log level: {log_level}')

    logging.basicConfig(
        level=numeric_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description='Update Okta Access Policy rules with Keep Me Signed In configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Update a single rule
  %(prog)s --policy-id 00p1a2b3c4d5e6f7g8h9 --rule-id 0pr9i8h7g6f5e4d3c2b1

  # Bulk update from CSV file
  %(prog)s --csv-file config/policy_rule_ids.csv

  # Dry run (preview changes without updating)
  %(prog)s --csv-file config/policy_rule_ids.csv --dry-run

  # Use custom Keep Me Signed In configuration
  %(prog)s --policy-id 00p... --rule-id 0pr... --config examples/keep_me_signed_in_patch.json
        """
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        '--policy-id',
        help='Policy ID (for single rule update)'
    )
    mode_group.add_argument(
        '--csv-file',
        help='CSV file with policy_id,rule_id,description columns'
    )

    # Single rule update
    parser.add_argument(
        '--rule-id',
        help='Rule ID (required when using --policy-id)'
    )

    # Configuration
    parser.add_argument(
        '--config',
        help='JSON file with Keep Me Signed In configuration (optional, uses default if not specified)'
    )

    # Options
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without actually updating rules'
    )
    parser.add_argument(
        '--log-level',
        default=os.getenv('LOG_LEVEL', 'INFO'),
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Logging level (default: INFO)'
    )

    args = parser.parse_args()

    # Validate arguments
    if args.policy_id and not args.rule_id:
        parser.error('--rule-id is required when using --policy-id')

    # Setup logging
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)

    # Get Okta credentials from environment
    okta_domain = os.getenv('OKTA_DOMAIN')
    okta_token = os.getenv('OKTA_API_TOKEN')

    if not okta_domain or not okta_token:
        logger.error("OKTA_DOMAIN and OKTA_API_TOKEN environment variables must be set")
        sys.exit(1)

    try:
        # Load Keep Me Signed In configuration
        kmsi_config = load_keep_me_signed_in_config(args.config)

        if args.config:
            logger.info(f"Loaded configuration from: {args.config}")
        else:
            logger.info("Using default Keep Me Signed In configuration:")
            logger.info(json.dumps(kmsi_config, indent=2))

        # Initialize client and updater
        logger.info(f"Connecting to Okta domain: {okta_domain}")
        client = OktaAPIClient(okta_domain, okta_token)
        updater = KeepMeSignedInUpdater(client)

        if args.dry_run:
            logger.info("=" * 60)
            logger.info("DRY RUN MODE - No changes will be made")
            logger.info("=" * 60)

        # Execute update
        if args.policy_id:
            # Single rule update
            logger.info(f"Updating single rule...")
            logger.info(f"Policy ID: {args.policy_id}")
            logger.info(f"Rule ID:   {args.rule_id}")

            result = updater.update_rule_by_id(
                args.policy_id,
                args.rule_id,
                kmsi_config,
                args.dry_run
            )

            logger.info("\nUpdate completed successfully")
            if not args.dry_run:
                logger.info(f"Rule name: {result.get('name')}")

        else:
            # Bulk update from CSV
            logger.info(f"Bulk updating rules from: {args.csv_file}")
            results = updater.bulk_update_from_csv(
                args.csv_file,
                kmsi_config,
                args.dry_run
            )

            # Summary
            logger.info("\n" + "=" * 60)
            logger.info("BULK UPDATE SUMMARY")
            logger.info("=" * 60)

            success_count = sum(1 for _, _, success, _ in results if success)
            failed_count = len(results) - success_count

            logger.info(f"Total processed: {len(results)}")
            logger.info(f"Successful:      {success_count}")
            logger.info(f"Failed:          {failed_count}")

            if failed_count > 0:
                logger.info("\nFailed updates:")
                for policy_id, rule_id, success, error in results:
                    if not success:
                        logger.info(f"  - Policy {policy_id}, Rule {rule_id}: {error}")

        if args.dry_run:
            logger.info("\n" + "=" * 60)
            logger.info("DRY RUN COMPLETED - No changes were made")
            logger.info("Run without --dry-run to apply changes")
            logger.info("=" * 60)

        sys.exit(0)

    except Exception as e:
        logger.error(f"Operation failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
