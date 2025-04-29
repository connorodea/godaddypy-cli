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
