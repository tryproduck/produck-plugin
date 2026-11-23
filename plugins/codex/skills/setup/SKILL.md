---
name: setup
description: Install or update Produck's local app and background service on this computer
---

Run exactly one shell command: on Windows, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <plugin directory>/bin/produck-bootstrap.ps1 --harness codex`; otherwise, `sh <plugin directory>/bin/produck-bootstrap --harness codex`. Append the person's arguments. The plugin directory is two levels above this skill's directory.

Report the command's output verbatim. If it fails, report the output and stop: do not retry it,
do not run its steps yourself and do not work around the failure.
