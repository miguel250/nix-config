---
name: notebook
description: >-
  Mandatory repository memory workflow for every agent session. Read and maintain
  the per-repository cache notebook, track unique sessions, and consolidate at
  startup and before handoff when it reaches 400 lines or 5 sessions.
metadata:
  version: "2.1.0"
  date: "2026-10-31"
---

Maintain a per-repository operational memory file. This skill is mandatory every session.

Activation note: always active, no trigger required. Run `Startup (Do First)` once at the start of each session before doing any work, then re-read `notebook.md` immediately before any file edit.

Consolidation is part of completing the task, not an optional follow-up. If due at startup, finish it before repository work. If due later, finish it before handoff. A short or read-only task does not exempt notebook maintenance. Higher-priority restrictions still apply; report a blocked notebook write rather than claiming cleanup succeeded.

## Startup (Do First)

Do not start task work until this checklist is complete:

1. Resolve repository root with `git rev-parse --show-toplevel` (fallback to the working directory outside Git).
2. From that root, resolve repository name with `basename -s .git "$(git remote get-url origin)"` (fallback to repo directory name if origin is missing).
3. Set `notebook_path` to `${XDG_CACHE_HOME:-$HOME/.cache}/agents/{repository_name}/notebook.md`. Use this same path for every read, write, and check.
4. If the notebook is missing, create it from `Starter Template`.
5. Read the entire notebook, including any additional sections. Measure its line count and inspect `session_count`; remember if either consolidation threshold is already met.
6. Run `Session Tracking`, then check the thresholds again. The session that brings the count to 5 triggers consolidation now, not next session.
7. If either check found consolidation due, complete `Consolidation` and verify its postconditions before starting repository work. Correcting a stale counter does not cancel an already-due cleanup.

While working, log only qualifying events using `Entry Format`. After every notebook write, check the thresholds again. Before every final response, run `Handoff Check`, even if no log entry was added.

## Starter Template

Create the notebook at `notebook_path` with this template, then run `Session Tracking`. Leave sections empty until there is real guidance to record; do not insert placeholder rules or session IDs.

```markdown
# Notebook

## Purpose
Track mistakes, failed attempts, user corrections, and what actually worked in this repository.

## Working Agreements
- Read this file before starting work.
- Add entries continuously while working.
- Insert each new log entry under `## Log` so newest entries stay first.
- Log your own mistakes, not only user corrections.
- Keep entries factual and short.
- Check consolidation at startup, after notebook writes, and before handoff.
- Consolidate at 400 lines or 5 sessions; reset the index only with a verified, condensed notebook under 200 lines.

## Top Rules

## User Preferences

## Session Index
- session_count: 0
- session_ids (newest first):

## Log
```

## Session Tracking

Session contract:

- `current_session_id` is the stable identifier for the active chat/thread session.
- In Codex, use `CODEX_THREAD_ID`.
- In non-Codex agents, use that runtime's equivalent conversation/thread/session id variable.
- The value must stay the same within one session and change when a new session starts.

`Session Index` is mandatory and stores:

- `session_count`
- `session_ids` (newest first), unique session IDs retained since last consolidation

At startup:

1. Resolve `current_session_id` from the runtime session identifier variable (Codex: `CODEX_THREAD_ID`; others: equivalent variable).
2. If `Session Index` is missing, initialize `session_count: 0` and empty `session_ids` without changing other sections.
3. Deduplicate existing IDs, preserving their order. Prepend the current ID only if it is absent from the entire list. Resuming a session or sharing its ID with a subagent does not create another session.
4. If id is unavailable, do not invent an ID or clear existing IDs. The line-count trigger still applies.
5. Set `session_count` to the number of unique IDs. Retain other sessions until consolidation succeeds; do not reset the index merely because a new session started.
6. Do not emit a `session-start` log entry for this bookkeeping. Check `Consolidation` immediately after updating the index.

## What to Log

Allowed event types: `mistake`, `failed-attempt`, `user-correction`, `working-pattern`, `consolidation`.

- `mistake`: your assumption, implementation, or command was wrong.
- `failed-attempt`: approach failed or only partially worked.
- `user-correction`: anything the user told you to do differently.
- `working-pattern`: non-obvious, high-signal pattern that should be reused.
- `consolidation`: notebook cleanup was executed.

Before writing any entry, all three must be true:

1. Novel: not already captured in `Top Rules`, `User Preferences`, or a newer log entry.
2. Concrete: tied to a specific command, diff, failure, or decision in this repository.
3. Actionable: changes what you will do differently next time.

If any check fails, skip the entry.

- Keep `## Log` in strict descending chronological order.
- Do not log `session-start`.
- Log only events that would change future behavior or save time on similar tasks.
- For `working-pattern`, skip obvious wins. If a competent engineer would expect it, do not log it.
- If no qualifying event occurred, do not force an entry.
- Do not log duplicates already captured in `Top Rules`, `User Preferences`, or a newer log entry.
- Do not log generic writing/process advice unless tied to a concrete failure in this repo.
- Do not log user corrections that only restate an existing rule without new constraints.
- Do not delete failures to hide them. Remove old entries only during consolidation after promoting the lesson.

## Entry Format

Use this format for every log entry:

```markdown
### <ISO-8601 timestamp> | <event-type>
- Context: <what you were trying to do>
- Observation: <what happened>
- Action: <what you changed next>
- Outcome: <worked, failed, partial>
- Follow-up: <how to avoid or repeat this>
```

## Consolidation

At each checkpoint, measure the saved notebook rather than estimating its size. For a newline-terminated Markdown file, `wc -l < "$notebook_path"` provides the line count. Trigger consolidation when either condition is true:

- Notebook has 400 lines or more.
- `session_count >= 5`.

During consolidation:

1. Re-read the complete notebook immediately before editing. Consolidation is semantic cleanup, not truncation, moving the backlog to another file, or resetting a counter.
2. Merge reusable lessons into `Top Rules` and durable user guidance into `User Preferences`. A valuable one-off failure can supply a rule; repetition is not required. Preserve constraints, unresolved failures, and uncertainty instead of turning an unverified guess into a fact.
3. Remove redundant, low-signal, or superseded log entries after preserving any actionable lesson. Keep unique, still-useful context in concise entries. Leave `## Log` newest first and preserve required sections.
4. Prepare the complete condensed draft, including a `Session Index` reset to the current session only (one ID when available, otherwise none; `session_count` 1 or 0 accordingly). Verify the draft has fewer than 200 lines and still contains the durable lessons. If not, continue semantic cleanup; do not discard unique guidance just to meet the size target. If the target cannot be met without losing necessary context, report the blocker and leave the saved session index unreset.
5. Save the verified draft with the cleanup and index reset together, then re-read the saved file. Verify its final line count, lessons, and session index before declaring success. If the source changed while preparing the draft, reconcile it before saving. Never save an index-only reset instead of reviewing and consolidating the content.

## Handoff Check

Before the final response:

1. Re-read the saved notebook and measure its line count. Verify `session_count` matches the unique IDs and that the current ID is present when available.
2. If either threshold is met, complete `Consolidation` now. Do not defer it to a later session or merely recommend it in the response.
3. If consolidation ran, briefly report the measured before/after line counts and final session count. If notebook maintenance was blocked by permissions, conflicting instructions, or concurrent edits, state the incomplete step. Do not claim success without inspecting the saved file.

## Practical Defaults

- Do notebook create/read steps sequentially, not in parallel.
- Start every session by running `Startup (Do First)` and reading the required notebook sections before doing repository work.
- Multiple agents may write the notebook at the same time. Re-read `notebook.md` immediately before editing and keep writes minimal. If it changed since the read used to prepare an edit, reload and reconcile it instead of overwriting newer lessons or session IDs. Re-read after writing to verify the result.
- Quote multi-word shell search patterns.
- Check for duplicate lessons before adding a new log entry.
