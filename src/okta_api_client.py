#!/usr/bin/env python3
"""
Okta API Client
Handles authentication and API requests to Okta Management API
"""

import os
import sys
import json
import logging
import requests
from typing import Dict, List, Optional, Any


class OktaAPIClient:
    """Client for interacting with Okta Management API"""

    def __init__(self, domain: str, api_token: str, verify_ssl: bool = True):
        """
        Initialize Okta API Client

        Args:
            domain: Okta domain (e.g., 'your-domain.okta.com')
            api_token: Okta API token with appropriate permissions
            verify_ssl: Whether to verify SSL certificates (default: True)
        """
        self.domain = domain.replace('https://', '').replace('http://', '')
        self.base_url = f"https://{self.domain}/api/v1"
        self.api_token = api_token
        self.verify_ssl = verify_ssl
        self.session = requests.Session()
        self.session.headers.update({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': f'SSWS {self.api_token}'
        })

        # Setup logging
        self.logger = logging.getLogger(__name__)

    def _make_request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Make HTTP request to Okta API

        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint (e.g., '/policies')
            data: Request body data
            params: Query parameters

        Returns:
            Response data as dictionary

        Raises:
            requests.exceptions.RequestException: If request fails
        """
        url = f"{self.base_url}{endpoint}"

        self.logger.debug(f"{method} {url}")
        if data:
            self.logger.debug(f"Request body: {json.dumps(data, indent=2)}")

        try:
            response = self.session.request(
                method=method,
                url=url,
                json=data,
                params=params,
                verify=self.verify_ssl
            )
            response.raise_for_status()

            # Handle empty responses (e.g., DELETE operations)
            if response.status_code == 204 or not response.content:
                return {'status': 'success', 'status_code': response.status_code}

            return response.json()

        except requests.exceptions.HTTPError as e:
            self.logger.error(f"HTTP Error: {e}")
            self.logger.error(f"Response: {e.response.text}")
            raise
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Request failed: {e}")
            raise

    def get(self, endpoint: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """Make GET request"""
        return self._make_request('GET', endpoint, params=params)

    def post(self, endpoint: str, data: Dict) -> Dict[str, Any]:
        """Make POST request"""
        return self._make_request('POST', endpoint, data=data)

    def put(self, endpoint: str, data: Dict) -> Dict[str, Any]:
        """Make PUT request"""
        return self._make_request('PUT', endpoint, data=data)

    def delete(self, endpoint: str) -> Dict[str, Any]:
        """Make DELETE request"""
        return self._make_request('DELETE', endpoint)

    # Policy-specific methods

    def get_policies(self, policy_type: Optional[str] = None) -> List[Dict]:
        """
        Get all policies or filter by type

        Args:
            policy_type: Filter by policy type (e.g., 'ACCESS_POLICY', 'OKTA_SIGN_ON')

        Returns:
            List of policy objects
        """
        params = {'type': policy_type} if policy_type else None
        return self.get('/policies', params=params)

    def get_policy(self, policy_id: str) -> Dict:
        """Get a specific policy by ID"""
        return self.get(f'/policies/{policy_id}')

    def create_policy(self, policy_data: Dict) -> Dict:
        """Create a new policy"""
        return self.post('/policies', policy_data)

    def update_policy(self, policy_id: str, policy_data: Dict) -> Dict:
        """Update an existing policy"""
        return self.put(f'/policies/{policy_id}', policy_data)

    def delete_policy(self, policy_id: str) -> Dict:
        """Delete a policy"""
        return self.delete(f'/policies/{policy_id}')

    # Policy Rules methods

    def get_policy_rules(self, policy_id: str) -> List[Dict]:
        """Get all rules for a specific policy"""
        return self.get(f'/policies/{policy_id}/rules')

    def get_policy_rule(self, policy_id: str, rule_id: str) -> Dict:
        """Get a specific policy rule"""
        return self.get(f'/policies/{policy_id}/rules/{rule_id}')

    def create_policy_rule(self, policy_id: str, rule_data: Dict) -> Dict:
        """
        Create a new policy rule

        Args:
            policy_id: ID of the policy to add the rule to
            rule_data: Rule configuration data

        Returns:
            Created rule object
        """
        return self.post(f'/policies/{policy_id}/rules', rule_data)

    def update_policy_rule(self, policy_id: str, rule_id: str, rule_data: Dict) -> Dict:
        """
        Update an existing policy rule

        Args:
            policy_id: ID of the policy
            rule_id: ID of the rule to update
            rule_data: Updated rule configuration data

        Returns:
            Updated rule object
        """
        return self.put(f'/policies/{policy_id}/rules/{rule_id}', rule_data)

    def delete_policy_rule(self, policy_id: str, rule_id: str) -> Dict:
        """Delete a policy rule"""
        return self.delete(f'/policies/{policy_id}/rules/{rule_id}')


def main():
    """Example usage"""
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    # Get configuration from environment variables
    okta_domain = os.getenv('OKTA_DOMAIN')
    okta_token = os.getenv('OKTA_API_TOKEN')

    if not okta_domain or not okta_token:
        print("Error: OKTA_DOMAIN and OKTA_API_TOKEN environment variables must be set")
        sys.exit(1)

    # Initialize client
    client = OktaAPIClient(okta_domain, okta_token)

    # Example: List all access policies
    try:
        policies = client.get_policies(policy_type='ACCESS_POLICY')
        print(f"Found {len(policies)} access policies")
        for policy in policies:
            print(f"  - {policy.get('name')} (ID: {policy.get('id')})")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
