#!/usr/bin/env bash
# compsync — Debian package wrapper installed to /usr/bin/compsync

set -euo pipefail

SCRIPT_DIR="/usr/share/compsync/scripts"

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
