#!/usr/bin/env python3
"""Validate the thin Apple Watch amount launcher."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from typing import Any, Iterable


DISALLOWED_ACTIONS = {
    "is.workflow.actions.choosefromlist",
    "is.workflow.actions.documentpicker.open",
    "is.workflow.actions.documentpicker.save",
    "is.workflow.actions.downloadurl",
    "is.workflow.actions.file.getfoldercontents",
}


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

    if document.get("WFWorkflowTypes") != ["Watch"]:
        failures.append("shortcut must be exposed only as a Watch workflow")

    prompt_actions = [
        action for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask"
    ]
    if len(prompt_actions) != 1:
        failures.append("watch launcher must have exactly one number prompt")
    else:
        prompt = prompt_actions[0].get("WFWorkflowActionParameters", {})
        if prompt.get("WFAskActionDefaultAnswer") != "197":
            failures.append("watch prompt default must be the string 197")
        if prompt.get("WFAskActionDefaultAnswerNumber") != "197":
            failures.append("watch prompt numeric default must be 197")
        if prompt.get("WFInputType") != "Number":
            failures.append("watch prompt must use number input")

    run_actions = [
        action for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.runworkflow"
    ]
    if len(run_actions) != 1:
        failures.append("watch launcher must run exactly one Shortcut")
    else:
        run = run_actions[0].get("WFWorkflowActionParameters", {})
        if run.get("WFWorkflowName") != "喝水BO～":
            failures.append("watch launcher must target 喝水BO～")
        if "payload" not in str(run.get("WFInput", "")):
            failures.append("watch launcher must pass the payload to the executor")

    identifiers = {
        action.get("WFWorkflowActionIdentifier") for action in actions
    }
    if "is.workflow.actions.round" not in identifiers:
        failures.append("watch amount must be rounded to an integer")
    for identifier in sorted(DISALLOWED_ACTIONS & identifiers):
        failures.append(f"watch launcher contains unsupported action: {identifier}")
    if "drink:" not in all_text:
        failures.append("watch payload must use the drink:<ml> command")
    if "查看今日记录" in all_text:
        failures.append("watch launcher must not show today's records")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: Watch launcher defaults to 197ml and delegates to the iPhone executor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
