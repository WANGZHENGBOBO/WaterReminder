#!/usr/bin/env python3
"""Validate that the iPhone Shortcut safely accepts only explicit Watch payloads."""

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


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    with Path(sys.argv[1]).open("rb") as shortcut:
        document = plistlib.load(shortcut)
    actions = document.get("WFWorkflowActions", [])
    all_text = "\n".join(strings(actions))
    failures: list[str] = []

    if "ShortcutInput" in all_text:
        if document.get("WFWorkflowHasShortcutInputVariables") is not True:
            failures.append("shortcut input variables must be enabled for Watch payloads")
    if "无法识别手表输入" in all_text:
        failures.append("unrecognised shortcut input must be ignored, not rejected")
    if "watchCommand" not in all_text:
        failures.append("explicit Watch command state is missing")
    if not any(
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.conditional"
        and action.get("WFWorkflowActionParameters", {}).get("WFConditionalActionString")
        == "drink"
        for action in actions
    ):
        failures.append("Watch payload must require the explicit drink command")
    if any(
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.runworkflow"
        for action in actions
    ):
        failures.append("phone shortcut must not run another shortcut")

    prompts = [
        action.get("WFWorkflowActionParameters", {})
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask"
    ]
    if len(prompts) != 1:
        failures.append("phone shortcut must always ask for one amount")
    elif (
        prompts[0].get("WFAskActionDefaultAnswer") != "197"
        or prompts[0].get("WFAskActionDefaultAnswerNumber") != 197
        or prompts[0].get("WFInputType") != "Number"
    ):
        failures.append("phone amount prompt must default to numeric 197")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: iPhone Shortcut prompts unless invoked with an explicit Watch payload")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
