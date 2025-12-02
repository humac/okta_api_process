#!/usr/bin/env python3
"""
Access Policy Manager
Manages Okta Access Policy rules with features not supported by Terraform
"""

import os
import sys
import json
import logging
import argparse
from pathlib import Path
from typing import Dict, List, Optional
from okta_api_client import OktaAPIClient


class AccessPolicyManager:
    """Manages Okta Access Policies and Rules"""

    def __init__(self, client: OktaAPIClient):
        """
        Initialize Access Policy Manager

        Args:
            client: Initialized OktaAPIClient instance
        """
        self.client = client
        self.logger = logging.getLogger(__name__)

    def find_policy_by_name(self, policy_name: str) -> Optional[Dict]:
        """
        Find an access policy by name

        Args:
            policy_name: Name of the policy to find

        Returns:
            Policy object if found, None otherwise
        """
        self.logger.info(f"Searching for policy: {policy_name}")
        policies = self.client.get_policies(policy_type='ACCESS_POLICY')

        for policy in policies:
            if policy.get('name') == policy_name:
                self.logger.info(f"Found policy: {policy_name} (ID: {policy.get('id')})")
                return policy

        self.logger.warning(f"Policy not found: {policy_name}")
        return None

    def find_rule_by_name(self, policy_id: str, rule_name: str) -> Optional[Dict]:
        """
        Find a rule within a policy by name

        Args:
            policy_id: ID of the policy
            rule_name: Name of the rule to find

        Returns:
            Rule object if found, None otherwise
        """
        self.logger.info(f"Searching for rule: {rule_name} in policy {policy_id}")
        rules = self.client.get_policy_rules(policy_id)

        for rule in rules:
            if rule.get('name') == rule_name:
                self.logger.info(f"Found rule: {rule_name} (ID: {rule.get('id')})")
                return rule

        self.logger.warning(f"Rule not found: {rule_name}")
        return None

    def apply_rule_from_file(
        self,
        policy_name: str,
        rule_file: str,
        update_if_exists: bool = True
    ) -> Dict:
        """
        Apply an access policy rule from a JSON file

        Args:
            policy_name: Name of the policy to add/update the rule
            rule_file: Path to JSON file containing rule configuration
            update_if_exists: If True, update existing rule; if False, create new

        Returns:
            Created or updated rule object
        """
        # Find the policy
        policy = self.find_policy_by_name(policy_name)
        if not policy:
            raise ValueError(f"Policy '{policy_name}' not found")

        policy_id = policy.get('id')

        # Load rule configuration from file
        rule_path = Path(rule_file)
        if not rule_path.exists():
            raise FileNotFoundError(f"Rule file not found: {rule_file}")

        with open(rule_path, 'r') as f:
            rule_data = json.load(f)

        rule_name = rule_data.get('name')
        if not rule_name:
            raise ValueError("Rule configuration must include 'name' field")

        # Check if rule already exists
        existing_rule = self.find_rule_by_name(policy_id, rule_name)

        if existing_rule:
            if update_if_exists:
                self.logger.info(f"Updating existing rule: {rule_name}")
                rule_id = existing_rule.get('id')
                result = self.client.update_policy_rule(policy_id, rule_id, rule_data)
                self.logger.info(f"Successfully updated rule: {rule_name}")
                return result
            else:
                self.logger.info(f"Rule already exists: {rule_name}, skipping")
                return existing_rule
        else:
            self.logger.info(f"Creating new rule: {rule_name}")
            result = self.client.create_policy_rule(policy_id, rule_data)
            self.logger.info(f"Successfully created rule: {rule_name}")
            return result

    def apply_rules_from_directory(
        self,
        policy_name: str,
        rules_dir: str,
        update_if_exists: bool = True
    ) -> List[Dict]:
        """
        Apply all access policy rules from JSON files in a directory

        Args:
            policy_name: Name of the policy to add/update rules
            rules_dir: Path to directory containing rule JSON files
            update_if_exists: If True, update existing rules; if False, skip

        Returns:
            List of created/updated rule objects
        """
        rules_path = Path(rules_dir)
        if not rules_path.exists() or not rules_path.is_dir():
            raise ValueError(f"Invalid rules directory: {rules_dir}")

        json_files = list(rules_path.glob('*.json'))
        if not json_files:
            self.logger.warning(f"No JSON files found in: {rules_dir}")
            return []

        results = []
        for json_file in sorted(json_files):
            self.logger.info(f"Processing rule file: {json_file.name}")
            try:
                result = self.apply_rule_from_file(
                    policy_name,
                    str(json_file),
                    update_if_exists
                )
                results.append(result)
            except Exception as e:
                self.logger.error(f"Failed to apply rule from {json_file.name}: {e}")
                raise

        return results


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
        description='Manage Okta Access Policy rules via API'
    )
    parser.add_argument(
        '--policy-name',
        required=True,
        help='Name of the access policy'
    )
    parser.add_argument(
        '--rule-file',
        help='Path to JSON file containing rule configuration'
    )
    parser.add_argument(
        '--rules-dir',
        help='Path to directory containing multiple rule JSON files'
    )
    parser.add_argument(
        '--create-only',
        action='store_true',
        help='Only create new rules, do not update existing ones'
    )
    parser.add_argument(
        '--log-level',
        default=os.getenv('LOG_LEVEL', 'INFO'),
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Logging level (default: INFO)'
    )

    args = parser.parse_args()

    # Validate arguments
    if not args.rule_file and not args.rules_dir:
        parser.error('Either --rule-file or --rules-dir must be specified')

    if args.rule_file and args.rules_dir:
        parser.error('Cannot specify both --rule-file and --rules-dir')

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
        # Initialize client and manager
        logger.info(f"Connecting to Okta domain: {okta_domain}")
        client = OktaAPIClient(okta_domain, okta_token)
        manager = AccessPolicyManager(client)

        update_if_exists = not args.create_only

        # Apply rules
        if args.rule_file:
            logger.info(f"Applying rule from file: {args.rule_file}")
            result = manager.apply_rule_from_file(
                args.policy_name,
                args.rule_file,
                update_if_exists
            )
            logger.info(f"Rule applied successfully: {result.get('name')}")
            print(json.dumps(result, indent=2))

        elif args.rules_dir:
            logger.info(f"Applying rules from directory: {args.rules_dir}")
            results = manager.apply_rules_from_directory(
                args.policy_name,
                args.rules_dir,
                update_if_exists
            )
            logger.info(f"Successfully applied {len(results)} rules")
            for result in results:
                print(f"  ✓ {result.get('name')}")

        logger.info("Operation completed successfully")
        sys.exit(0)

    except Exception as e:
        logger.error(f"Operation failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
