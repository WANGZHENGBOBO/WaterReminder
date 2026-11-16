#!/usr/bin/env python3
"""Patch Cherri output so Save File consumes the JSON Text action directly."""

import plistlib
import sys
from pathlib import Path


shortcut_path = Path(sys.argv[1])
with shortcut_path.open("rb") as shortcut_file:
    document = plistlib.load(shortcut_file)

actions = document["WFWorkflowActions"]
json_output = None
for action in actions:
    parameters = action.get("WFWorkflowActionParameters", {})
    if (
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.setvariable"
        and parameters.get("WFVariableName") == "eventJSON"
    ):
        value = parameters.get("WFInput", {}).get("Value", {})
        if value.get("Type") == "ActionOutput":
            json_output = value
        break

if json_output is None:
    raise SystemExit("eventJSON text output was not found")

for action in actions:
    parameters = action.get("WFWorkflowActionParameters", {})
    if (
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.documentpicker.save"
        and "/喝水BO～/Sync/Events/" in str(parameters.get("WFFileDestinationPath", ""))
    ):
        parameters["WFInput"] = {
            "Value": dict(json_output),
            "WFSerializationType": "WFTextTokenAttachment",
        }
        break
else:
    raise SystemExit("Events JSON Save File action was not found")

for action in actions:
    parameters = action.get("WFWorkflowActionParameters", {})
    if (
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.downloadurl"
        and "/v1/today" in str(parameters.get("WFURL", ""))
    ):
        parameters["WFShowError"] = False

# The executor delegates Watch launches to the thin watch launcher. Keeping the
# executor off watch surfaces prevents users from running the iCloud file actions
# directly on watchOS and hitting remote-execution errors.
document["WFWorkflowTypes"] = ["WFWorkflowTypeShowInSearch"]

with shortcut_path.open("wb") as shortcut_file:
    plistlib.dump(document, shortcut_file, fmt=plistlib.FMT_BINARY, sort_keys=False)
