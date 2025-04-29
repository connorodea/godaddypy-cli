# GoDaddyPy CLI

[![PyPI version](https://badge.fury.io/py/godaddypy-cli.svg)](https://badge.fury.io/py/godaddypy-cli)
[![CI/CD](https://github.com/connorodea/godaddypy-cli/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/connorodea/godaddypy-cli/actions/workflows/ci-cd.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A beautiful and interactive command-line interface for managing GoDaddy domains and DNS records.

## Features

✨ **Interactive Mode** - Navigate through menus to manage domains without remembering commands  
🎨 **Beautiful Output** - Colorful, well-formatted tables and progress indicators  
🔍 **Easy to Use** - Simple commands with smart confirmation prompts  
🛠 **Powerful** - Complete control over your GoDaddy domains and DNS records

## Installation

```bash
# Install from PyPI
pip install godaddypy-cli
```

## Configuration

There are three ways to provide your GoDaddy API credentials:

1. **Environment variables** (recommended):
   ```bash
   export GODADDY_TOKEN=YOUR_API_KEY
   export GODADDY_SECRET=YOUR_API_SECRET
   ```

2. **Command-line arguments**:
   ```bash
   godaddy --key YOUR_API_KEY --secret YOUR_API_SECRET domains
   ```

3. **Interactive prompt**:
   If credentials aren't provided, the CLI will securely prompt for them in interactive mode.

## Usage

### Interactive Mode (Recommended)

Simply run:

```bash
godaddy -i
```

This launches an interactive menu where you can:
- Browse and manage domains
- View, add, update, and delete DNS records
- Get guided through all operations with clear prompts

### Command Line Mode

#### List all domains

```bash
godaddy domains
```

#### Get all DNS records for a domain

```bash
godaddy records example.com
```

#### Get specific DNS records

```bash
godaddy records example.com --type A --name www
```

#### Add a DNS record

```bash
godaddy add example.com --name www --type A --data 192.168.1.1 --ttl 3600
```

#### Update a DNS record

```bash
godaddy update example.com --name www --type A --data 192.168.1.2
```

#### Delete DNS records

```bash
godaddy delete example.com --name www --type A
```

### JSON Output

Add the `--json` flag to any command to get JSON output:

```bash
godaddy records example.com --json
```

## Requirements

- Python 3.7+
- GoDaddy API credentials (get them from [GoDaddy Developer Portal](https://developer.godaddy.com/keys/))

## Development

```bash
# Clone the repository
git clone https://github.com/connorodea/godaddypy-cli.git
cd godaddypy-cli

# Install in development mode
pip install -e .

# Run tests
pytest
```

## License

MIT
