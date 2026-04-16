# TWC Vault Integration Contract

## Purpose

This file mirrors the vault-side Paperclip contract so the control plane and the vault keep the same boundary.

Paperclip at `/Users/sheshnarayaniyer/tryambakam-noesis-paperclip/` is the control plane.
`/Volumes/madara/2026/twc-vault` is the knowledge and transformation plane.

## What Paperclip Reads From the Vault

Read these as the primary coordination surfaces:
- `_System/memory/archetypal-candidates/latest-run.json`
- `_System/memory/archetypal-candidates/runs/<run-id>/paperclip-handoff.json`
- `_System/memory/archetypal-candidates/runs/<run-id>/openclaw-handoff.json`
- `_System/memory/archetypal-candidates/paperclip-sync-state.json`
- `_System/memory/archetypal-candidates/runs/<run-id>/candidates/<candidate-id>.yaml`
- `01-Projects/Content-Engine/_inbox/meru-candidates/`
- `01-Projects/Content-Engine/daily-status.md`
- `01-Projects/Content-Engine/editorial/meru-candidate-seeds.yaml`
- `docs/reference/paperclip-vault-integration-contract.md`
- `docs/reference/meru-archetypal-content-pipeline.md`

Do not use these as routine Paperclip inputs:
- raw FAISS / embedding artifacts
- arbitrary full-vault scans
- raw `.claude/skills/` source on every heartbeat

## Persistent Sync Rules

- One candidate evidence surface must map to one stable `sync_key`.
- One `sync_key` must have one active Paperclip assignment.
- `candidate_id` is useful for same-run duplicate detection but is not enough for cross-run dedupe because it is run-scoped.
- If the same `sync_key` reappears in a later run, update bridge memory and skip duplicate task creation.
- If the same `sync_key` appears to want a different Paperclip lane, treat that as an assignment conflict and escalate instead of forking work.

## Agent Routing

- `atlas`: taxonomy drift, synthesis-note, structural ambiguity
- `scribe`: source-lattice-brief, content-brief
- `sage`: triage_candidate and queue sense-making
- `clawd`: moc-linking, routing-only, mapping maintenance
- `sentinel`: realization audit and regression review
- `jarvis`: cross-lane conflicts, missing-owner cases, priority arbitration

## Handoff Chain

1. `para-ingest-applet` captures raw material into `processing/`.
2. Meru stages candidate packets and handoff manifests.
3. `.claude/skills` classify, synthesize, and route in vault terms.
4. OpenClaw executes deterministic realization / MOC maintenance.
5. Paperclip assigns ownership, tracks blocked work, and escalates conflicts.
6. Content Engine moves approved winners through editorial processing.

## Non-Overlap Rule

Paperclip should store pointers, status, sync identity, and ownership.
Paperclip should not become a second PARA taxonomy, a second Meru, or a second realization engine.

