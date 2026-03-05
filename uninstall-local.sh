#!/usr/bin/env bash
# uninstall-local.sh — Remove compsync from the user's local directory.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOCAL_BIN="$HOME/.local/bin"
LOCAL_SHARE="$HOME/.local/share/compsync"

echo -e "${YELLOW}Uninstalling compsync from user's local directory...${NC}"
echo

if [ -f "$LOCAL_BIN/compsync" ]; then
    echo "Removing compsync command from $LOCAL_BIN..."
    rm "$LOCAL_BIN/compsync"
    echo -e "${GREEN}✓ Removed compsync command${NC}"
else
    echo -e "${YELLOW}compsync command not found in $LOCAL_BIN${NC}"
fi
echo

if [ -d "$LOCAL_SHARE" ]; then
    echo "Removing scripts from $LOCAL_SHARE..."
    rm -rf "$LOCAL_SHARE"
    echo -e "${GREEN}✓ Removed scripts directory${NC}"
else
    echo -e "${YELLOW}Scripts directory not found at $LOCAL_SHARE${NC}"
fi
echo

echo -e "${GREEN}Uninstallation complete!${NC}"
echo
