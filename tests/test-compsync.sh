#!/usr/bin/env bash
# tests/test-compsync.sh — Automated test suite for compsync
#
# Tests the core bash workflow: fetch, gitignore, apply, cleanup.
# All tests use an isolated temporary directory and a fake "comp" repo
# so no real network access is required.

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours & counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() { echo ""; echo "============================================"; echo "$1"; echo "============================================"; }
print_test()   { echo ""; echo -e "${YELLOW}TEST: $1${NC}"; TESTS_RUN=$((TESTS_RUN + 1)); }
print_pass()   { echo -e "${GREEN}✓ PASS: $1${NC}"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
print_fail()   { echo -e "${RED}✗ FAIL: $1${NC}"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
print_info()   { echo "ℹ  $1"; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPSYNC_SCRIPT="$PROJECT_ROOT/scripts/compsync.sh"
MERGE_JSON_SCRIPT="$PROJECT_ROOT/scripts/merge-json.py"

# ---------------------------------------------------------------------------
# Shared test fixture: create a fake "comp" clone tree
# ---------------------------------------------------------------------------
build_fake_comp() {
    local dir="$1"
    mkdir -p "$dir/.devcontainer/prebuild"
    mkdir -p "$dir/.devcontainer/renv/holder"
    mkdir -p "$dir/.devcontainer/scripts/r"
    mkdir -p "$dir/scripts/helper"

    # Dockerfile
    echo "FROM ubuntu:22.04" > "$dir/.devcontainer/Dockerfile"

    # devcontainer.json
    cat > "$dir/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "comp",
  "extensions": ["ms-python.python"],
  "postCreateCommand": "echo hello"
}
EOF

    # prebuild devcontainer.json
    cat > "$dir/.devcontainer/prebuild/devcontainer.json" <<'EOF'
{
  "name": "comp-prebuild",
  "extensions": ["ms-python.python"]
}
EOF

    # .Rprofile
    echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' > "$dir/.devcontainer/.Rprofile"

    # renv lockfile
    echo '{"R":{"Version":"4.3.0"}}' > "$dir/.devcontainer/renv/holder/renv.lock"

    # R switch script
    echo '# switch.R placeholder' > "$dir/.devcontainer/scripts/r/switch.R"

    # Bash scripts — intentionally NOT chmod +x here; compsync must fix that
    echo '#!/usr/bin/env bash' > "$dir/scripts/setup-repos.sh"
    echo '#!/usr/bin/env bash' > "$dir/scripts/run-pipeline.sh"
    echo '#!/usr/bin/env bash' > "$dir/scripts/helper/clone-repos.sh"
}

# ---------------------------------------------------------------------------
# Shared test fixture: create a minimal local git repo
# ---------------------------------------------------------------------------
build_local_repo() {
    local dir="$1"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    touch "$dir/.gitignore"
    git -C "$dir" add .gitignore
    git -C "$dir" commit -q -m "init"
}

# ---------------------------------------------------------------------------
# Helper: run a single compsync function inside an isolated subshell.
# Usage: run_fn <work_dir> <function_name> [extra_args...]
# ---------------------------------------------------------------------------
run_fn() {
    local work_dir="$1"; shift
    local fn_name="$1";  shift
    (
        cd "$work_dir"
        AUTO_YES=true
        # shellcheck disable=SC1090
        source "$COMPSYNC_SCRIPT"
        "$fn_name" "$@"
    ) 2>/dev/null
}

print_header "compsync test suite"
print_info "Project root: $PROJECT_ROOT"

# ===========================================================================
# Test 1: Script exists and is executable
# ===========================================================================
print_test "compsync.sh exists and is executable"

if [ -x "$COMPSYNC_SCRIPT" ]; then
    print_pass "compsync.sh is executable"
else
    print_fail "compsync.sh not found or not executable at $COMPSYNC_SCRIPT"
fi

# ===========================================================================
# Test 2: Help message
# ===========================================================================
print_test "compsync.sh --help shows usage"

if "$COMPSYNC_SCRIPT" --help 2>&1 | grep -q "Usage:"; then
    print_pass "Help message displays"
else
    print_fail "Help message does not display"
fi

# ===========================================================================
# Test 3: merge-json.py exists
# ===========================================================================
print_test "merge-json.py exists"

if [ -f "$MERGE_JSON_SCRIPT" ]; then
    print_pass "merge-json.py found"
else
    print_fail "merge-json.py not found at $MERGE_JSON_SCRIPT"
fi

# ===========================================================================
# Test 4: .gitignore updated with .comp-tmp/
# ===========================================================================
print_test ".comp-tmp/ is added to .gitignore"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
run_fn "$WORK_DIR" cmd_gitignore

if grep -qxF ".comp-tmp/" "$WORK_DIR/.gitignore"; then
    print_pass ".comp-tmp/ added to .gitignore"
else
    print_fail ".comp-tmp/ not found in .gitignore"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 5: scripts/ copied and .sh files have +x permissions
# ===========================================================================
print_test "scripts/ copied with executable permissions on .sh files"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
FAKE_COMP="$(mktemp -d)"
build_fake_comp "$FAKE_COMP"

run_fn "$WORK_DIR" apply_scripts "$FAKE_COMP"
rm -rf "$FAKE_COMP"

ALL_EXEC=true
if [ -d "$WORK_DIR/scripts" ]; then
    while IFS= read -r -d '' sh_file; do
        if [ ! -x "$sh_file" ]; then
            print_info "Not executable: $sh_file"
            ALL_EXEC=false
        fi
    done < <(find "$WORK_DIR/scripts" -name "*.sh" -print0)
else
    ALL_EXEC=false
fi

if $ALL_EXEC; then
    print_pass "All .sh files in scripts/ are executable"
else
    print_fail "Some .sh files are missing +x or scripts/ was not copied"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 6: Dockerfile copied
# ===========================================================================
print_test "Dockerfile copied to .devcontainer/Dockerfile"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
FAKE_COMP="$(mktemp -d)"
build_fake_comp "$FAKE_COMP"

run_fn "$WORK_DIR" apply_dockerfile "$FAKE_COMP"
rm -rf "$FAKE_COMP"

if [ -f "$WORK_DIR/.devcontainer/Dockerfile" ] && grep -q "FROM ubuntu" "$WORK_DIR/.devcontainer/Dockerfile"; then
    print_pass "Dockerfile copied correctly"
else
    print_fail "Dockerfile was not copied to .devcontainer/"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 7: .Rprofile copied (overwrite path — no existing .Rprofile)
# ===========================================================================
print_test ".Rprofile created when none exists (overwrite)"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
FAKE_COMP="$(mktemp -d)"
build_fake_comp "$FAKE_COMP"
# No existing .Rprofile → apply_rprofile should create it automatically

run_fn "$WORK_DIR" apply_rprofile "$FAKE_COMP"
rm -rf "$FAKE_COMP"

if [ -f "$WORK_DIR/.devcontainer/.Rprofile" ] && grep -q "r-project.org" "$WORK_DIR/.devcontainer/.Rprofile"; then
    print_pass ".Rprofile created with comp content"
else
    print_fail ".Rprofile not created"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 8: cleanup removes .comp-tmp/
# ===========================================================================
print_test "cleanup removes .comp-tmp/ directory"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
mkdir -p "$WORK_DIR/.comp-tmp"
touch "$WORK_DIR/.comp-tmp/somefile"

run_fn "$WORK_DIR" cmd_cleanup "$WORK_DIR/.comp-tmp"

if [ ! -d "$WORK_DIR/.comp-tmp" ]; then
    print_pass ".comp-tmp/ deleted by cleanup"
else
    print_fail ".comp-tmp/ still exists after cleanup"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 9: .devcontainer/scripts/ copied with +x on .sh files
# ===========================================================================
print_test ".devcontainer/scripts/ copied with +x on .sh files"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
FAKE_COMP="$(mktemp -d)"
build_fake_comp "$FAKE_COMP"
# Add a .sh file inside .devcontainer/scripts to verify chmod
echo '#!/usr/bin/env bash' > "$FAKE_COMP/.devcontainer/scripts/setup.sh"

run_fn "$WORK_DIR" apply_devcontainer_scripts "$FAKE_COMP"
rm -rf "$FAKE_COMP"

if [ -d "$WORK_DIR/.devcontainer/scripts" ] && [ -x "$WORK_DIR/.devcontainer/scripts/setup.sh" ]; then
    print_pass ".devcontainer/scripts/ copied and .sh files are executable"
else
    print_fail ".devcontainer/scripts/ was not copied or .sh not executable"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Test 10: renv/ directory copied
# ===========================================================================
print_test ".devcontainer/renv/ directory copied"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_local_repo "$WORK_DIR"
FAKE_COMP="$(mktemp -d)"
build_fake_comp "$FAKE_COMP"

run_fn "$WORK_DIR" apply_renv "$FAKE_COMP"
rm -rf "$FAKE_COMP"

if [ -f "$WORK_DIR/.devcontainer/renv/holder/renv.lock" ]; then
    print_pass "renv/holder/renv.lock copied"
else
    print_fail ".devcontainer/renv/ was not copied"
fi
rm -rf "$WORK_DIR"
trap - EXIT

# ===========================================================================
# Summary
# ===========================================================================
print_header "Test Summary"

echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"

if [ "$TESTS_FAILED" -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
fi
