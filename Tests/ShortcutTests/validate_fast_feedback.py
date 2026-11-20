#!/usr/bin/env python3
"""Validate that recording finishes without a blocking result screen."""

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


def action_text(action: dict[str, Any]) -> str:
    return "\n".join(strings(action.get("WFWorkflowActionParameters", {})))


def variable_names(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        name = value.get("VariableName")
        if isinstance(name, str):
            found.add(name)
        for child in value.values():
            found.update(variable_names(child))
    elif isinstance(value, list):
        for child in value:
            found.update(variable_names(child))
    return found


def parameter_path(parameters: dict[str, Any], key: str) -> str:
    value = parameters.get(key)
    if isinstance(value, str):
        return value
    return "\n".join(strings(value))


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    with Path(sys.argv[1]).open("rb") as shortcut:
        actions = plistlib.load(shortcut).get("WFWorkflowActions", [])

    failures: list[str] = []
    if any(
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.choosefromlist"
        for action in actions
    ):
        failures.append("recording must not start with a menu")

    prompt_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask"
    ]
    if len(prompt_indices) != 1:
        failures.append("recording must have exactly one amount prompt")

    if prompt_indices:
        prompt_parameters = actions[prompt_indices[0]].get("WFWorkflowActionParameters", {})
        if prompt_parameters.get("WFAskActionDefaultAnswer") != "197":
            failures.append("the phone prompt default must be 197")
        if prompt_parameters.get("WFAskActionDefaultAnswerNumber") != 197:
            failures.append("the phone numeric default must be 197")

    rounded_assignments = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.setvariable"
        and action.get("WFWorkflowActionParameters", {}).get("WFVariableName") == "amount"
        and index > min(prompt_indices, default=0)
    ]
    validation_conditions = [
        action.get("WFWorkflowActionParameters", {})
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.conditional"
        and action.get("WFWorkflowActionParameters", {}).get("WFCondition") is None
        and "WFActionParameterFilterTemplates" in str(action)
    ]
    if not rounded_assignments:
        failures.append("the rounded amount is not assigned before validation")
    if not any("amount" in variable_names(condition) for condition in validation_conditions):
        failures.append("amount validation must use the final amount variable")

    notifications = [
        (index, action)
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.notification"
    ]
    if len(notifications) != 1:
        failures.append("recording must finish with exactly one progress notification")
    elif not all(token in action_text(notifications[0][1]) for token in ("已记录", "完成")):
        failures.append("the notification must contain the amount and progress")

    blocking_results = [
        action
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.showresult"
        and any(token in action_text(action) for token in ("已记录", "已同步到电脑"))
    ]
    if blocking_results:
        failures.append("recording must not finish with a blocking Show Result screen")

    post_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.downloadurl"
        and "/v1/drink" in action_text(action)
    ]
    if not post_indices:
        failures.append("the LAN drink request is missing")
    elif notifications and max(post_indices) > notifications[0][0]:
        failures.append("the LAN drink request must run before the progress notification")

    if any("已同步到电脑" in text for text in strings(actions)):
        failures.append("recording must not show a second sync confirmation")

    event_save_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.documentpicker.save"
        and "/喝水BO～/Sync/Events/" in action_text(action)
    ]
    if not event_save_indices:
        failures.append("the drink event save action is missing")
    elif prompt_indices and max(event_save_indices) < min(prompt_indices):
        failures.append("the drink event must be saved after the amount prompt")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: recording syncs before one non-blocking progress notification")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
