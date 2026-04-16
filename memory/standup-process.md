# Daily Standup Process

> Operational reference for AI agents. Load this file to generate standups, understand reporting format, and follow escalation rules.

---

## Timing

- **When**: 6:00 PM IST (12:30 UTC), end of day
- **Days**: Monday through Friday
- **Deadline**: All standups posted by 6:30 PM IST

---

## Who Reports

- Every human team member
- Every active agent

---

## Standup Template

```markdown
---
Standup - [Name] - [YYYY-MM-DD]

Completed:
- @[TASK-ID]: [Description] ([hours])
- @[TASK-ID]: [Description] ([hours])

Tomorrow (Scheduled in Planner):
- @[TASK-ID]: [Description] ([estimated hours])
- @[TASK-ID]: [Description] ([estimated hours])

Blockers:
- None / [Describe blocker + link to blocker task]

Total Today: [X]h
Tomorrow Planned: [X]h
---
```

### Example

```markdown
---
Standup - CODEX - 2026-04-11

Completed:
- @AXT-FEAT-DASHBOARD-042: Implemented energy graph component (3h)
- @INT-TASK-CI-009: Fixed flaky test in deploy pipeline (1.5h)

Tomorrow (Scheduled in Planner):
- @AXT-FEAT-DASHBOARD-043: Add date range filter to graph (4h)
- @AXT-BUG-API-018: Debug intermittent timeout on device sync (2h)

Blockers:
- None

Total Today: 4.5h
Tomorrow Planned: 6h
---
```

---

## Agent Standup Generation

Agents build their standup by reading these sources:

| Source | Maps To | Logic |
|---|---|---|
| TASKS.md items marked "done" today | Completed | Filter by today's date, status=done |
| TASKS.md items "open" or "in-progress" | Tomorrow | Next scheduled items by priority |
| TASKS.md items marked "blocked" | Blockers | Include blocker description + linked task |
| HEARTBEAT.md | Metrics | Today's cycle count, duration, outcomes |

---

## Output Location

Each standup is written to:

```
vault/standups/YYYY-MM-DD/{agent-name}.md
```

Example: `vault/standups/2026-04-11/codex.md`

---

## JARVIS Aggregation

After all standups are posted, JARVIS performs:

1. Read all files in `vault/standups/YYYY-MM-DD/*.md`
2. Generate org-wide summary containing:
   - Total work hours across all reporters
   - Blocked items needing attention
   - Cross-department dependencies
3. Write to `vault/standups/YYYY-MM-DD/org-summary.md`
4. Escalate any unresolved blockers older than 24 hours

---

## PM Review (Next Morning)

| Step | Action |
|---|---|
| 1 | Read org summary |
| 2 | Check Team Planner for today's capacity |
| 3 | Verify no one is over/under allocated |
| 4 | Clear blockers mentioned in standups |
| 5 | Rebalance tasks if needed |

---

## Escalation Rules

| Condition | Action |
|---|---|
| Blocker mentioned in standup | Auto-create blocker task if none exists |
| Same blocker in 2 consecutive standups | Escalate to department lead |
| Same blocker in 3 consecutive standups | Escalate to JARVIS |
| P0 blocker at any point | Immediate escalation to JARVIS + owner notification |

### Escalation Flow

```
Standup mention → Blocker task created (if missing)
  → Day 2 same blocker → Department lead notified
    → Day 3 same blocker → JARVIS takes over resolution
```

---

## Standup Compliance

### Monitoring

SENTINEL monitors standup compliance:

- **Check time**: 6:30 PM IST daily
- **Check**: Did all active agents post a standup?

### Consequences

| Condition | Action |
|---|---|
| Missing standup by 6:30 PM IST | Flagged in org-summary |
| 3 consecutive missed standups | Escalation to JARVIS |
