# Sprint Management Workflow

> Operational reference for AI agents. Load this file to understand sprint structure, ceremonies, and velocity tracking.

---

## Sprint Class Schema

```yaml
Sprint:
  sprint_name: text               # e.g., "Axtech Sprint 12"
  project: relation → Project
  start_date: date
  end_date: date
  sprint_goal: text
  planned_capacity: number        # Total hours available
  actual_capacity: number         # Auto-calculated from time entries
  completion_percentage: number
  retrospective_notes: rich text
  status: enum                    # Planning | Active | Completed | Cancelled
```

---

## Sprint Cadence

- **Duration**: 2 weeks (Monday to Friday x 2)
- **Days**: 10 working days per sprint
- **Overlap**: None -- sprints run back-to-back

---

## Sprint Ceremonies

### 1. Sprint Planning (Monday 10:00 AM, Sprint Day 1)

| Step | Action | Details |
|---|---|---|
| 1 | Review backlog | Filter: Status=Backlog, Priority=P0/P1 |
| 2 | Discuss and estimate | Assign complexity level to each candidate task |
| 3 | Select sprint tasks | Drag selected tasks to sprint milestone |
| 4 | Assign work | Balance hours across team members |
| 5 | Schedule Week 1 | Each person schedules tasks in personal Planner |

### 2. Daily Standups (Every workday, 6:00 PM IST)

- See `memory/standup-process.md` for full specification

### 3. Sprint Demo (Last Friday of sprint, if applicable)

- Demo completed work to client
- Collect feedback, create follow-up tasks

### 4. Sprint Retrospective (Last Friday of sprint, after demo)

| Section | Questions |
|---|---|
| What went well | Processes, tools, collaboration wins |
| What didn't go well | Blockers, miscommunications, scope creep |
| Action items | Concrete changes for next sprint |

After retrospective: mark sprint **Completed**, begin planning next sprint.

---

## Capacity Calculation

```
team_size x 8h/day x 10 days - time_off_hours = available_capacity
```

### Example

```
Team: 4 people
Time off: 1 person out 2 days = 16h
Available: (4 x 8 x 10) - 16 = 304h
Target (90%): 304 x 0.9 = 273.6h plannable
Buffer (10%): 30.4h for ad-hoc, context switching
```

### Utilization Target

- **90%** of available capacity should be planned
- **10%** buffer reserved for unplanned work, meetings, context switching

---

## During Sprint Execution

| Activity | Frequency | Owner |
|---|---|---|
| Track burndown | Daily | PM |
| Review standup blockers | Daily | PM |
| Adjust scope if falling behind | As needed | PM + Team |
| Mid-sprint check-in | Wednesday of Week 1 | PM |
| Escalate stalled P0/P1 items | Immediately | PM |

### Scope Adjustment Rules

- If burndown shows >20% behind by mid-sprint: remove lowest-priority items
- Removed items return to Backlog with note: "Descoped from Sprint N"
- Never add scope mid-sprint without removing equal or greater effort

---

## End of Sprint

1. Run sprint demo (client-facing projects)
2. Conduct retrospective
3. Mark sprint status: **Completed**
4. Record retrospective_notes in Sprint record
5. Move incomplete tasks to next sprint or back to Backlog
6. Plan next sprint

---

## Velocity Tracking

```
Sprint velocity = completed_hours / planned_hours x 100
```

| Velocity | Interpretation |
|---|---|
| >95% | Excellent -- may be underestimating |
| 80-95% | Healthy range |
| 60-80% | Investigate blockers, scope creep |
| <60% | Sprint was disrupted -- review in retro |

Track velocity across sprints to improve estimation accuracy over time.
