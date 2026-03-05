#!/usr/bin/env bash
# compsync.sh — Synchronize repository configurations from MiguelRodo/comp
#
# MiguelRodo/comp layout that this script syncs from:
#
#   .devcontainer/
#     .Rprofile               → .devcontainer/.Rprofile
#     Dockerfile              → .devcontainer/Dockerfile
#     devcontainer.json       → .devcontainer/devcontainer.json  (merge or overwrite)
#     prebuild/
#       devcontainer.json     → .devcontainer/prebuild/devcontainer.json  (merge or overwrite)
#     renv/                   → .devcontainer/renv/              (copy directory)
#     scripts/                → .devcontainer/scripts/           (copy directory; +x on .sh)
#   scripts/                  → scripts/                         (copy directory; +x on .sh)
#
# Usage:
#   compsync update [--yes] [--no-cleanup]
#   compsync --help
#
# Commands:
#   update    Clone MiguelRodo/comp and interactively apply configurations
#
# Options:
#   --yes         Accept all prompts automatically (non-interactive mode)
#   --no-cleanup  Skip the cleanup step (do not delete .comp-tmp/)
#   -h, --help    Show this help message

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
COMP_REPO="https://github.com/MiguelRodo/comp.git"
COMP_TMP_DIR=".comp-tmp"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✓  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${RED}✗  $*${NC}" >&2; }

# Ask a yes/no question.  Returns 0 for yes, 1 for no.
# If AUTO_YES is set, always return 0.
ask() {
    local prompt="$1"
    if [ "${AUTO_YES:-false}" = "true" ]; then
        echo -e "${YELLOW}?  $prompt [y/N] (auto: y)${NC}"
        return 0
    fi
    echo -e "${YELLOW}?  $prompt [y/N]${NC} "
    local answer
    read -r answer
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# Ask a multiple-choice question. Prints the chosen option to stdout.
# If AUTO_YES is set, chooses the first option.
ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    if [ "${AUTO_YES:-false}" = "true" ]; then
        echo -e "${YELLOW}?  $prompt (auto: ${options[0]})${NC}" >&2
        echo "${options[0]}"
        return 0
    fi
    echo -e "${YELLOW}?  $prompt${NC}" >&2
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt" >&2
        i=$((i + 1))
    done
    local choice
    while true; do
        printf "Enter number [1-%d]: " "${#options[@]}" >&2
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice - 1))]}"
            return 0
        fi
        echo "Invalid choice. Please enter a number between 1 and ${#options[@]}." >&2
    done
}

# ---------------------------------------------------------------------------
# Script location helpers (for finding merge-json.py)
# ---------------------------------------------------------------------------
script_dir() {
    # Return the directory containing this script, resolving symlinks.
    local src="${BASH_SOURCE[0]}"
    while [ -L "$src" ]; do
        local dir
        dir="$(cd "$(dirname "$src")" && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd "$(dirname "$src")" && pwd
}

SCRIPT_DIR="$(script_dir)"
MERGE_JSON_SCRIPT="$SCRIPT_DIR/merge-json.py"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
Usage: compsync <command> [options]

Commands:
  update    Clone MiguelRodo/comp and interactively apply configurations

Options:
  --yes         Accept all prompts automatically (non-interactive mode)
  --no-cleanup  Skip cleanup of .comp-tmp/ after applying configurations
  -h, --help    Show this help message and exit

Examples:
  compsync update
  compsync update --yes
  compsync update --no-cleanup
EOF
}

# ---------------------------------------------------------------------------
# Step 1 — Fetch MiguelRodo/comp
# ---------------------------------------------------------------------------
cmd_fetch() {
    local target_dir="$1"

    info "Cloning $COMP_REPO into $target_dir …"

    if [ -d "$target_dir" ]; then
        warn "$target_dir already exists — pulling latest changes."
        git -C "$target_dir" pull --ff-only 2>/dev/null \
            || { warn "Pull failed; removing stale clone and re-cloning."; rm -rf "$target_dir"; git clone --depth=1 "$COMP_REPO" "$target_dir"; }
    else
        git clone --depth=1 "$COMP_REPO" "$target_dir"
    fi
    success "Cloned $COMP_REPO to $target_dir"
}

# ---------------------------------------------------------------------------
# Step 2 — Ensure .comp-tmp/ is in .gitignore
# ---------------------------------------------------------------------------
cmd_gitignore() {
    local gitignore=".gitignore"
    local entry="$COMP_TMP_DIR/"

    if grep -qxF "$entry" "$gitignore" 2>/dev/null; then
        info "$entry already in $gitignore"
        return 0
    fi

    if ask "Add '$entry' to $gitignore?"; then
        printf '\n# compsync temporary clone\n%s\n' "$entry" >> "$gitignore"
        success "Added $entry to $gitignore"
    else
        warn "Skipped updating $gitignore — be careful not to commit $COMP_TMP_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Step 3a — Apply Dockerfile
# ---------------------------------------------------------------------------
apply_dockerfile() {
    local src="$1/.devcontainer/Dockerfile"
    local dst=".devcontainer/Dockerfile"

    [ -f "$src" ] || { warn "Source Dockerfile not found at $src — skipping."; return 0; }

    if ask "Overwrite $dst with the version from comp?"; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        success "Copied Dockerfile → $dst"
    else
        info "Skipped Dockerfile"
    fi
}

# ---------------------------------------------------------------------------
# Step 3b — Apply scripts/
# ---------------------------------------------------------------------------
apply_scripts() {
    local src_dir="$1/scripts"
    local dst_dir="scripts"

    [ -d "$src_dir" ] || { warn "Source scripts/ not found at $src_dir — skipping."; return 0; }

    if ask "Copy/mirror $src_dir → $dst_dir (and set +x on all .sh files)?"; then
        mkdir -p "$dst_dir"
        cp -r "$src_dir/." "$dst_dir/"
        # Ensure executable permissions on all shell scripts
        find "$dst_dir" -name "*.sh" -exec chmod +x {} \;
        success "Mirrored scripts/ and set +x on .sh files"
    else
        info "Skipped scripts/"
    fi
}

# ---------------------------------------------------------------------------
# Step 3c — Apply a devcontainer.json file (merge or overwrite)
# Internal helper used by apply_devcontainer_json and apply_prebuild_json.
# ---------------------------------------------------------------------------
_apply_json_file() {
    local src="$1"
    local dst="$2"
    local label="$3"

    [ -f "$src" ] || { warn "Source $label not found at $src — skipping."; return 0; }

    local action
    if [ -f "$dst" ]; then
        action="$(ask_choice "$label exists — how should it be handled?" "merge" "overwrite" "skip")"
    else
        action="overwrite"
        info "No existing $dst — will create it."
    fi

    if [ "$action" = "merge" ]; then
        if command -v python3 &>/dev/null && [ -f "$MERGE_JSON_SCRIPT" ]; then
            info "Merging $src into $dst …"
            python3 "$MERGE_JSON_SCRIPT" "$dst" "$src" "$dst"
            success "Merged $label"
        else
            warn "python3 or merge-json.py not found; falling back to overwrite."
            action="overwrite"
        fi
    fi

    if [ "$action" = "overwrite" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        success "Overwrote $dst"
    elif [ "$action" = "skip" ]; then
        info "Skipped $label"
    fi
}

apply_devcontainer_json() {
    _apply_json_file \
        "$1/.devcontainer/devcontainer.json" \
        ".devcontainer/devcontainer.json" \
        "devcontainer.json"
}

# ---------------------------------------------------------------------------
# Step 3e — Apply .devcontainer/prebuild/devcontainer.json
# ---------------------------------------------------------------------------
apply_prebuild_json() {
    _apply_json_file \
        "$1/.devcontainer/prebuild/devcontainer.json" \
        ".devcontainer/prebuild/devcontainer.json" \
        "prebuild/devcontainer.json"
}

# ---------------------------------------------------------------------------
# Step 3f — Apply .devcontainer/renv/ (renv lockfile directory)
# ---------------------------------------------------------------------------
apply_renv() {
    local src_dir="$1/.devcontainer/renv"
    local dst_dir=".devcontainer/renv"

    [ -d "$src_dir" ] || { warn "Source renv/ not found at $src_dir — skipping."; return 0; }

    if ask "Copy $src_dir → $dst_dir (renv lockfile)?"; then
        mkdir -p "$dst_dir"
        cp -r "$src_dir/." "$dst_dir/"
        success "Copied renv/ → $dst_dir"
    else
        info "Skipped renv/"
    fi
}

# ---------------------------------------------------------------------------
# Step 3g — Apply .devcontainer/scripts/ (R utility scripts)
# ---------------------------------------------------------------------------
apply_devcontainer_scripts() {
    local src_dir="$1/.devcontainer/scripts"
    local dst_dir=".devcontainer/scripts"

    [ -d "$src_dir" ] || { warn "Source .devcontainer/scripts/ not found at $src_dir — skipping."; return 0; }

    if ask "Copy $src_dir → $dst_dir (and set +x on any .sh files)?"; then
        mkdir -p "$dst_dir"
        cp -r "$src_dir/." "$dst_dir/"
        find "$dst_dir" -name "*.sh" -exec chmod +x {} \;
        success "Copied .devcontainer/scripts/ and set +x on .sh files"
    else
        info "Skipped .devcontainer/scripts/"
    fi
}

# ---------------------------------------------------------------------------
# Step 3d — Apply .Rprofile
# ---------------------------------------------------------------------------
apply_rprofile() {
    local src="$1/.devcontainer/.Rprofile"
    local dst=".devcontainer/.Rprofile"

    [ -f "$src" ] || { warn "Source .Rprofile not found at $src — skipping."; return 0; }

    local action
    if [ -f "$dst" ]; then
        action="$(ask_choice ".Rprofile exists — how should it be handled?" "overwrite" "append" "skip")"
    else
        action="overwrite"
        info "No existing $dst — will create it."
    fi

    case "$action" in
        overwrite)
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            success "Overwrote $dst"
            ;;
        append)
            {
                printf '\n# --- appended by compsync ---\n'
                cat "$src"
            } >> "$dst"
            success "Appended comp .Rprofile to $dst"
            ;;
        skip)
            info "Skipped .Rprofile"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Step 4 — Cleanup
# ---------------------------------------------------------------------------
cmd_cleanup() {
    local target_dir="$1"

    [ -d "$target_dir" ] || return 0

    if ask "Delete $target_dir now that sync is complete?"; then
        rm -rf "$target_dir"
        success "Deleted $target_dir"
    else
        info "Kept $target_dir — you can remove it manually later."
    fi
}

# ---------------------------------------------------------------------------
# Main command: update
# ---------------------------------------------------------------------------
cmd_update() {
    local do_cleanup=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes)         AUTO_YES=true ;;
            --no-cleanup)  do_cleanup=false ;;
            -h|--help)     usage; exit 0 ;;
            *) error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done

    # Ensure we are in the root of a git repository
    if ! git rev-parse --show-toplevel &>/dev/null; then
        error "Not inside a git repository. Please run compsync from your project root."
        exit 1
    fi
    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"
    cd "$repo_root"

    local comp_tmp="$repo_root/$COMP_TMP_DIR"

    info "=== compsync update ==="
    info "Repository root: $repo_root"
    echo ""

    # 1. Fetch
    cmd_fetch "$comp_tmp"
    echo ""

    # 2. Gitignore
    cmd_gitignore
    echo ""

    # 3. Apply configurations
    info "--- Applying configurations ---"
    echo ""
    apply_dockerfile "$comp_tmp"
    echo ""
    apply_scripts "$comp_tmp"
    echo ""
    apply_devcontainer_json "$comp_tmp"
    echo ""
    apply_prebuild_json "$comp_tmp"
    echo ""
    apply_renv "$comp_tmp"
    echo ""
    apply_devcontainer_scripts "$comp_tmp"
    echo ""
    apply_rprofile "$comp_tmp"
    echo ""

    # 4. Cleanup
    if [ "$do_cleanup" = true ]; then
        cmd_cleanup "$comp_tmp"
    else
        info "Skipping cleanup (--no-cleanup flag set)."
    fi

    echo ""
    success "compsync update complete."
}

# ---------------------------------------------------------------------------
# Entry point — only runs when the script is executed directly, not sourced.
# This guard allows test scripts to `source compsync.sh` to access functions.
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    AUTO_YES=false

    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    case "$1" in
        update)
            shift
            cmd_update "$@"
            ;;
        *)
            error "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
fi
