# compsync - Configuration Synchronization Tool

<a href="https://github.com/MiguelRodo/compsync/actions/workflows/test-suite.yml"><img src="https://github.com/MiguelRodo/compsync/actions/workflows/test-suite.yml/badge.svg"></a>

A command-line tool for synchronizing DevContainer configurations from [MiguelRodo/comp](https://github.com/MiguelRodo/comp) into your projects.

## Overview

Maintaining consistent DevContainer configurations across multiple repositories is time-consuming. `compsync` solves this by cloning the [MiguelRodo/comp](https://github.com/MiguelRodo/comp) repository and interactively applying its "gold standard" configurations to your current project.

Here's what `compsync` can sync into your project:

```
MiguelRodo/comp layout → your project
──────────────────────────────────────────────────
.devcontainer/Dockerfile         → .devcontainer/Dockerfile
.devcontainer/devcontainer.json  → .devcontainer/devcontainer.json  (merge or overwrite)
.devcontainer/prebuild/
  devcontainer.json              → .devcontainer/prebuild/devcontainer.json  (merge or overwrite)
.devcontainer/renv/              → .devcontainer/renv/
.devcontainer/scripts/           → .devcontainer/scripts/
.devcontainer/.Rprofile          → .devcontainer/.Rprofile
scripts/                         → scripts/
```

Run `compsync update` to apply configurations interactively:

```bash
compsync update
```

`compsync` will prompt you for each file/directory, letting you choose to overwrite, merge, append, or skip. For JSON files you can choose a **deep merge** that preserves your existing keys while adding new ones from `comp`.

### Options

#### `compsync update`

- Accept all prompts automatically with `--yes`, e.g. `compsync update --yes`
- Skip cleanup of the temporary clone with `--no-cleanup`, e.g. `compsync update --no-cleanup`

#### Interactive choices per file

| File / Directory | Available actions |
|---|---|
| `Dockerfile` | overwrite, skip |
| `devcontainer.json` | merge, overwrite, skip |
| `prebuild/devcontainer.json` | merge, overwrite, skip |
| `.Rprofile` | overwrite, append, skip |
| `renv/` | copy, skip |
| `.devcontainer/scripts/` | copy, skip |
| `scripts/` | copy, skip |

## Installation

You can install compsync as a system package (Ubuntu/Debian, macOS, Windows), from source, or as a Python package.

### <a></a>Ubuntu/Debian

You can install compsync from the APT repository, with a downloaded `.deb`, or to your local user directory (no sudo required).

#### Option 1: Local Installation (No sudo required)

Install to your user directory (`~/.local/bin`):

```bash
# Clone the repository
git clone https://github.com/MiguelRodo/compsync.git
cd compsync

# Run the local installer
bash install-local.sh
```

The installer will:
- Install the `compsync` command to `~/.local/bin`
- Install scripts to `~/.local/share/compsync/scripts`
- Check if `~/.local/bin` is in your PATH and provide instructions if needed

If `~/.local/bin` is not in your PATH, add this line to your `~/.bashrc` or `~/.profile`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload your configuration:

```bash
source ~/.bashrc
```

Run the compsync command:

```bash
compsync --help
```

To uninstall:

```bash
bash uninstall-local.sh
```

#### Option 2: Install from APT Repository (Recommended)

Install and update `compsync` directly via `apt` from <a href="https://github.com/MiguelRodo/apt-miguelrodo">MiguelRodo/apt-miguelrodo</a>:

```bash
# Add repository signing key
curl -fsSL https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/KEY.gpg \
   | sudo gpg --dearmor -o /usr/share/keyrings/miguelrodo-repos.gpg

# Add apt source
echo "deb [signed-by=/usr/share/keyrings/miguelrodo-repos.gpg] https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/ ./" \
   | sudo tee /etc/apt/sources.list.d/miguelrodo-repos.list >/dev/null

# Install compsync
sudo apt-get update
sudo apt-get install -y compsync
```

Run the compsync command:

```bash
compsync --help
```

To uninstall:

```bash
sudo apt-get remove compsync
```

#### Option 3: System-wide Installation from Release .deb (Requires sudo)

Install the .deb package to use the compsync command system-wide.

Download and install the latest `.deb` package from the <a href="https://github.com/MiguelRodo/compsync/releases">Releases page</a>:

```bash
# Download the latest release (replace VERSION_COMPSYNC with desired version)
VERSION_COMPSYNC=1.0.0
wget https://github.com/MiguelRodo/compsync/releases/download/v${VERSION_COMPSYNC}/compsync_${VERSION_COMPSYNC}_all.deb

# Install the package
sudo dpkg -i compsync_${VERSION_COMPSYNC}_all.deb

# Remove installation file
rm compsync_${VERSION_COMPSYNC}_all.deb

# If there are dependency issues, run:
sudo apt-get install -f
```

Run the compsync command:

```bash
compsync --help
```

To uninstall:

```bash
sudo dpkg -r compsync
```

#### Dependencies

All installation methods require:
- `bash` - Shell interpreter
- `git` - Version control
- `python3` - For JSON merging

These are typically pre-installed on Ubuntu/Debian systems. If not, install them:

```bash
sudo apt-get install bash git python3
```

### <a></a>Windows (Scoop)

Install using Scoop to use the compsync command in your shell.

Install using <a href="https://scoop.sh/">Scoop</a>:

```powershell
# Add the compsync bucket
scoop bucket add compsync https://github.com/MiguelRodo/compsync

# Install compsync
scoop install compsync
```

Run the compsync command:

```powershell
compsync --help
```

Dependencies (`git` and `python`) are automatically installed by Scoop. You'll also need Git for Windows for bash support.

### <a></a>Windows (Manual)

Install manually to use the compsync command in PowerShell or Git Bash.

1. Clone the repository:
   ```powershell
   git clone https://github.com/MiguelRodo/compsync.git
   cd compsync
   ```

2. Run the installer:
   ```powershell
   .\install.ps1
   ```

3. Restart your PowerShell session for the PATH changes to take effect.

4. Verify installation:
   ```powershell
   compsync --help
   ```

#### Windows Dependencies

- **Git for Windows** (required for bash and git): <a href="https://git-scm.com/download/win">Download here</a>
- **Python 3** (required for JSON merging): <a href="https://www.python.org/downloads/">Download here</a>

### <a></a>macOS (Homebrew)

Install using Homebrew to use the compsync command system-wide.

Install using <a href="https://brew.sh/">Homebrew</a>:

```bash
# Add the compsync tap
brew tap MiguelRodo/compsync

# Install compsync
brew install compsync
```

Run the compsync command:

```bash
compsync --help
```

The formula automatically handles the `python3` dependency. Git is typically pre-installed on macOS.

### <a></a>From Source

Install from source to use the compsync command or run scripts directly.

```bash
git clone https://github.com/MiguelRodo/compsync.git
cd compsync

# For Ubuntu/Debian - Local installation (no sudo)
bash install-local.sh

# For Ubuntu/Debian - System-wide installation (requires sudo)
sudo dpkg-buildpackage -us -uc -b
sudo dpkg -i ../compsync_*.deb

# For other systems, use the script directly
./scripts/compsync.sh
```

Run the compsync command:

```bash
compsync --help
```

### <a></a>Python Package

Install the Python package to use compsync from Python or the command line.

```bash
# Install from local clone
git clone https://github.com/MiguelRodo/compsync.git
cd compsync
pip install .

# Or install in development mode
pip install -e .

# Use the compsync command
compsync update
compsync update --yes
compsync --help
```

Run the compsync command:

```bash
compsync --help
```

**System Requirements:** The Python package requires `bash`, `git`, and `python3` to be installed on your system. On Windows, you need <a href="https://git-scm.com/download/win">Git for Windows</a> (which includes Git Bash) or WSL (Windows Subsystem for Linux).

**How it works:** The Python package bundles the Bash scripts in `src/compsync/scripts/` and provides both a CLI entry point and a Python API using `subprocess.run()`.

**Python API:**

```python
from compsync import update

# Apply configurations interactively
update()

# Accept all prompts automatically
update(yes=True)

# Skip cleanup of temporary clone
update(no_cleanup=True)

# Combine options
update(yes=True, no_cleanup=True)
```

## Quick Start

### 1. Navigate to your project root

```bash
cd /path/to/your/project
```

### 2. Run the update command

```bash
compsync update
```

`compsync` will:
1. Clone [MiguelRodo/comp](https://github.com/MiguelRodo/comp) into a temporary `.comp-tmp/` directory
2. Offer to add `.comp-tmp/` to your `.gitignore`
3. Interactively prompt for each configuration file/directory
4. Clean up the temporary clone when done

For a fully non-interactive run (accept all prompts):

```bash
compsync update --yes
```

## Usage

### Subcommands

The `compsync` CLI uses subcommands:

```bash
compsync update [flags]   # Sync configurations from MiguelRodo/comp
compsync --help           # Show available subcommands
```

### compsync update

Synchronize configurations from [MiguelRodo/comp](https://github.com/MiguelRodo/comp):

```bash
# Run interactively (prompts for each file)
compsync update

# Accept all prompts automatically
compsync update --yes

# Skip cleanup of .comp-tmp/ after sync
compsync update --no-cleanup

# Show help
compsync update --help
```

### What gets synced

| Source (in MiguelRodo/comp) | Destination (in your project) | Mode |
|---|---|---|
| `.devcontainer/Dockerfile` | `.devcontainer/Dockerfile` | overwrite |
| `.devcontainer/devcontainer.json` | `.devcontainer/devcontainer.json` | merge or overwrite |
| `.devcontainer/prebuild/devcontainer.json` | `.devcontainer/prebuild/devcontainer.json` | merge or overwrite |
| `.devcontainer/renv/` | `.devcontainer/renv/` | copy |
| `.devcontainer/scripts/` | `.devcontainer/scripts/` | copy |
| `.devcontainer/.Rprofile` | `.devcontainer/.Rprofile` | overwrite or append |
| `scripts/` | `scripts/` | copy |

Shell scripts (`.sh` files) are automatically made executable after copying.

## Examples

### Example 1: Interactive sync

```bash
cd my-project
compsync update
# Follow the prompts to choose which files to sync and how
```

### Example 2: Non-interactive sync (CI/CD or scripted setup)

```bash
cd my-project
compsync update --yes
# All prompts are automatically accepted
```

### Example 3: Sync without cleanup (inspect what was downloaded)

```bash
cd my-project
compsync update --no-cleanup
# .comp-tmp/ is kept after sync so you can inspect the source files
ls .comp-tmp/
```

## Troubleshooting

### Not inside a git repository

`compsync` must be run from within a git repository:

```bash
git init
compsync update
```

### Missing Dependencies

```bash
sudo apt-get install bash git python3
```

### Permission Issues

After local installation, if `~/.local/bin/compsync` is not executable:

```bash
chmod +x ~/.local/bin/compsync
```

### JSON merge failing

If `python3` is not available, `compsync` falls back to overwriting the target JSON file. Install `python3` to enable deep merge support:

```bash
sudo apt-get install python3
```

## Uninstallation

### Local Installation

```bash
bash uninstall-local.sh
```

### APT Installation

```bash
sudo apt-get remove compsync
```

### System-wide Installation (.deb)

```bash
sudo dpkg -r compsync
```

## License

MIT License - see debian/copyright for details

## Contributing

Issues and pull requests welcome at https://github.com/MiguelRodo/compsync

## Author

Miguel Rodo
