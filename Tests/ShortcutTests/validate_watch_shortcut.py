#!/usr/bin/env python3
"""Validate the thin Apple Watch-to-iPhone message bridge."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from typing import Any, Iterable


DISALLOWED_ACTIONS = {
    "is.workflow.actions.documentpicker.open",
    "is.workflow.actions.documentpicker.save",
    "is.workflow.actions.downloadurl",
    "is.workflow.actions.file.getfoldercontents",
    "is.workflow.actions.runworkflow",
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

    prompts = [
        action.get("WFWorkflowActionParameters", {})
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask"
    ]
    if len(prompts) != 1:
        failures.append("watch launcher must have exactly one number prompt")
    elif (
        prompts[0].get("WFAskActionDefaultAnswer") != "197"
        or prompts[0].get("WFAskActionDefaultAnswerNumber") != 197
        or prompts[0].get("WFInputType") != "Number"
    ):
        failures.append("watch prompt must default to numeric 197")

    messages = [
        action.get("WFWorkflowActionParameters", {})
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.sendmessage"
    ]
    if len(messages) != 1:
        failures.append("watch launcher must send exactly one message")
    elif "payload" not in str(messages[0].get("WFSendMessageContent", "")):
        failures.append("watch message must send the generated payload")
    if "drink:喝水BO～" not in all_text:
        failures.append("watch payload must carry the drink command")

    questions = document.get("WFWorkflowImportQuestions", [])
    if len(questions) != 1:
        failures.append("watch launcher must ask for the user's own Apple ID")
    elif questions[0].get("ParameterKey") != "WFTextActionText":
        failures.append("watch recipient question must bind to the Text action")
    else:
        question_text = str(questions[0].get("Text", ""))
        if "Apple ID" not in question_text or "iMessage" not in question_text or "短信" not in question_text:
            failures.append("watch recipient question must request an Apple ID for the iMessage-only setup")

    identifiers = {action.get("WFWorkflowActionIdentifier") for action in actions}
    if "is.workflow.actions.phonenumber" in identifiers:
        failures.append("watch recipient must remain an Apple ID rather than a phone number")
    if messages and "recipientText" not in str(
        messages[0].get("WFSendMessageActionRecipients", "")
    ):
        failures.append("watch message must use the Apple ID text recipient")
    if "is.workflow.actions.round" not in identifiers:
        failures.append("watch amount must be rounded")
    for identifier in sorted(DISALLOWED_ACTIONS & identifiers):
        failures.append(f"watch launcher contains unsupported action: {identifier}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: Watch launcher prompts, rounds, and iMessages the Apple ID recipient")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
