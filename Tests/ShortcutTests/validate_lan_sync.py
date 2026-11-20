#!/usr/bin/env python3
"""Validate the LAN request and device-origin fields in the compiled Shortcut."""

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


def strings(value: Any) -> Iterable[str]:
    if isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)
    elif isinstance(value, str):
        yield value


def action_parameters(actions: list[dict[str, Any]], identifier: str) -> list[dict[str, Any]]:
    return [
        action.get("WFWorkflowActionParameters", {})
        for action in actions
        if action.get("WFWorkflowActionIdentifier") == identifier
    ]


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} SHORTCUT", file=sys.stderr)
        return 2
    with Path(sys.argv[1]).open("rb") as shortcut:
        actions = plistlib.load(shortcut).get("WFWorkflowActions", [])

    failures: list[str] = []
    all_strings = list(strings(actions))
    all_text = "\n".join(all_strings)
    if "Devices" not in all_text:
        failures.append("Devices folder is not read")
    if "source\",\"source\":\"iphone\"" not in all_text and '"source":"iphone"' not in all_text:
        failures.append("event source must be iphone")
    if '"deviceShortName":"iPH"' not in all_text:
        failures.append("phone short name must be iPH")
    if "iphone-" not in all_text:
        failures.append("new phone event IDs must use the iphone- prefix")
    if not any(
        action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.file.getfoldercontents"
        for action in actions
    ):
        failures.append("folder contents action is missing")

    open_paths = [
        str(
            action.get("WFWorkflowActionParameters", {}).get("WFGetFilePath", "")
        )
        for action in actions
        if action.get("WFWorkflowActionIdentifier")
        == "is.workflow.actions.documentpicker.open"
    ]
    if "/喝水BO～/Sync" not in open_paths:
        failures.append(
            "file access must read the Sync folder once and derive child items"
        )
    requirement_paths = {"/喝水BO～/Sync/today-summary.json"}
    if not requirement_paths.issubset(set(open_paths)):
        failures.append("today summary must be read by direct file path")
    if "始终允许" not in all_text:
        failures.append("first-run permission guidance is missing")

    save_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.documentpicker.save"
        and "/喝水BO～/Sync/Events/" in str(
            action.get("WFWorkflowActionParameters", {}).get("WFFileDestinationPath", "")
        )
    ]
    request_indices = [
        index
        for index, action in enumerate(actions)
        if action.get("WFWorkflowActionIdentifier") == "is.workflow.actions.downloadurl"
        and "/v1/drink" in "\n".join(strings(action))
    ]
    if not save_indices:
        failures.append("Events save action is missing")
    if not request_indices:
        failures.append("LAN POST action is missing")
    if save_indices and request_indices and not (min(save_indices) < max(request_indices)):
        failures.append("iCloud save must precede the LAN request")

    if request_indices:
        request = actions[max(request_indices)].get("WFWorkflowActionParameters", {})
        if str(request.get("WFHTTPMethod", "")).upper() != "POST":
            failures.append("LAN request must use POST")
        if request.get("WFHTTPBodyType") != "File":
            failures.append("LAN request body must use a real file")
        if request.get("WFShowError") is not False:
            failures.append("LAN request must not abort after an iCloud save")
        request_references = references(request)
        if "eventFile" not in request_references:
            failures.append("LAN request must send the saved event file")
        if "eventJSON" in request_references:
            failures.append("LAN request must not send JSON text as a file body")
        if "Authorization" not in all_text or "Bearer" not in all_text:
            failures.append("LAN request authorization is missing")

    if any("/v1/today" in text for text in all_strings):
        failures.append("recording must not return to the separate today view")

    summary_text_assignments = [
        parameters
        for parameters in action_parameters(actions, "is.workflow.actions.setvariable")
        if str(parameters.get("WFVariableName", "")).lower().endswith("summarytext")
    ]
    if not summary_text_assignments:
        failures.append("today-summary file must be converted to text before parsing")

    device_text_assignments = [
        parameters
        for parameters in action_parameters(actions, "is.workflow.actions.setvariable")
        if str(parameters.get("WFVariableName", "")).lower().endswith("devicetext")
    ]
    if not device_text_assignments:
        failures.append("device JSON files must be converted to text before parsing")

    event_file_assignments = [
        parameters
        for parameters in action_parameters(actions, "is.workflow.actions.setvariable")
        if parameters.get("WFVariableName") == "eventFile"
    ]
    if not event_file_assignments:
        failures.append("Save File output must be captured as eventFile")
    elif not any(
        parameters.get("WFInput", {}).get("Value", {}).get("OutputName") == "SaveFile"
        for parameters in event_file_assignments
    ):
        failures.append("eventFile must be the Save File action output")

    payload_assignments = [
        parameters
        for parameters in action_parameters(actions, "is.workflow.actions.setvariable")
        if parameters.get("WFVariableName") == "eventPayload"
    ]
    if payload_assignments and "eventJSON" not in references(payload_assignments[-1]):
        failures.append("eventPayload must be built from eventJSON")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: LAN request uses Devices, POST, auth, saved event file, and iPhone identity")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
