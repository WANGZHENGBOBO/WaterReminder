#!/usr/bin/env python3
"""Validate one-file-per-drink Shortcut output."""

import plistlib
import sys
from pathlib import Path


with Path(sys.argv[1]).open("rb") as shortcut_file:
    actions = plistlib.load(shortcut_file)["WFWorkflowActions"]

if any(action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.file.append" for action in actions):
    raise SystemExit("FAIL: Append File must not be used")

amount_prompts = [
    action.get("WFWorkflowActionParameters", {})
    for action in actions
    if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.ask"
    and action.get("WFWorkflowActionParameters", {}).get("WFAskActionPrompt")
    == "这次喝了多少 ml？"
]
if len(amount_prompts) != 1:
    raise SystemExit("FAIL: Custom amount prompt is missing or duplicated")
if any(
    key in amount_prompts[0]
    for key in ("WFAskActionDefaultAnswer", "WFAskActionDefaultAnswerNumber")
):
    raise SystemExit("FAIL: Custom amount prompt must not prefill a number")

for index, action in enumerate(actions):
    if action.get("WFWorkflowActionIdentifier") != "is.workflow.actions.documentpicker.save":
        continue
    parameters = action.get("WFWorkflowActionParameters", {})
    path = parameters.get("WFFileDestinationPath", "")
    if "/喝水BO～/Sync/Events/" not in str(path):
        continue
    value = parameters.get("WFInput", {}).get("Value", {})
    if value.get("Type") != "ActionOutput":
        raise SystemExit("FAIL: Save File must consume JSON text output directly")
    output_uuid = value.get("OutputUUID")
    if not any(
        previous.get("WFWorkflowActionIdentifier")
        in {"is.workflow.actions.gettext", "is.workflow.actions.text.combine"}
        and previous.get("WFWorkflowActionParameters", {}).get("UUID") == output_uuid
        for previous in actions[:index]
    ):
        raise SystemExit("FAIL: Save File input is not generated JSON text")
    print("PASS: Shortcut saves each drink as a direct JSON event")
    break
else:
    raise SystemExit("FAIL: Events JSON Save File action is missing")
