#!/bin/bash
#
# GoDaddyPy CLI Setup Script
# This comprehensive script sets up the GoDaddyPy CLI project, including:
# - Project structure
# - Dependencies
# - Git repository
# - GitHub Actions for CI/CD
# - PyPI publishing configuration
# - Local development environment
#
# Usage: ./setup.sh [options]
# Options:
#   --install-only    Skip Git setup, just install the CLI
#   --api-key KEY     GoDaddy API key
#   --api-secret SEC  GoDaddy API secret
#   --dev             Set up a development environment
#   --server          Set up as a server API service
#   --help            Show this help message

set -e  # Exit immediately if a command exits with a non-zero status

# ============================
# Configuration Variables
# ============================
PROJECT_NAME="godaddypy-cli"
GITHUB_USERNAME="connorodea"  # Change this to your GitHub username
AUTHOR_NAME="Connor O'Dea"  # Change this to your name
AUTHOR_EMAIL="cpodea5@gmail.com"  # Change this to your email
VERSION="0.1.0"

# Installation paths
INSTALL_DIR="/opt/$PROJECT_NAME"
CONFIG_DIR="/etc/$PROJECT_NAME"
VENV_DIR="${INSTALL_DIR}/venv"
SYSTEMWIDE_BIN="/usr/local/bin/godaddy"

# Default mode
INSTALL_ONLY=false
DEVELOPMENT_MODE=false
SERVER_MODE=false
GODADDY_API_KEY=""
GODADDY_API_SECRET=""

# ============================
# Utility Functions
# ============================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${MAGENTA}=== $1 ===${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to confirm action
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Function to create directory safely
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_message "Created directory: $1"
    else
        print_message "Directory already exists: $1"
    fi
}

# ============================
# Parse Command Line Arguments
# ============================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --install-only)
                INSTALL_ONLY=true
                shift
                ;;
            --api-key)
                GODADDY_API_KEY="$2"
                shift
                shift
                ;;
            --api-secret)
                GODADDY_API_SECRET="$2"
                shift
                shift
                ;;
            --dev)
                DEVELOPMENT_MODE=true
                shift
                ;;
            --server)
                SERVER_MODE=true
                shift
                ;;
            --help)
                echo "GoDaddyPy CLI Setup Script"
                echo "Usage: ./setup.sh [options]"
                echo "Options:"
                echo "  --install-only    Skip Git setup, just install the CLI"
                echo "  --api-key KEY     GoDaddy API key"
                echo "  --api-secret SEC  GoDaddy API secret"
                echo "  --dev             Set up a development environment"
                echo "  --server          Set up as a server API service"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $key"
                exit 1
                ;;
        esac
    done
}

# ============================
# Check Requirements
# ============================
check_requirements() {
    print_step "Checking Requirements"

    # Check Python version
    if command_exists python3; then
        python_version=$(python3 --version | cut -d " " -f 2)
        print_message "Found Python $python_version"
        
        # Check if Python version is at least 3.7
        if [[ $(echo "$python_version" | cut -d. -f1) -lt 3 || ($(echo "$python_version" | cut -d. -f1) -eq 3 && $(echo "$python_version" | cut -d. -f2) -lt 7) ]]; then
            print_error "Python 3.7+ is required. Found $python_version"
            exit 1
        fi
    else
        print_error "Python 3.7+ is required but not found"
        exit 1
    fi

    # Check pip
    if command_exists pip3; then
        print_message "Found pip3: $(pip3 --version)"
    else
        print_error "pip3 is required but not found"
        exit 1
    fi

    # Check git (if not in install-only mode)
    if [ "$INSTALL_ONLY" = false ]; then
        if command_exists git; then
            print_message "Found git: $(git --version)"
        else
            print_error "git is required but not found"
            exit 1
        fi
    fi
}

# ============================
# Install System Dependencies
# ============================
install_system_dependencies() {
    print_step "Installing System Dependencies"

    # Check if we have sudo access
    if command_exists sudo; then
        SUDO="sudo"
    else
        # Check if we're already root
        if [ "$(id -u)" -eq 0 ]; then
            SUDO=""
        else
            print_error "Neither sudo nor root access available"
            exit 1
        fi
    fi
    
    print_message "Updating package index..."
    if command_exists apt-get; then
        # Debian/Ubuntu
        $SUDO apt-get update -qq
        $SUDO apt-get install -y python3 python3-pip python3-venv git build-essential
    elif command_exists dnf; then
        # Fedora/RHEL/CentOS
        $SUDO dnf -y update
        $SUDO dnf -y install python3 python3-pip python3-devel git
    elif command_exists yum; then
        # Older RHEL/CentOS
        $SUDO yum -y update
        $SUDO yum -y install python3 python3-pip python3-devel git
    elif command_exists pacman; then
        # Arch Linux
        $SUDO pacman -Sy --noconfirm python python-pip git base-devel
    elif command_exists brew; then
        # macOS with Homebrew
        brew update
        brew install python git
    else
        print_warning "Unsupported package manager. Please manually install Python 3.7+, pip, and git."
    fi

    print_success "System dependencies installed successfully"
}

# ============================
# Set Up Project Structure
# ============================
setup_project_structure() {
    print_step "Setting Up Project Structure"
    
    if [ "$DEVELOPMENT_MODE" = true ]; then
        # Development mode - create project in current directory
        BASE_DIR="$PWD/$PROJECT_NAME"
        create_dir "$BASE_DIR"
        cd "$BASE_DIR"
    else
        # System installation mode
        if [ "$(id -u)" -ne 0 ] && [ "$SUDO" = "sudo" ]; then
            print_error "System installation requires root privileges. Please run with sudo."
            exit 1
        fi
        
        BASE_DIR="$INSTALL_DIR"
        create_dir "$BASE_DIR"
        create_dir "$CONFIG_DIR"
        cd "$BASE_DIR"
    fi
    
    # Create Python package directory structure
    create_dir "godaddypy_cli"
    create_dir "tests"
    create_dir ".github/workflows"
    
    print_success "Project structure created successfully"
}

# ============================
# Create Python Environment
# ============================
create_python_environment() {
    print_step "Creating Python Environment"
    
    if [ "$DEVELOPMENT_MODE" = true ]; then
        # Create virtual environment in project directory
        VENV_DIR="$BASE_DIR/venv"
        print_message "Creating virtual environment in $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    else
        # Create virtual environment in system directory
        print_message "Creating virtual environment in $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    print_message "Upgrading pip..."
    pip install --upgrade pip
    
    # Install basic development tools
    print_message "Installing development tools..."
    pip install wheel build twine pytest flake8
    
    print_success "Python environment created successfully"
}

# ============================
# Create Project Files
# ============================
create_project_files() {
    print_step "Creating Project Files"
    
    # Create __init__.py
    cat > "godaddypy_cli/__init__.py" << 'EOF'
"""
GoDaddyPy CLI - A beautiful and interactive command line interface for the GoDaddy API
"""

__version__ = '0.1.0'
EOF

    # Create __main__.py
    cat > "godaddypy_cli/__main__.py" << 'EOF'
"""
Entry point for the GoDaddyPy CLI when run as a module
"""

from .cli import main

if __name__ == '__main__':
    main()
EOF

    # Create cli.py
    cat > "godaddypy_cli/cli.py" << 'EOF'
#!/usr/bin/env python3
"""
GoDaddyPy CLI - A beautiful and interactive command line interface for the GoDaddy API
"""

import os
import sys
import json
import argparse
import time
from godaddypy import Client, Account

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.prompt import Prompt, Confirm
    from rich import print as rprint
    from rich.traceback import install as install_rich_traceback
    RICH_AVAILABLE = True
    install_rich_traceback()
except ImportError:
    RICH_AVAILABLE = False
    print("For a better experience, install the 'rich' package: pip install rich")

# Create a console for rich output
console = Console() if RICH_AVAILABLE else None

def setup_client(api_key, api_secret):
    """Create and return a GoDaddy API client"""
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold blue]Connecting to GoDaddy API..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        account = Account(api_key=api_key, api_secret=api_secret)
        client = Client(account)
        time.sleep(0.5)  # Small delay for visual feedback
    return client

class DummyProgress:
    """Dummy context manager for when rich is not available"""
    def __enter__(self):
        print("Connecting to GoDaddy API...")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        pass

def list_domains(args, client):
    """List all domains in the account"""
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold blue]Fetching domains..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        domains = client.get_domains()
    
    if args.json:
        print(json.dumps(domains, indent=2))
        return
    
    if RICH_AVAILABLE:
        if not domains:
            console.print(Panel("[yellow]No domains found in your account", title="Domains"))
            return
            
        table = Table(title="Your GoDaddy Domains")
        table.add_column("Domain Name", style="cyan")
        
        for domain in domains:
            table.add_row(domain)
        
        console.print(table)
    else:
        if not domains:
            print("No domains found in your account")
            return
            
        print("\nYour GoDaddy Domains:")
        print("---------------------")
        for domain in domains:
            print(domain)

def get_records(args, client):
    """Get DNS records for a domain"""
    with Progress(
        SpinnerColumn(),
        TextColumn(f"[bold blue]Fetching records for {args.domain}..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        records = client.get_records(args.domain, record_type=args.type, name=args.name)
    
    if args.json:
        print(json.dumps(records, indent=2))
        return
    
    if RICH_AVAILABLE:
        if not records:
            console.print(Panel(f"[yellow]No records found for {args.domain}", title="DNS Records"))
            return
            
        table = Table(title=f"DNS Records for {args.domain}")
        table.add_column("Type", style="green")
        table.add_column("Name", style="cyan")
        table.add_column("Data", style="magenta")
        table.add_column("TTL", style="blue")
        
        for record in records:
            table.add_row(
                record.get('type', 'N/A'),
                record.get('name', 'N/A'),
                record.get('data', 'N/A'),
                str(record.get('ttl', 'N/A')),
            )
        
        console.print(table)
    else:
        if not records:
            print(f"No records found for {args.domain}")
            return
            
        print(f"\nDNS Records for {args.domain}:")
        print("-" * (20 + len(args.domain)))
        for record in records:
            print(f"Type: {record.get('type', 'N/A')}, " +
                  f"Name: {record.get('name', 'N/A')}, " +
                  f"Data: {record.get('data', 'N/A')}, " +
                  f"TTL: {record.get('ttl', 'N/A')}")

def update_record(args, client):
    """Update a DNS record"""
    if not all([args.domain, args.name, args.type, args.data]):
        error_msg = "Error: domain, name, type, and data are required"
        if RICH_AVAILABLE:
            console.print(f"[bold red]{error_msg}[/bold red]")
        else:
            print(error_msg)
        return
    
    # Confirm update if not forced
    if not args.force and RICH_AVAILABLE:
        if not Confirm.ask(f"Update [cyan]{args.type}[/cyan] record [green]{args.name}[/green] for [yellow]{args.domain}[/yellow] with data [magenta]{args.data}[/magenta]?"):
            console.print("[yellow]Operation cancelled[/yellow]")
            return
    
    with Progress(
        SpinnerColumn(),
        TextColumn(f"[bold blue]Updating {args.type} record {args.name} for {args.domain}..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        try:
            success = client.update_record_ip(args.data, args.domain, args.name, args.type)
            time.sleep(0.5)  # Small delay for visual feedback
        except Exception as e:
            if RICH_AVAILABLE:
                console.print(f"[bold red]Error:[/bold red] {str(e)}")
            else:
                print(f"Error updating record: {e}")
            return
    
    if RICH_AVAILABLE:
        if success:
            console.print(Panel(f"[bold green]Successfully updated {args.type} record {args.name} for {args.domain}[/bold green]", title="Success"))
        else:
            console.print(Panel(f"[bold red]Failed to update record[/bold red]", title="Error"))
    else:
        print(f"Record update {'successful' if success else 'failed'}")

def add_record(args, client):
    """Add a new DNS record"""
    if not all([args.domain, args.name, args.type, args.data]):
        error_msg = "Error: domain, name, type, and data are required"
        if RICH_AVAILABLE:
            console.print(f"[bold red]{error_msg}[/bold red]")
        else:
            print(error_msg)
        return
    
    # Confirm addition if not forced
    if not args.force and RICH_AVAILABLE:
        if not Confirm.ask(f"Add [cyan]{args.type}[/cyan] record [green]{args.name}[/green] to [yellow]{args.domain}[/yellow] with data [magenta]{args.data}[/magenta]?"):
            console.print("[yellow]Operation cancelled[/yellow]")
            return
    
    record = {
        'name': args.name,
        'type': args.type,
        'data': args.data,
        'ttl': args.ttl
    }
    
    with Progress(
        SpinnerColumn(),
        TextColumn(f"[bold blue]Adding {args.type} record {args.name} to {args.domain}..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        try:
            success = client.add_record(args.domain, record)
            time.sleep(0.5)  # Small delay for visual feedback
        except Exception as e:
            if RICH_AVAILABLE:
                console.print(f"[bold red]Error:[/bold red] {str(e)}")
            else:
                print(f"Error adding record: {e}")
            return
    
    if RICH_AVAILABLE:
        if success:
            console.print(Panel(f"[bold green]Successfully added {args.type} record {args.name} to {args.domain}[/bold green]", title="Success"))
        else:
            console.print(Panel(f"[bold red]Failed to add record[/bold red]", title="Error"))
    else:
        print(f"Record creation {'successful' if success else 'failed'}")

def delete_records(args, client):
    """Delete DNS records"""
    if not args.domain:
        error_msg = "Error: domain is required"
        if RICH_AVAILABLE:
            console.print(f"[bold red]{error_msg}[/bold red]")
        else:
            print(error_msg)
        return
    
    # Show what will be deleted
    with Progress(
        SpinnerColumn(),
        TextColumn(f"[bold blue]Fetching records for {args.domain}..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        records = client.get_records(args.domain, record_type=args.type, name=args.name)
        time.sleep(0.5)  # Small delay for visual feedback
    
    if not records:
        msg = f"No matching records found for {args.domain}"
        if RICH_AVAILABLE:
            console.print(f"[yellow]{msg}[/yellow]")
        else:
            print(msg)
        return
    
    # Confirm deletion if not forced
    if not args.force and RICH_AVAILABLE:
        console.print("[bold yellow]The following records will be deleted:[/bold yellow]")
        table = Table()
        table.add_column("Type", style="green")
        table.add_column("Name", style="cyan")
        table.add_column("Data", style="magenta")
        
        for record in records:
            table.add_row(
                record.get('type', 'N/A'),
                record.get('name', 'N/A'),
                record.get('data', 'N/A'),
            )
        
        console.print(table)
        
        if not Confirm.ask(f"Delete {len(records)} record(s) from [yellow]{args.domain}[/yellow]?"):
            console.print("[yellow]Operation cancelled[/yellow]")
            return
    elif not args.force:
        print("The following records will be deleted:")
        for record in records:
            print(f"Type: {record.get('type', 'N/A')}, " +
                  f"Name: {record.get('name', 'N/A')}, " +
                  f"Data: {record.get('data', 'N/A')}")
        
        confirm = input(f"Delete {len(records)} record(s) from {args.domain}? (y/n): ")
        if confirm.lower() != 'y':
            print("Operation cancelled")
            return
    
    with Progress(
        SpinnerColumn(),
        TextColumn(f"[bold blue]Deleting records from {args.domain}..."),
        transient=True,
    ) if RICH_AVAILABLE else DummyProgress() as progress:
        try:
            success = client.delete_records(args.domain, name=args.name, record_type=args.type)
            time.sleep(0.5)  # Small delay for visual feedback
        except Exception as e:
            if RICH_AVAILABLE:
                console.print(f"[bold red]Error:[/bold red] {str(e)}")
            else:
                print(f"Error deleting records: {e}")
            return
    
    if RICH_AVAILABLE:
        if success:
            console.print(Panel(f"[bold green]Successfully deleted records from {args.domain}[/bold green]", title="Success"))
        else:
            console.print(Panel(f"[bold red]Failed to delete records[/bold red]", title="Error"))
    else:
        print(f"Record deletion {'successful' if success else 'failed'}")

def interactive_menu():
    """Show interactive menu for navigation"""
    if not RICH_AVAILABLE:
        print("Interactive mode requires the 'rich' package. Please install it with: pip install rich")
        return
    
    api_key = os.environ.get('GODADDY_TOKEN') or os.environ.get('GODADDY_API_KEY')
    api_secret = os.environ.get('GODADDY_SECRET') or os.environ.get('GODADDY_API_SECRET')
    
    if not api_key or not api_secret:
        api_key = Prompt.ask("Enter your GoDaddy API Key", password=True)
        api_secret = Prompt.ask("Enter your GoDaddy API Secret", password=True)
    
    client = setup_client(api_key, api_secret)
    
    while True:
        console.clear()
        console.print(Panel.fit("[bold cyan]GoDaddy CLI[/bold cyan]", border_style="blue"))
        console.print("\n[bold]Please select an option:[/bold]\n")
        console.print("[1] [cyan]List domains[/cyan]")
        console.print("[2] [cyan]View DNS records[/cyan]")
        console.print("[3] [cyan]Add DNS record[/cyan]")
        console.print("[4] [cyan]Update DNS record[/cyan]")
        console.print("[5] [cyan]Delete DNS records[/cyan]")
        console.print("[0] [red]Exit[/red]")
        
        choice = Prompt.ask("\nEnter your choice", choices=["0", "1", "2", "3", "4", "5"], default="0")
        
        if choice == "0":
            console.print("[yellow]Goodbye![/yellow]")
            break
        elif choice == "1":
            list_domains(argparse.Namespace(json=False), client)
            input("\nPress Enter to continue...")
        elif choice == "2":
            domain = Prompt.ask("Enter domain name")
            record_type = Prompt.ask("Enter record type (leave empty for all)", default="")
            name = Prompt.ask("Enter record name (leave empty for all)", default="")
            
            args = argparse.Namespace(
                domain=domain,
                type=record_type if record_type else None,
                name=name if name else None,
                json=False
            )
            get_records(args, client)
            input("\nPress Enter to continue...")
        elif choice == "3":
            domain = Prompt.ask("Enter domain name")
            record_type = Prompt.ask("Enter record type")
            name = Prompt.ask("Enter record name")
            data = Prompt.ask("Enter record data")
            ttl = int(Prompt.ask("Enter TTL", default="3600"))
            
            args = argparse.Namespace(
                domain=domain,
                type=record_type,
                name=name,
                data=data,
                ttl=ttl,
                force=True,
                json=False
            )
            add_record(args, client)
            input("\nPress Enter to continue...")
        elif choice == "4":
            domain = Prompt.ask("Enter domain name")
            record_type = Prompt.ask("Enter record type")
            name = Prompt.ask("Enter record name")
            data = Prompt.ask("Enter new record data")
            
            args = argparse.Namespace(
                domain=domain,
                type=record_type,
                name=name,
                data=data,
                force=True,
                json=False
            )
            update_record(args, client)
            input("\nPress Enter to continue...")
        elif choice == "5":
            domain = Prompt.ask("Enter domain name")
            record_type = Prompt.ask("Enter record type (leave empty for all)", default="")
            name = Prompt.ask("Enter record name (leave empty for all)", default="")
            
            args = argparse.Namespace(
                domain=domain,
                type=record_type if record_type else None,
                name=name if name else None,
                force=False,
                json=False
            )
            delete_records(args, client)
            input("\nPress Enter to continue...")

def main():
    # Top level parser
    parser = argparse.ArgumentParser(description='GoDaddy API CLI - Manage your domains and DNS records')
    parser.add_argument('--key', help='GoDaddy API Key')
    parser.add_argument('--secret', help='GoDaddy API Secret')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--interactive', '-i', action='store_true', help='Start interactive mode')
    
    # Use environment variables as defaults if not specified
    default_key = os.environ.get('GODADDY_TOKEN') or os.environ.get('GODADDY_API_KEY')
    default_secret = os.environ.get('GODADDY_SECRET') or os.environ.get('GODADDY_API_SECRET')
    
    # Subcommands
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # domains command
    domains_parser = subparsers.add_parser('domains', help='List all domains')
    
    # records command
    records_parser = subparsers.add_parser('records', help='Get domain records')
    records_parser.add_argument('domain', help='Domain name')
    records_parser.add_argument('--type', help='Record type (A, AAAA, CNAME, etc.)')
    records_parser.add_argument('--name', help='Record name (e.g., www, @, etc.)')
    
    # update command
    update_parser = subparsers.add_parser('update', help='Update a DNS record')
    update_parser.add_argument('domain', help='Domain name')
    update_parser.add_argument('--name', required=True, help='Record name (e.g., www, @, etc.)')
    update_parser.add_argument('--type', required=True, help='Record type (A, AAAA, CNAME, etc.)')
    update_parser.add_argument('--data', required=True, help='Record data (e.g., IP address)')
    update_parser.add_argument('--force', '-f', action='store_true', help='Skip confirmation')
    
    # add command
    add_parser = subparsers.add_parser('add', help='Add a DNS record')
    add_parser.add_argument('domain', help='Domain name')
    add_parser.add_argument('--name', required=True, help='Record name (e.g., www, @, etc.)')
    add_parser.add_argument('--type', required=True, help='Record type (A, AAAA, CNAME, etc.)')
    add_parser.add_argument('--data', required=True, help='Record data (e.g., IP address)')
    add_parser.add_argument('--ttl', type=int, default=3600, help='Time to live (seconds)')
    add_parser.add_argument('--force', '-f', action='store_true', help='Skip confirmation')
    
    # delete command
    delete_parser = subparsers.add_parser('delete', help='Delete DNS records')
    delete_parser.add_argument('domain', help='Domain name')
    delete_parser.add_argument('--name', help='Record name (e.g., www, @, etc.)')
    delete_parser.add_argument('--type', help='Record type (A, AAAA, CNAME, etc.)')
    delete_parser.add_argument('--force', '-f', action='store_true', help='Skip confirmation')
    
    args = parser.parse_args()
    
    # Handle interactive mode
    if args.interactive:
        interactive_menu()
        return
    
    # If no command is specified, show help
    if not args.command:
        parser.print_help()
        return
    
    # Determine API key and secret
    api_key = args.key or default_key
    api_secret = args.secret or default_secret
    
    if not api_key or not api_secret:
        error_msg = "Error: API key and secret are required. Provide them as arguments or set environment variables."
        if RICH_AVAILABLE:
            console.print(f"[bold red]{error_msg}[/bold red]")
        else:
            print(error_msg)
        return
    
    # Create the client
    client = setup_client(api_key, api_secret)
    
    # Execute the appropriate command
    commands = {
        'domains': list_domains,
        'records': get_records,
        'update': update_record,
        'add': add_record,
        'delete': delete_records
    }
    
    if args.command in commands:
        commands[args.command](args, client)

if __name__ == '__main__':
    main()
EOF

    # Create test_cli.py
    cat > "tests/test_cli.py" << 'EOF'
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
EOF

    # Create tests/__init__.py
    cat > "tests/__init__.py" << 'EOF'
# Tests package
EOF

    # Create GitHub workflow file
    cat > ".github/workflows/ci-cd.yml" << 'EOF'
name: CI/CD

on:
  push:
    branches: [ main, master ]
    tags:
      - 'v*'
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.7', '3.8', '3.9', '3.10']

    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
        
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install flake8 pytest
        pip install -e .
        
    - name: Lint with flake8
      run: |
        # stop the build if there are Python syntax errors or undefined names
        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
        # exit-zero treats all errors as warnings
        flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
        
    - name: Test with pytest
      run: |
        pytest

  build-and-publish:
    needs: test
    runs-on: ubuntu-latest
    # Only publish on tag pushes
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags')
    
    environment:
      name: pypi
      url: https://pypi.org/p/godaddypy-cli
      
    permissions:
      id-token: write  # Required for trusted publishing
      
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
        
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install build twine
        
    - name: Extract version from tag
      id: get_version
      run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV
      
    - name: Build package
      run: |
        python -m build
        
    - name: Check package
      run: |
        twine check dist/*
        
    - name: Publish package to PyPI
      uses: pypa/gh-action-pypi-publish@release/v1
      # No need to provide credentials when using trusted publishing
EOF

    # Create pyproject.toml
    cat > "pyproject.toml" << EOF
[build-system]
requires = ["setuptools>=42", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "godaddypy-cli"
version = "$VERSION"
description = "Beautiful Command Line Interface for GoDaddy API using GoDaddyPy"
readme = "README.md"
authors = [
    {name = "$AUTHOR_NAME", email = "$AUTHOR_EMAIL"}
]
license = {text = "MIT"}
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.7",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
]
keywords = ["godaddy", "dns", "api", "cli", "domains"]
dependencies = [
    "godaddypy>=2.5.1",
    "rich>=12.0.0",
]
requires-python = ">=3.7"

[project.urls]
Homepage = "https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
"Bug Tracker" = "https://github.com/$GITHUB_USERNAME/$PROJECT_NAME/issues"

[project.scripts]
godaddy = "godaddypy_cli.cli:main"

[tool.setuptools]
packages = ["godaddypy_cli"]

[tool.pytest.ini_options]
testpaths = ["tests"]
EOF

    # Create setup.py (for backward compatibility)
    cat > "setup.py" << EOF
#!/usr/bin/env python3
from setuptools import setup

# This file is maintained for backward compatibility.
# Most configuration is in pyproject.toml

setup()
EOF

    # Create README.md
    cat > "README.md" << EOF
# GoDaddyPy CLI

[![PyPI version](https://badge.fury.io/py/godaddypy-cli.svg)](https://badge.fury.io/py/godaddypy-cli)
[![CI/CD](https://github.com/$GITHUB_USERNAME/$PROJECT_NAME/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/$GITHUB_USERNAME/$PROJECT_NAME/actions/workflows/ci-cd.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A beautiful and interactive command-line interface for managing GoDaddy domains and DNS records.

## Features

✨ **Interactive Mode** - Navigate through menus to manage domains without remembering commands  
🎨 **Beautiful Output** - Colorful, well-formatted tables and progress indicators  
🔍 **Easy to Use** - Simple commands with smart confirmation prompts  
🛠 **Powerful** - Complete control over your GoDaddy domains and DNS records

## Installation

\`\`\`bash
# Install from PyPI
pip install godaddypy-cli
\`\`\`

## Configuration

There are three ways to provide your GoDaddy API credentials:

1. **Environment variables** (recommended):
   \`\`\`bash
   export GODADDY_TOKEN=YOUR_API_KEY
   export GODADDY_SECRET=YOUR_API_SECRET
   \`\`\`

2. **Command-line arguments**:
   \`\`\`bash
   godaddy --key YOUR_API_KEY --secret YOUR_API_SECRET domains
   \`\`\`

3. **Interactive prompt**:
   If credentials aren't provided, the CLI will securely prompt for them in interactive mode.

## Usage

### Interactive Mode (Recommended)

Simply run:

\`\`\`bash
godaddy -i
\`\`\`

This launches an interactive menu where you can:
- Browse and manage domains
- View, add, update, and delete DNS records
- Get guided through all operations with clear prompts

### Command Line Mode

#### List all domains

\`\`\`bash
godaddy domains
\`\`\`

#### Get all DNS records for a domain

\`\`\`bash
godaddy records example.com
\`\`\`

#### Get specific DNS records

\`\`\`bash
godaddy records example.com --type A --name www
\`\`\`

#### Add a DNS record

\`\`\`bash
godaddy add example.com --name www --type A --data 192.168.1.1 --ttl 3600
\`\`\`

#### Update a DNS record

\`\`\`bash
godaddy update example.com --name www --type A --data 192.168.1.2
\`\`\`

#### Delete DNS records

\`\`\`bash
godaddy delete example.com --name www --type A
\`\`\`

### JSON Output

Add the \`--json\` flag to any command to get JSON output:

\`\`\`bash
godaddy records example.com --json
\`\`\`

## Requirements

- Python 3.7+
- GoDaddy API credentials (get them from [GoDaddy Developer Portal](https://developer.godaddy.com/keys/))

## Development

\`\`\`bash
# Clone the repository
git clone https://github.com/$GITHUB_USERNAME/$PROJECT_NAME.git
cd $PROJECT_NAME

# Install in development mode
pip install -e .

# Run tests
pytest
\`\`\`

## License

MIT
EOF

    # Create .gitignore
    cat > ".gitignore" << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python installer script
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# celery beat schedule file
celerybeat-schedule

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# GoDaddy API credentials
credentials.yml
EOF

    # Create LICENSE
    cat > "LICENSE" << EOF
MIT License

Copyright (c) $(date +%Y) $AUTHOR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    # Create API Wrapper (if server mode is enabled)
    if [ "$SERVER_MODE" = true ]; then
        print_message "Creating API wrapper..."
        cat > "godaddypy_cli/api.py" << 'EOF'
#!/usr/bin/env python3
"""
GoDaddyPy API Wrapper - A RESTful API service for the GoDaddy API
This script provides a Flask-based REST API that wraps the GoDaddyPy functionality,
making it accessible over HTTP.
"""

import os
import json
from flask import Flask, request, jsonify
from godaddypy import Client, Account
from functools import wraps
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/var/log/godaddypy-api.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("godaddypy-api")

# Initialize Flask app
app = Flask(__name__)

# Get GoDaddy API credentials from environment variables
API_KEY = os.environ.get('GODADDY_TOKEN') or os.environ.get('GODADDY_API_KEY')
API_SECRET = os.environ.get('GODADDY_SECRET') or os.environ.get('GODADDY_API_SECRET')

# Create GoDaddy client
account = Account(api_key=API_KEY, api_secret=API_SECRET)
client = Client(account)

# Optional: API authentication token
API_TOKEN = os.environ.get('API_AUTH_TOKEN')

# Authentication decorator
def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        # Skip auth check if no token is configured
        if not API_TOKEN:
            return f(*args, **kwargs)
            
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Unauthorized - Missing or invalid Authorization header'}), 401
            
        token = auth_header.split(' ')[1]
        if token != API_TOKEN:
            return jsonify({'error': 'Unauthorized - Invalid token'}), 401
            
        return f(*args, **kwargs)
    return decorated

# API health check endpoint
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'service': 'godaddypy-api'})

# List domains
@app.route('/api/domains', methods=['GET'])
@require_auth
def list_domains():
    try:
        domains = client.get_domains()
        return jsonify({'domains': domains})
    except Exception as e:
        logger.error(f"Error listing domains: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Get records
@app.route('/api/domains/<domain>/records', methods=['GET'])
@require_auth
def get_records(domain):
    try:
        record_type = request.args.get('type')
        name = request.args.get('name')
        
        records = client.get_records(domain, record_type=record_type, name=name)
        return jsonify({'records': records})
    except Exception as e:
        logger.error(f"Error getting records for {domain}: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Add record
@app.route('/api/domains/<domain>/records', methods=['POST'])
@require_auth
def add_record(domain):
    try:
        data = request.json
        
        if not data or not all(k in data for k in ['name', 'type', 'data']):
            return jsonify({'error': 'Missing required fields (name, type, data)'}), 400
            
        record = {
            'name': data['name'],
            'type': data['type'],
            'data': data['data'],
            'ttl': data.get('ttl', 3600)
        }
        
        success = client.add_record(domain, record)
        
        if success:
            return jsonify({'status': 'success', 'message': f"Record added to {domain}"})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to add record'}), 500
    except Exception as e:
        logger.error(f"Error adding record to {domain}: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Update record
@app.route('/api/domains/<domain>/records', methods=['PUT'])
@require_auth
def update_record(domain):
    try:
        data = request.json
        
        if not data or not all(k in data for k in ['name', 'type', 'data']):
            return jsonify({'error': 'Missing required fields (name, type, data)'}), 400
            
        success = client.update_record_ip(data['data'], domain, data['name'], data['type'])
        
        if success:
            return jsonify({'status': 'success', 'message': f"Record updated for {domain}"})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to update record'}), 500
    except Exception as e:
        logger.error(f"Error updating record for {domain}: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Delete records
@app.route('/api/domains/<domain>/records', methods=['DELETE'])
@require_auth
def delete_records(domain):
    try:
        record_type = request.args.get('type')
        name = request.args.get('name')
        
        if not name and not record_type:
            return jsonify({'error': 'At least one of name or type is required'}), 400
            
        success = client.delete_records(domain, name=name, record_type=record_type)
        
        if success:
            return jsonify({'status': 'success', 'message': f"Records deleted from {domain}"})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to delete records'}), 500
    except Exception as e:
        logger.error(f"Error deleting records from {domain}: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Default to port 5000, but allow override from environment
    port = int(os.environ.get('PORT', 5000))
    # In production, you'd want to run this behind a proper WSGI server
    # For development/testing only:
    app.run(host='0.0.0.0', port=port)
EOF

        # Create systemd service file for API
        if [ "$DEVELOPMENT_MODE" = false ]; then
            print_message "Creating systemd service file for API service..."
            cat > "/etc/systemd/system/godaddypy-api.service" << EOF
[Unit]
Description=GoDaddyPy API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="GODADDY_TOKEN=$GODADDY_API_KEY"
Environment="GODADDY_SECRET=$GODADDY_API_SECRET"
ExecStart=$VENV_DIR/bin/python -m flask --app godaddypy_cli.api run --host=0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        fi
    fi

    print_success "Project files created successfully"
}

# ============================
# Install Package Dependencies
# ============================
install_package_dependencies() {
    print_step "Installing Package Dependencies"
    
    # Install dependencies
    print_message "Installing required packages..."
    pip install godaddypy rich

    # Install additional dependencies for server mode
    if [ "$SERVER_MODE" = true ]; then
        print_message "Installing server dependencies..."
        pip install flask gunicorn
    fi
    
    # Install development dependencies
    if [ "$DEVELOPMENT_MODE" = true ]; then
        print_message "Installing development dependencies..."
        pip install pytest pytest-cov flake8 twine build
    fi
    
    print_success "Package dependencies installed successfully"
}

# ============================
# Install the CLI Package
# ============================
install_cli_package() {
    print_step "Installing CLI Package"
    
    # Install the package in development mode
    print_message "Installing GoDaddyPy CLI..."
    pip install -e .
    
    if [ "$DEVELOPMENT_MODE" = false ]; then
        # Create a wrapper script for system-wide usage
        print_message "Creating system-wide wrapper script..."
        cat > "$SYSTEMWIDE_BIN" << EOF
#!/bin/bash
# Wrapper script for GoDaddyPy CLI

# Source environment variables if they exist
if [ -f "$CONFIG_DIR/env" ]; then
    source "$CONFIG_DIR/env"
fi

# Activate virtual environment and run the CLI
source "$VENV_DIR/bin/activate"
python -m godaddypy_cli "\$@"
EOF

        # Make the script executable
        chmod +x "$SYSTEMWIDE_BIN"

        # Store API credentials in environment file
        if [ -n "$GODADDY_API_KEY" ] && [ -n "$GODADDY_API_SECRET" ]; then
            print_message "Storing API credentials..."
            cat > "$CONFIG_DIR/env" << EOF
GODADDY_TOKEN=$GODADDY_API_KEY
GODADDY_SECRET=$GODADDY_API_SECRET
EOF
            chmod 600 "$CONFIG_DIR/env"
        fi
    fi
    
    print_success "CLI package installed successfully"
}

# ============================
# Initialize Git Repository
# ============================
init_git_repository() {
    if [ "$INSTALL_ONLY" = true ]; then
        return
    fi
    
    print_step "Initializing Git Repository"
    
    # Initialize git repository
    if [ -d ".git" ]; then
        print_message "Git repository already initialized"
    else
        print_message "Initializing git repository..."
        git init
        
        # Add all files to git
        git add .
        
        # Initial commit
        git commit -m "Initial commit of GoDaddyPy CLI"
        
        print_message "Git repository initialized"
        
        # Configure remote if we're in development mode
        if [ "$DEVELOPMENT_MODE" = true ]; then
            print_message "You can now push to GitHub with:"
            echo "  git remote add origin https://github.com/$GITHUB_USERNAME/$PROJECT_NAME.git"
            echo "  git push -u origin main"
        fi
    fi
    
    print_success "Git repository initialized successfully"
}

# ============================
# Setup API Service
# ============================
setup_api_service() {
    if [ "$SERVER_MODE" = false ]; then
        return
    fi
    
    print_step "Setting Up API Service"
    
    if [ "$DEVELOPMENT_MODE" = true ]; then
        print_message "API service setup for development environment:"
        echo "  To start the API service, run:"
        echo "  source venv/bin/activate"
        echo "  export GODADDY_TOKEN=your_api_key"
        echo "  export GODADDY_SECRET=your_api_secret"
        echo "  python -m flask --app godaddypy_cli.api run"
    else
        print_message "Setting up systemd service for API..."
        
        # Reload systemd to read new service file
        systemctl daemon-reload
        
        # Try to start the service
        if systemctl start godaddypy-api; then
            print_message "API service started successfully"
            
            # Enable service to start on boot
            systemctl enable godaddypy-api
            print_message "API service enabled to start on boot"
        else
            print_error "Failed to start API service. Check logs with: journalctl -u godaddypy-api.service"
        fi
    fi
    
    print_success "API service setup completed"
}

# ============================
# Main Function
# ============================
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Welcome message
    clear
    echo "======================================================"
    echo "       GoDaddyPy CLI - Complete Setup Script          "
    echo "======================================================"
    echo ""
    print_message "This script will set up the GoDaddyPy CLI project"
    
    # Display configuration
    echo ""
    echo "Configuration:"
    echo "  Install Only:    $INSTALL_ONLY"
    echo "  Development:     $DEVELOPMENT_MODE"
    echo "  Server Mode:     $SERVER_MODE"
    if [ -n "$GODADDY_API_KEY" ] && [ -n "$GODADDY_API_SECRET" ]; then
        echo "  API Credentials: Provided"
    else
        echo "  API Credentials: Not provided"
    fi
    echo ""
    
    # Confirm configuration
    if ! confirm "Continue with this configuration?"; then
        print_message "Setup cancelled"
        exit 0
    fi
    
    # If API credentials not provided but needed, ask for them
    if { [ "$SERVER_MODE" = true ] || [ "$DEVELOPMENT_MODE" = false ]; } && { [ -z "$GODADDY_API_KEY" ] || [ -z "$GODADDY_API_SECRET" ]; }; then
        echo ""
        print_message "GoDaddy API credentials are required for this setup."
        read -p "Enter your GoDaddy API Key: " GODADDY_API_KEY
        read -p "Enter your GoDaddy API Secret: " GODADDY_API_SECRET
        echo ""
    fi
    
    # Run setup steps
    check_requirements
    install_system_dependencies
    setup_project_structure
    create_python_environment
    create_project_files
    install_package_dependencies
    install_cli_package
    init_git_repository
    setup_api_service
    
    # Final message
    echo ""
    echo "======================================================"
    echo "                  SETUP COMPLETE                      "
    echo "======================================================"
    echo ""
    print_success "GoDaddyPy CLI has been successfully set up!"
    
    # Display usage information
    if [ "$DEVELOPMENT_MODE" = true ]; then
        echo ""
        echo "Development Setup:"
        echo "  To activate virtual environment:"
        echo "    source venv/bin/activate"
        echo ""
        echo "  To install in development mode:"
        echo "    pip install -e ."
        echo ""
        echo "  To run tests:"
        echo "    pytest"
        echo ""
        echo "  To build package:"
        echo "    python -m build"
        echo ""
        echo "  To create a release:"
        echo "    git tag -a v0.1.0 -m 'First release'"
        echo "    git push origin v0.1.0"
        echo ""
    else
        echo ""
        echo "System Installation:"
        echo "  The GoDaddyPy CLI is now available as the 'godaddy' command."
        echo "  Examples:"
        echo "    godaddy -i                            # Start interactive mode"
        echo "    godaddy domains                       # List all domains"
        echo "    godaddy records example.com           # List all records for domain"
        echo "    godaddy add example.com --name www --type A --data 192.168.1.1"
        echo ""
        if [ "$SERVER_MODE" = true ]; then
            echo "  API Service:"
            echo "    The API service is available at: http://localhost:5000/api/"
            echo "    Available endpoints:"
            echo "      GET    /api/health                        - Health check"
            echo "      GET    /api/domains                       - List domains"
            echo "      GET    /api/domains/{domain}/records      - Get records"
            echo "      POST   /api/domains/{domain}/records      - Add record"
            echo "      PUT    /api/domains/{domain}/records      - Update record"
            echo "      DELETE /api/domains/{domain}/records      - Delete records"
            echo ""
            echo "    Service management:"
            echo "      systemctl status godaddypy-api            - Check status"
            echo "      systemctl restart godaddypy-api           - Restart service"
            echo "      journalctl -u godaddypy-api.service       - View logs"
            echo ""
        fi
    fi
}

# Run main function with all arguments
main "$@"
