#!/usr/bin/env python3
"""
Basic tests for the GoDaddyPy CLI
"""

import unittest
from unittest.mock import patch, MagicMock
import sys
import os
import json
from io import StringIO

# Add parent directory to path to import the package
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from godaddypy_cli.cli import setup_client, list_domains, get_records

class TestGoDaddyCLI(unittest.TestCase):
    """Test cases for GoDaddyPy CLI"""
    
    @patch('godaddypy_cli.cli.Account')
    @patch('godaddypy_cli.cli.Client')
    def test_setup_client(self, mock_client, mock_account):
        """Test client setup with API credentials"""
        # Setup mocks
        mock_account_instance = MagicMock()
        mock_account.return_value = mock_account_instance
        
        mock_client_instance = MagicMock()
        mock_client.return_value = mock_client_instance
        
        # Call the function
        api_key = "test_key"
        api_secret = "test_secret"
        client = setup_client(api_key, api_secret)
        
        # Assertions
        mock_account.assert_called_once_with(api_key=api_key, api_secret=api_secret)
        mock_client.assert_called_once_with(mock_account_instance)
        self.assertEqual(client, mock_client_instance)
    
    @patch('godaddypy_cli.cli.Client')
    @patch('sys.stdout', new_callable=StringIO)
    def test_list_domains(self, mock_stdout, mock_client):
        """Test listing domains"""
        # Setup mocks
        mock_client_instance = MagicMock()
        mock_client_instance.get_domains.return_value = ["example.com", "test.org"]
        
        args = MagicMock()
        args.json = True
        
        # Call the function
        list_domains(args, mock_client_instance)
        
        # Assertions
        mock_client_instance.get_domains.assert_called_once()
        # Check that JSON output contains our domains
        output = mock_stdout.getvalue()
        domains = json.loads(output)
        self.assertEqual(domains, ["example.com", "test.org"])
    
    @patch('godaddypy_cli.cli.Client')
    @patch('sys.stdout', new_callable=StringIO)
    def test_get_records(self, mock_stdout, mock_client):
        """Test getting DNS records"""
        # Setup mocks
        mock_client_instance = MagicMock()
        mock_records = [
            {"type": "A", "name": "www", "data": "192.168.1.1", "ttl": 3600}
        ]
        mock_client_instance.get_records.return_value = mock_records
        
        args = MagicMock()
        args.domain = "example.com"
        args.type = "A"
        args.name = "www"
        args.json = True
        
        # Call the function
        get_records(args, mock_client_instance)
        
        # Assertions
        mock_client_instance.get_records.assert_called_once_with("example.com", record_type="A", name="www")
        # Check that JSON output contains our records
        output = mock_stdout.getvalue()
        records = json.loads(output)
        self.assertEqual(records, mock_records)

if __name__ == '__main__':
    unittest.main()
