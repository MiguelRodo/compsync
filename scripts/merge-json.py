#!/usr/bin/env python3
"""
merge-json.py — Deep-merge two JSON files.

Usage:
    merge-json.py <base.json> <overlay.json> <output.json>

The merge strategy is:
  - Dicts: recursively merged (overlay wins for scalar conflicts).
  - Lists: concatenated with duplicates removed (order: base first, then new
    items from overlay).
  - Scalars: overlay wins.

This is used by compsync to merge devcontainer.json from MiguelRodo/comp into
the local copy without discarding existing configuration.
"""

import json
import sys
from typing import Any


def deep_merge(base: Any, overlay: Any) -> Any:
    """Recursively merge *overlay* into *base* and return the result.

    Rules:
    - Both dicts: merge keys recursively; overlay wins on scalar conflicts.
    - Both lists: concatenate, removing duplicates (preserving order).
    - Otherwise:  overlay wins.
    """
    if isinstance(base, dict) and isinstance(overlay, dict):
        merged = dict(base)
        for key, val in overlay.items():
            if key in merged:
                merged[key] = deep_merge(merged[key], val)
            else:
                merged[key] = val
        return merged

    if isinstance(base, list) and isinstance(overlay, list):
        # Preserve order, deduplicate by converting unhashable items to str keys
        seen: set = set()
        result = []
        for item in base + overlay:
            # Use JSON representation as a hashable key for deduplication
            key = json.dumps(item, sort_keys=True)
            if key not in seen:
                seen.add(key)
                result.append(item)
        return result

    # Scalar or mixed types: overlay wins
    return overlay


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: merge-json.py <base.json> <overlay.json> <output.json>",
            file=sys.stderr,
        )
        return 1

    base_path, overlay_path, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        with open(base_path, "r", encoding="utf-8") as f:
            base_data = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Error reading base file '{base_path}': {exc}", file=sys.stderr)
        return 1

    try:
        with open(overlay_path, "r", encoding="utf-8") as f:
            overlay_data = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Error reading overlay file '{overlay_path}': {exc}", file=sys.stderr)
        return 1

    merged = deep_merge(base_data, overlay_data)

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=2)
            f.write("\n")
    except OSError as exc:
        print(f"Error writing output file '{output_path}': {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
