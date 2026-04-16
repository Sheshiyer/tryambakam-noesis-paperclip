# Team Planner & Capacity Management

> Operational reference for AI agents. Load this file to understand capacity calculations, planner usage, dashboard views, and workload red flags.

---

## Personal Planner

Each team member and agent has a personal Planner in Huly.

| Setting | Value |
|---|---|
| Default view | Week (Mon-Fri) |
| Block size | 1-2 hour blocks |
| Daily target | 8 hours productive work |
| Source | Tasks assigned in Tracker |

### Morning Routine

1. Open Planner
2. Review pre-scheduled tasks for the day
3. Drag additional tasks from Unplanned queue if capacity allows
4. Schedule the full day in time blocks

---

## Capacity Calculations

### Per Person

```
Weekly:   40h  (5 days x 8h)
Monthly: 160h  (4 weeks x 40h)
```

### Team Level

```
Team weekly:     40h x team_size
Sprint capacity: team_weekly x 2 - time_off_hours
```

### Target Utilization

```
Plannable:  90% of available capacity
Buffer:     10% for ad-hoc work, context switching, meetings
```

### Calculation Example

```
Team size: 5
Time off this sprint: 2 person-days (16h)
Sprint capacity: (5 x 40 x 2) - 16 = 384h
Plannable: 384 x 0.9 = 345.6h
Buffer: 384 x 0.1 = 38.4h
```

---

## Red Flags

PM should investigate immediately when any of these conditions appear:

| Red Flag | Possible Cause |
|---|---|
| Anyone > 10h in a single day | Overwork, incorrect time tracking |
| Anyone < 4h scheduled | Unmarked time off, task assignment gap |
| P0 task unscheduled | Critical work not being addressed |
| Sprint milestone due, tasks not scheduled | Planning breakdown |
| Same task scheduled > 3 days without progress | Blocked or stuck, needs intervention |

---

## PM Dashboard Views (Cards Module)

### Dashboard 1: Critical Issues Across All Projects

- Filter: Priority = P0 or P1
- Group by: Client
- Shows: Task name, assignee, days in current status

### Dashboard 2: Team Capacity This Week

- Metric: Hours scheduled / hours available per person
- Color coding:
  - Green: 70-90% utilized
  - Yellow: 50-70% or 90-100%
  - Red: <50% or >100%

### Dashboard 3: Revenue Projects Status

- Filter: Client tier = T1 or T2
- Shows: Sprint progress bar per project, completion %, next milestone

### Dashboard 4: Blocked Tasks Requiring Attention

- Filter: Status = Blocked
- Shows: Task, how long blocked, assigned to whom, blocker description

### Dashboard 5: This Week's Completed Work

- Filter: Status changed to Done this week
- Shows: Task, assignee, hours spent, client
- Purpose: Team morale and weekly reporting

---

## Developer Dashboard Views (Cards Module)

### Dashboard 1: My Active Work

- Filter: Assigned to me, Status != Done
- Group by: Priority
- Shows: Task ID, description, sprint, due date

### Dashboard 2: My Planner This Week

- Visual: Calendar view of scheduled time blocks
- Shows: Task blocks with colors by project

### Dashboard 3: Related Knowledge

- Source: Trainings module articles linked to current tasks
- Shows: Article title, relevance tag, last updated

### Dashboard 4: Code Reviews Needed

- Filter: PRs awaiting my review
- Shows: PR title, repo, author, age
