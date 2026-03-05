"""
compsync — Synchronize repository configurations from MiguelRodo/comp.

A Python wrapper for the compsync Bash script.
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional, List

__version__ = "1.0.0"


def get_script_path(script_name: str = "compsync.sh") -> str:
    """Return the absolute path to a bundled script.

    Args:
        script_name: Filename of the script (default: compsync.sh).

    Returns:
        Absolute path as a string.

    Raises:
        FileNotFoundError: If the script cannot be located.
    """
    # Try importlib.resources (Python ≥ 3.9)
    try:
        if sys.version_info >= (3, 9):
            from importlib.resources import files  # type: ignore[attr-defined]
            script_path = files("compsync").joinpath("scripts", script_name)
            if script_path.is_file():  # type: ignore[union-attr]
                return str(script_path)
        else:
            import importlib.resources as pkg_resources
            with pkg_resources.path("compsync.scripts", script_name) as p:
                if p.is_file():
                    return str(p)
    except (ImportError, FileNotFoundError, AttributeError, TypeError):
        pass

    # Fallback: path relative to this file
    module_dir = Path(__file__).parent
    script_path = module_dir / "scripts" / script_name
    if script_path.is_file():
        return str(script_path)

    raise FileNotFoundError(
        f"Cannot find '{script_name}'. Make sure the package is properly installed."
    )


def run_script(script_name: str = "compsync.sh", args: Optional[List[str]] = None) -> subprocess.CompletedProcess:
    """Run a bundled script with the given arguments.

    Args:
        script_name: Filename of the script to run.
        args: Extra command-line arguments.

    Returns:
        :class:`subprocess.CompletedProcess` instance.

    Raises:
        FileNotFoundError: Script not found.
        subprocess.CalledProcessError: Script exited with non-zero status.
    """
    script_path = get_script_path(script_name)

    try:
        os.chmod(script_path, 0o755)
    except (OSError, PermissionError):
        pass

    cmd = [script_path]
    if args:
        cmd.extend(args)

    return subprocess.run(cmd, check=True, text=True)


def update(
    yes: bool = False,
    no_cleanup: bool = False,
) -> subprocess.CompletedProcess:
    """Clone MiguelRodo/comp and interactively apply configurations.

    Args:
        yes: If ``True``, accept all prompts automatically.
        no_cleanup: If ``True``, skip deleting the ``.comp-tmp/`` directory.

    Returns:
        :class:`subprocess.CompletedProcess` instance.
    """
    script_args = ["update"]
    if yes:
        script_args.append("--yes")
    if no_cleanup:
        script_args.append("--no-cleanup")
    return run_script("compsync.sh", script_args)


USAGE = """\
Usage: compsync <command> [options]

Commands:
  update    Clone MiguelRodo/comp and interactively apply configurations

Run 'compsync <command> --help' for more information on a command.
"""

SUBCOMMAND_SCRIPTS: dict = {
    "update": "compsync.sh",
}


def main() -> None:
    """Entry point for the ``compsync`` CLI command."""
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help"):
        print(USAGE, end="")
        sys.exit(0 if args else 1)

    subcommand = args[0]
    remaining = args[1:]

    if subcommand not in SUBCOMMAND_SCRIPTS:
        print(f"Error: unknown command '{subcommand}'\n", file=sys.stderr)
        print(USAGE, end="", file=sys.stderr)
        sys.exit(1)

    script = SUBCOMMAND_SCRIPTS[subcommand]

    try:
        run_script(script, [subcommand] + remaining)
        sys.exit(0)
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:  # noqa: BLE001
        print(f"Unexpected error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
