---
name: notebook
version: "1.0.0"
date: "2026-02-09"
description: >-
  Always-on repository memory workflow for agent sessions. Keep
  `.agents/notebook.md` current with a session index/counter and only
  high-signal, newest-first entries, using a fast startup path.
---

Maintain a per-repository operational memory file. This skill is mandatory every session.

Activation note: always active, no trigger required.

## Startup (Do First)

Do not start task work until this checklist is complete:

1. Resolve repository root.
2. Set notebook path to `.agents/notebook.md`.
3. If missing, create it from `Starter Template`.
4. Read context:
   - Always read `Top Rules`, `User Preferences`, and `Session Index`.
   - Read all `## Log` entries before starting task work.
   - Read the entire notebook when any `Full-Read Trigger` applies.
5. Run `Session Tracking` and update `Session Index`.
6. While working, log only qualifying events under `## Log` using `Entry Format`.
7. Run `Consolidation` when thresholds are hit.

## Starter Template

Use this exact template when creating `.agents/notebook.md`:

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
- Consolidate regularly to keep only high-signal guidance.

## Top Rules
- <high-signal rule>

## User Preferences
- <repeated user preference>

## Session Index
- session_count: 1
- session_ids (newest first):
  - <SESSION_ID>

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
- `session_ids` (newest first), one `current_session_id` per agent session since last consolidation

At startup:

1. Resolve `current_session_id` from the runtime session identifier variable (Codex: `CODEX_THREAD_ID`; others: equivalent variable).
2. If `Session Index` is missing, initialize:
   - `session_count: 1` and `session_ids: [current_session_id]` when id exists.
   - `session_count: 0` and empty `session_ids` when id is unavailable.
3. If id exists and first `session_ids` entry differs, prepend id.
4. If id is unavailable, do not append anything.
5. Set `session_count` to `len(session_ids)`.
6. Do not emit a `session-start` log entry for this bookkeeping.

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

Trigger consolidation when either condition is true:

- Notebook has 400 lines or more.
- `session_count >= 5`.

During consolidation:

1. Merge repeated lessons into `Top Rules`.
2. Promote repeated user guidance into `User Preferences`.
3. Remove redundant, low-signal, or superseded entries already captured above.
5. Keep `## Log` newest first.
6. Keep notebook under 200 lines after consolidation.
7. Reset `Session Index` to current session only (`session_ids` has one current id when available) and set `session_count` accordingly.

## Practical Defaults

- Do notebook create/read steps sequentially, not in parallel.
- Quote multi-word shell search patterns.
- Check for duplicate lessons before adding a new log entry.
