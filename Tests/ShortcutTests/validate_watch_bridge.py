#!/usr/bin/env python3
"""Validate that the iPhone executor accepts the Watch drink command."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from typing import Any, Iterable


def strings(value: Any) -> Iterable[str]:
    if isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)
    elif isinstance(value, str):
        yield value


def assigned_names(actions: list[dict[str, Any]]) -> set[str]:
    return {
        action.get("WFWorkflowActionParameters", {}).get("WFVariableName")
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.setvariable"
    }


def conditional_strings(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        candidate = value.get("WFConditionalActionString")
        if isinstance(candidate, str):
            found.add(candidate)
        for child in value.values():
            found.update(conditional_strings(child))
    elif isinstance(value, list):
        for child in value:
            found.update(conditional_strings(child))
    return found


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    with Path(sys.argv[1]).open("rb") as shortcut:
        document = plistlib.load(shortcut)

    actions = document.get("WFWorkflowActions", [])
    all_text = "\n".join(strings(actions))
    failures: list[str] = []

    workflow_types = document.get("WFWorkflowTypes", [])
    if "Watch" in workflow_types:
        failures.append("executor must not be exposed directly on Apple Watch")
    if document.get("WFWorkflowHasShortcutInputVariables") is not True:
        failures.append("shortcut input variable is not enabled")
    for variable in ("watchInputPresent", "watchAmount", "watchCleanAmount"):
        if variable not in assigned_names(actions):
            failures.append(f"watch input variable is missing: {variable}")
    if "drink" not in conditional_strings(actions):
        failures.append("watch drink command branch is missing")
    if "无法识别手表输入" not in all_text:
        failures.append("invalid watch input guidance is missing")
    for label in ("喝了 197ml", "自定义水量", "查看今日记录"):
        if label not in all_text:
            failures.append(f"iPhone menu choice is missing: {label}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: iPhone executor accepts drink:<ml> and keeps the normal menu")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
