#!/usr/bin/env python3
"""Normalize Cherri's stringified numeric fields in a Shortcut document."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from typing import Any


def numeric_value(value: Any) -> int | float | None:
    if not isinstance(value, str):
        return None
    try:
        number = float(value)
    except ValueError:
        return None
    return int(number) if number.is_integer() else number


def normalize(document: dict[str, Any]) -> int:
    changes = 0
    for action in document.get("WFWorkflowActions", []):
        parameters = action.get("WFWorkflowActionParameters", {})
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.number":
            key = "WFNumberActionNumber"
            number = numeric_value(parameters.get(key))
            if number is not None:
                parameters[key] = number
                changes += 1
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask":
            key = "WFAskActionDefaultAnswerNumber"
            number = numeric_value(parameters.get(key))
            if number is not None:
                parameters[key] = number
                changes += 1
    return changes


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    shortcut_path = Path(sys.argv[1])
    with shortcut_path.open("rb") as shortcut_file:
        document = plistlib.load(shortcut_file)
    changes = normalize(document)
    with shortcut_path.open("wb") as shortcut_file:
        plistlib.dump(document, shortcut_file, fmt=plistlib.FMT_BINARY, sort_keys=False)
    print(f"PASS: normalized {changes} numeric Shortcut fields")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
