---
name: setup
description: Install or update Produck's local app and background service on this computer, and pair it with the person's dashboard when given a pairing code
argument-hint: "[pairing code]"
disable-model-invocation: true
---

On Windows use PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin directory>/bin/produck-bootstrap.ps1" --harness claude-code`; the plugin directory is two levels above this skill directory. Otherwise use Bash: `sh "${CLAUDE_PLUGIN_ROOT}/bin/produck-bootstrap" --harness claude-code`. The person's arguments are `$ARGUMENTS`: pass a pairing code (`XXXX-XXXX-XXXX`) as `--pair <code>` and append any other argument unchanged.

Report the command's output verbatim. If it fails, report the output and stop: do not retry it,
do not run its steps yourself and do not work around the failure.
