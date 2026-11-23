---
name: create-journey
description: Ask to review and save the workflow just finished as a reusable Produck automation
argument-hint: "[what the automation is for]"
disable-model-invocation: true
allowed-tools: mcp__produck__produck_create_journey, request_user_input, mcp__produck__produck_review_journey
---

Call `mcp__produck__produck_create_journey` once to nominate the task this session most recently
worked on. The steps come from what Produck captured, so do not restate them. Nomination does not
approve or save the workflow.

Write `intent` as one imperative sentence that reads correctly after "Use when you need to": the
goal, the kind of input it starts from and the result it leaves, general enough that someone with
different inputs recognises their own task. Leave out names, URLs, ids, paths, dates and amounts
from this run. If a description follows, base the intent on it: $ARGUMENTS

The call waits for the judge and can take several minutes. Do not call it again
while it runs.

When it returns `awaitingReview`, follow its `instruction`: ask the person the exact question,
including the task identifier, with Save and Don't save options through `request_user_input`. Wait for their answer. Only then call
`mcp__produck__produck_review_journey` with that `taskId` and their decision. Do not prefill an
answer. Without an answer, leave the task awaiting review and do not call review or save.

Report a save only after the review call succeeds, or if nomination returns an already saved
journey. If the person declines, report that it was not saved. Never claim nomination saved a skill.

If it fails, report the reason it gives and stop; do not retry and do not save anything by other
means. Two reasons need a next step from me:

- "sensitive content or fewer than three tool calls": this task cannot be saved.
- "No captured call of produck_create_journey matches this nomination" or a connection error:
  Produck is not capturing this session; suggest running `produck doctor`.
