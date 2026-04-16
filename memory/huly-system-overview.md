# Thoughtseed Integrated Huly System Design

> Operational reference for AI agents. Load this file to understand the Huly project management structure and conventions used across Thoughtseed.

---

## What is Huly

Huly is the project management platform Thoughtseed uses for all operations. Every task, sprint, standup, and client interaction flows through Huly. Agents operate WITHIN the Huly framework -- they create tasks using Huly conventions, track sprints, and generate standups according to the formats defined here.

---

## Module Map

| Module | Purpose | Key Use |
|---|---|---|
| **HR Beta** | Time tracking, people management | Leave, attendance, team roster |
| **Tracker** | Task and project management | Issues, sprints, boards, milestones |
| **Planner** | Personal time blocking | Individual day scheduling from task pool |
| **Team Planner** | Capacity and coordination | Cross-team workload visibility |
| **Chat** | Channel-based communication | Standups, client channels, blockers |
| **Trainings** | Onboarding and knowledge base | SOPs, tutorials, reference docs |
| **Cards** | Custom dashboards | Client overviews, PM dashboards, dev views |

---

## Agent-Huly Integration

Agents interact with Huly as follows:

- **Task creation**: Agents create tasks using the naming convention below
- **Sprint tracking**: Agents read sprint milestones to determine current work scope
- **Standup generation**: Agents produce daily standups from their TASKS.md and HEARTBEAT.md
- **Board updates**: Agents move tasks through board columns as work progresses
- **Blocker escalation**: Agents flag blockers which route through the escalation chain

---

## Enum Definitions

### project_type

```
Smart Home Integration
Energy Management
Web Development
Mobile App
R&D - Consciousness Tech
Creative/VR Experience
AI/ML Development
Internal Operations
```

### client_tier

| Tier | Description | Example |
|---|---|---|
| T1 - Recurring Revenue | Ongoing retainer clients | Axtech |
| T2 - Active Projects | Project-based engagements | Tuya Partners |
| T3 - Maintenance Mode | Low-touch, support only | Bezly, Vibrasonix |
| T4 - One-Off/Ad-hoc | Single deliverable | -- |
| TR&D - Innovation Lab | Internal R&D work | -- |

### task_complexity

| Level | Time Range | Description |
|---|---|---|
| Quick | <2h | Bug fix, minor tweak |
| Standard | 2-8h | Feature implementation |
| Complex | 1-3 days | Integration work |
| Epic | 3-7 days | Major feature |
| Mega | 1-4 weeks | Full system build |

### priority_level

| Priority | Meaning |
|---|---|
| P0 | Critical/Blocking (client down, deployment blocked) |
| P1 | High (this sprint, client deadline) |
| P2 | Medium (next sprint, important) |
| P3 | Low (backlog, nice-to-have) |
| P4 | Wishlist (future consideration) |

### work_status

```
Backlog | Scheduled | In Progress | Review | Done | Blocked | On Hold
```

### team_role

```
Founder/Director | PM-Developer | Senior Developer | Developer | Social Media Manager | Consultant
```

### smart_home_platform

```
Tuya IoT Platform | Axtech Energy System | Google Home | Amazon Alexa | Custom Integration
```

### meeting_type

```
Daily Standup | Sprint Planning | Sprint Retrospective | Client Call | Team Brainstorm | Training Session | 1-on-1 Sync
```

---

## Task Naming Convention

Format: `[PROJECT]-[TYPE]-[COMPONENT]-[ID]: Description`

### PROJECT Codes

| Code | Client | Notes |
|---|---|---|
| AXT | Axtech | -- |
| TUY | Tuya | Add client suffix: TUY-A, TUY-B |
| BZL | Bezly | -- |
| VBX | Vibrasonix | -- |
| OAS | OASIS R&D | -- |
| INT | Internal | -- |

### TYPE Codes

| Code | Meaning |
|---|---|
| FEAT | Feature |
| BUG | Bug Fix |
| TASK | General Task |
| DOC | Documentation |
| RESEARCH | R&D Investigation |
| SETUP | Infrastructure/Setup |

### Examples

```
AXT-FEAT-DASHBOARD-042: Add energy consumption graph
TUY-A-BUG-MQTT-015: Fix device disconnect on firmware update
INT-SETUP-CI-003: Configure GitHub Actions for monorepo
OAS-RESEARCH-EEG-007: Evaluate brainwave signal processing libraries
```

---

## Board View

### Columns (left to right)

```
Backlog → Scheduled → In Progress → Review/Testing → Done → Blocked
```

### Swim Lane Options

- **By Priority**: P0 at top, P4 at bottom
- **By Assignee**: One lane per team member/agent
- **By Component**: Frontend, Backend, IoT, DevOps, etc.
- **By Client**: One lane per active client

---

## Chat Channels

| Channel | Purpose |
|---|---|
| #general | Team-wide announcements |
| #standups | Daily standup posts |
| #axtech | Axtech client discussion |
| #tuya-clients | Tuya partner discussion |
| #research-rnd | R&D and innovation topics |
| #tech-resources | Tools, libraries, articles |
| #blockers-urgent | Immediate blocker escalation |
| #training-questions | Onboarding and learning |
