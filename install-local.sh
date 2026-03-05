#!/usr/bin/env bash
# install-local.sh — Install compsync to the user's local directory without sudo.
# Installs to ~/.local/bin and ~/.local/share/compsync

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOCAL_BIN="$HOME/.local/bin"
LOCAL_SHARE="$HOME/.local/share/compsync"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Installing compsync to user's local directory...${NC}"
echo

echo "Checking dependencies..."
MISSING_DEPS=()
for dep in bash git python3; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo "Please install them, e.g.:"
    echo "  sudo apt-get install ${MISSING_DEPS[*]}"
    exit 1
fi
echo -e "${GREEN}✓ All dependencies are installed${NC}"
echo

echo "Creating installation directories..."
mkdir -p "$LOCAL_BIN"
mkdir -p "$LOCAL_SHARE"
echo -e "${GREEN}✓ Created directories${NC}"
echo

echo "Installing scripts to $LOCAL_SHARE..."
cp -r "$SCRIPT_DIR/scripts" "$LOCAL_SHARE/"
find "$LOCAL_SHARE/scripts" -type f -name "*.sh" -exec chmod +x {} \;
echo -e "${GREEN}✓ Scripts installed${NC}"
echo

echo "Creating compsync command in $LOCAL_BIN..."
cat > "$LOCAL_BIN/compsync" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# compsync — wrapper installed to ~/.local/bin

set -euo pipefail

SCRIPT_DIR="$HOME/.local/share/compsync/scripts"

usage() {
  cat <<EOF
Usage: compsync <command> [options]

Commands:
  update    Clone MiguelRodo/comp and interactively apply configurations

Run 'compsync <command> --help' for more information on a command.
EOF
}

if [ $# -eq 0 ]; then
  usage >&2; exit 1
fi

case "$1" in
  -h|--help)
    usage; exit 0 ;;
  update)
    exec "$SCRIPT_DIR/compsync.sh" "$@" ;;
  *)
    echo "Error: unknown command '$1'" >&2; echo "" >&2; usage >&2; exit 1 ;;
esac
WRAPPER_EOF

chmod +x "$LOCAL_BIN/compsync"
echo -e "${GREEN}✓ compsync command installed${NC}"
echo

if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "${YELLOW}Warning: $LOCAL_BIN is not in your PATH${NC}"
    echo
    echo "Add the following line to your ~/.bashrc or ~/.profile:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Then reload with: source ~/.bashrc"
else
    echo -e "${GREEN}✓ $LOCAL_BIN is already in PATH${NC}"
fi
echo

echo -e "${GREEN}Installation complete!${NC}"
echo
echo "You can now use the compsync command:"
echo "  compsync --help"
echo
echo "To uninstall, run:"
echo "  bash $SCRIPT_DIR/uninstall-local.sh"
echo
