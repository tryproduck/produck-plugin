---
name: setup
description: Install or update Produck's local app and background service on this computer
argument-hint: "[--judge-url URL --install-key KEY]"
disable-model-invocation: true
---

On Windows use PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin directory>/bin/produck-bootstrap.ps1" --harness claude-code $ARGUMENTS`; the plugin directory is two levels above this skill directory. Otherwise use Bash: `sh "${CLAUDE_PLUGIN_ROOT}/bin/produck-bootstrap" --harness claude-code $ARGUMENTS`.

Report the command's output verbatim. If it fails, report the output and stop: do not retry it,
do not run its steps yourself and do not work around the failure.
