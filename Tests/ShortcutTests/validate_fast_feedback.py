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


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2

    with Path(sys.argv[1]).open("rb") as shortcut:
        actions = plistlib.load(shortcut).get("WFWorkflowActions", [])

    failures: list[str] = []
    identifiers = [action.get("WFWorkflowActionIdentifier") for action in actions]

    menu_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.choosefromlist"
    ]
    sync_read_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.documentpicker.open"
        and "/喝水BO～/Sync" in action_text(action)
    ]
    if not menu_indices:
        failures.append("the drink menu is missing")
    elif sync_read_indices and min(menu_indices) > min(sync_read_indices):
        failures.append("the drink menu must appear before scanning iCloud files")

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

    if "is.workflow.actions.ask" not in identifiers:
        failures.append("the custom amount prompt is missing")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: recording syncs before one non-blocking progress notification")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
