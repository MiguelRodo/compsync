#!/usr/bin/env python3
"""
tests/test-merge-json.py — Unit tests for scripts/merge-json.py

Tests the deep_merge logic directly by importing merge-json.py.
"""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

# ---------------------------------------------------------------------------
# Load merge-json.py as a module (it lives next to scripts/)
# ---------------------------------------------------------------------------
SCRIPT_PATH = Path(__file__).parent.parent / "scripts" / "merge-json.py"

spec = importlib.util.spec_from_file_location("merge_json", SCRIPT_PATH)
merge_json = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge_json)

deep_merge = merge_json.deep_merge


class TestDeepMergeScalars(unittest.TestCase):
    def test_overlay_wins_string(self):
        self.assertEqual(deep_merge("base", "overlay"), "overlay")

    def test_overlay_wins_int(self):
        self.assertEqual(deep_merge(1, 2), 2)

    def test_overlay_none(self):
        self.assertIsNone(deep_merge("base", None))

    def test_base_none(self):
        self.assertEqual(deep_merge(None, "overlay"), "overlay")


class TestDeepMergeDicts(unittest.TestCase):
    def test_disjoint_keys_merged(self):
        base = {"a": 1}
        overlay = {"b": 2}
        result = deep_merge(base, overlay)
        self.assertEqual(result, {"a": 1, "b": 2})

    def test_overlay_wins_on_conflict(self):
        base = {"a": 1, "b": "old"}
        overlay = {"b": "new"}
        result = deep_merge(base, overlay)
        self.assertEqual(result["b"], "new")
        self.assertEqual(result["a"], 1)

    def test_nested_dict_merge(self):
        base = {"outer": {"keep": True, "override": "old"}}
        overlay = {"outer": {"override": "new", "add": "extra"}}
        result = deep_merge(base, overlay)
        self.assertEqual(result["outer"]["keep"], True)
        self.assertEqual(result["outer"]["override"], "new")
        self.assertEqual(result["outer"]["add"], "extra")

    def test_base_preserved(self):
        base = {"a": 1}
        overlay = {"b": 2}
        result = deep_merge(base, overlay)
        # base must not be mutated
        self.assertNotIn("b", base)
        self.assertEqual(result["a"], 1)


class TestDeepMergeLists(unittest.TestCase):
    def test_list_concatenation(self):
        base = [1, 2]
        overlay = [3, 4]
        result = deep_merge(base, overlay)
        self.assertEqual(result, [1, 2, 3, 4])

    def test_list_deduplication(self):
        base = ["ext-a", "ext-b"]
        overlay = ["ext-b", "ext-c"]
        result = deep_merge(base, overlay)
        # ext-b should appear only once
        self.assertEqual(result.count("ext-b"), 1)
        self.assertIn("ext-a", result)
        self.assertIn("ext-c", result)

    def test_list_of_dicts_deduplication(self):
        base = [{"x": 1}]
        overlay = [{"x": 1}, {"x": 2}]
        result = deep_merge(base, overlay)
        self.assertEqual(len(result), 2)
        self.assertIn({"x": 1}, result)
        self.assertIn({"x": 2}, result)

    def test_base_order_preserved(self):
        base = ["a", "b"]
        overlay = ["c", "d"]
        result = deep_merge(base, overlay)
        self.assertEqual(result[:2], ["a", "b"])


class TestDeepMergeDevcontainerJson(unittest.TestCase):
    """Integration-style tests mimicking a real devcontainer.json merge."""

    BASE = {
        "name": "my-project",
        "extensions": ["ms-vscode.cpptools", "ms-python.python"],
        "settings": {
            "editor.tabSize": 4,
            "python.defaultInterpreterPath": "/usr/bin/python3",
        },
        "postCreateCommand": "echo project-specific",
    }

    OVERLAY = {
        "name": "comp",
        "extensions": ["ms-python.python", "github.copilot"],
        "settings": {
            "editor.tabSize": 2,
            "editor.formatOnSave": True,
        },
        "features": {"ghcr.io/devcontainers/features/git:1": {}},
    }

    def test_name_overlay_wins(self):
        result = deep_merge(self.BASE, self.OVERLAY)
        self.assertEqual(result["name"], "comp")

    def test_extensions_deduplicated(self):
        result = deep_merge(self.BASE, self.OVERLAY)
        extensions = result["extensions"]
        self.assertEqual(extensions.count("ms-python.python"), 1)
        self.assertIn("ms-vscode.cpptools", extensions)
        self.assertIn("github.copilot", extensions)

    def test_settings_merged(self):
        result = deep_merge(self.BASE, self.OVERLAY)
        settings = result["settings"]
        # Overlay wins for tabSize
        self.assertEqual(settings["editor.tabSize"], 2)
        # Base key retained
        self.assertEqual(settings["python.defaultInterpreterPath"], "/usr/bin/python3")
        # New key from overlay added
        self.assertTrue(settings["editor.formatOnSave"])

    def test_base_only_key_retained(self):
        result = deep_merge(self.BASE, self.OVERLAY)
        self.assertEqual(result["postCreateCommand"], "echo project-specific")

    def test_overlay_only_key_added(self):
        result = deep_merge(self.BASE, self.OVERLAY)
        self.assertIn("features", result)


class TestMainCLI(unittest.TestCase):
    """Test the CLI entry point (reads/writes files)."""

    def _write_json(self, path: str, data: dict) -> None:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    def _read_json(self, path: str) -> dict:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    def test_cli_merge_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            base_path = os.path.join(tmp, "base.json")
            overlay_path = os.path.join(tmp, "overlay.json")
            output_path = os.path.join(tmp, "output.json")

            self._write_json(base_path, {"a": 1, "list": [1, 2]})
            self._write_json(overlay_path, {"b": 2, "list": [2, 3]})

            old_argv = sys.argv
            sys.argv = ["merge-json.py", base_path, overlay_path, output_path]
            try:
                rc = merge_json.main()
            finally:
                sys.argv = old_argv

            self.assertEqual(rc, 0)
            result = self._read_json(output_path)
            self.assertEqual(result["a"], 1)
            self.assertEqual(result["b"], 2)
            self.assertEqual(sorted(result["list"]), [1, 2, 3])

    def test_cli_wrong_arg_count(self):
        old_argv = sys.argv
        sys.argv = ["merge-json.py", "only-one-arg"]
        try:
            rc = merge_json.main()
        finally:
            sys.argv = old_argv
        self.assertEqual(rc, 1)

    def test_cli_missing_base_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            overlay_path = os.path.join(tmp, "overlay.json")
            output_path = os.path.join(tmp, "output.json")
            self._write_json(overlay_path, {"x": 1})

            old_argv = sys.argv
            sys.argv = [
                "merge-json.py",
                "/nonexistent/base.json",
                overlay_path,
                output_path,
            ]
            try:
                rc = merge_json.main()
            finally:
                sys.argv = old_argv
            self.assertEqual(rc, 1)

    def test_cli_in_place_merge(self):
        """Output path same as base — simulates compsync's in-place merge."""
        with tempfile.TemporaryDirectory() as tmp:
            base_path = os.path.join(tmp, "devcontainer.json")
            overlay_path = os.path.join(tmp, "overlay.json")

            self._write_json(base_path, {"name": "local", "extensions": ["ext-a"]})
            self._write_json(overlay_path, {"name": "comp", "extensions": ["ext-b"]})

            old_argv = sys.argv
            sys.argv = ["merge-json.py", base_path, overlay_path, base_path]
            try:
                rc = merge_json.main()
            finally:
                sys.argv = old_argv

            self.assertEqual(rc, 0)
            result = self._read_json(base_path)
            self.assertEqual(result["name"], "comp")
            self.assertIn("ext-a", result["extensions"])
            self.assertIn("ext-b", result["extensions"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
