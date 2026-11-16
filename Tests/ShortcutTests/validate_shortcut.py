#!/usr/bin/env python3
"""Validate the data flow compiled into the iPhone Shortcut artifact."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from typing import Any, Iterable


def references(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        variable = value.get("VariableName")
        if isinstance(variable, str):
            found.add(variable)
        for child in value.values():
            found.update(references(child))
    elif isinstance(value, list):
        for child in value:
            found.update(references(child))
    return found


def assigned_name(action: dict[str, Any]) -> str | None:
    if action.get("WFWorkflowActionIdentifier") != "is.workflow.actions.setvariable":
        return None
    name = action.get("WFWorkflowActionParameters", {}).get("WFVariableName")
    return name if isinstance(name, str) else None


def has_math_then_assignment(
    actions: list[dict[str, Any]],
    operation: str,
    required_references: set[str],
    target: str,
) -> bool:
    for index, action in enumerate(actions[:-1]):
        identifier = action.get("WFWorkflowActionIdentifier")
        parameters = action.get("WFWorkflowActionParameters", {})
        if identifier != "is.workflow.actions.math":
            continue
        if parameters.get("WFMathOperation") != operation:
            continue
        if not required_references.issubset(references(parameters)):
            continue
        output_uuid = parameters.get("UUID")
        next_parameters = actions[index + 1].get("WFWorkflowActionParameters", {})
        assigned = next_parameters.get("WFInput", {}).get("Value", {})
        if assigned_name(actions[index + 1]) == target and assigned.get("OutputUUID") == output_uuid:
            return True
    return False


def file_paths(actions: Iterable[dict[str, Any]]) -> set[str]:
    paths: set[str] = set()
    for action in actions:
        parameters = action.get("WFWorkflowActionParameters", {})
        path = parameters.get("WFFilePath")
        if isinstance(path, str):
            paths.add(path)
    return paths


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    with Path(sys.argv[1]).open("rb") as shortcut:
        document = plistlib.load(shortcut)
    actions = document.get("WFWorkflowActions", [])

    failures: list[str] = []
    if not has_math_then_assignment(
        actions, "+", {"baseTotal", "pending"}, "total"
    ):
        failures.append("total must equal baseTotal + pending")
    if not has_math_then_assignment(actions, "-", {"goal", "total"}, "remaining"):
        failures.append("remaining must equal goal - total")

    paths = file_paths(actions)
    for required in (
        "/喝水BO～/Sync/iphone-amounts.txt",
        "/喝水BO～/Sync/iphone-times.txt",
    ):
        if required not in paths:
            failures.append(f"phone log is not read: {required}")

    identifiers = {
        action.get("WFWorkflowActionIdentifier") for action in actions
    }
    for required in (
        "is.workflow.actions.text.split",
        "is.workflow.actions.count",
        "is.workflow.actions.getitemfromlist",
        "is.workflow.actions.detect.number",
    ):
        if required not in identifiers:
            failures.append(f"missing action for log reconciliation: {required}")

    assignments = {
        action.get("WFWorkflowActionParameters", {}).get("WFVariableName")
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.setvariable"
    }
    for required in ("recordAmountText", "recordTimeText", "recordAmountLogLine", "recordTimeLogLine"):
        if required not in assignments:
            failures.append(f"missing explicit text materialization: {required}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: Shortcut reconciles phone logs and computes totals explicitly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
