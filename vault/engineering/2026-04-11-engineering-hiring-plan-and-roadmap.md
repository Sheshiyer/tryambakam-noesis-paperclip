# Engineering Hiring Plan and Roadmap Decomposition

Date: 2026-04-11
Owner: CLAWD
Status: Active internal plan

## Purpose

Translate the existing founding-engineer narrative into an execution-grade engineering hiring plan tied to the actual product roadmap.

This plan assumes the current product direction remains:

- internal tool first
- Paperclip as the orchestration backend
- Huly as the human operations system of record
- local worktree as canonical execution environment
- small team, low-cost infrastructure, high leverage from agent support

## Hiring Principles

1. Hire for systems judgment before framework familiarity.
2. Keep the first team small enough that architecture decisions still happen in one room.
3. Delay specialist roles until there is clear recurring load, not speculative need.
4. Use agents and automation to absorb QA/reporting overhead before adding headcount there.
5. Tie every hire to a roadmap bottleneck that already exists.

## Current Gap

The company has candidate-facing narrative assets, but the engineering side was still missing:

- a role sequence
- hiring triggers
- interview stages
- 30/60/90 expectations
- explicit mapping from hires to roadmap phases

This document closes that gap.

## Recommended Hiring Sequence

### Hire 1: Founding Engineer, Decision Systems Platform

Timing: now

Why now:

- the product is still founder-shaped and needs a second technical decision-maker
- roadmap risk is execution clarity, not idea supply
- backend, client, and orchestration work are still too coupled to split cleanly

Core charter:

- stabilize the Paperclip-backed engineering spine
- turn current product direction into a shipping cadence
- define the first durable engineering rituals: tests, CI, release review, technical docs
- own implementation across backend, frontend, and integration boundaries until the next seat exists

Must-have signals:

- has shipped early-stage product systems with ambiguous requirements
- can move between product architecture and implementation details
- writes readable code and keeps scope tight
- can operate in a high-context environment without creating chaos
- treats testing and observability as default behavior

Anti-signals:

- requires a heavily pre-structured org to execute
- prefers narrow lane ownership only
- over-indexes on abstraction before the product loop is stable
- cannot explain tradeoffs in plain language

30/60/90 expectations:

- 30 days: absorb system architecture, own one complete shipping lane, add missing tests around a real workflow, and write down boundary decisions
- 60 days: reduce founder implementation dependency on one major workstream and establish weekly release discipline
- 90 days: co-own roadmap planning, unblock the spatial prototype path, and make the next hire specification obvious from actual constraints

Interview loop:

1. Founder conversation: motivation, category fit, ownership appetite
2. Engineering deep dive with CLAWD: architecture judgment, debugging, tradeoff clarity
3. Paid work sample: scoped implementation or architecture-to-code exercise with tests
4. Final calibration: collaboration style, ambiguity handling, writing quality

Decision owners:

- founder: final hire/no-hire, compensation, equity
- CLAWD: technical bar, work sample, 30/60/90 scope
- SAGE: candidate narrative consistency and outbound support

### Hire 2: Product Engineer, Spatial Client

Timing: after Hire 1 has stabilized the foundation and the spatial client becomes the pacing item

Trigger conditions:

- Paperclip auth/workspace flows are stable enough that frontend delivery is the main bottleneck
- the room/presence/orchestrator UX backlog is larger than one engineer can ship in parallel with backend work
- design-to-implementation handoff is waiting on engineering bandwidth, not product clarity

Core charter:

- own the spatial presence client
- implement room state, presence, and orchestrator-facing dashboards
- harden frontend performance and interaction quality
- partner with PIXEL on a coherent internal operator UX

Profile:

- strong product/frontend engineer
- comfortable with real-time state and collaboration surfaces
- willing to operate close to backend and integration seams

### Hire 3: Platform Engineer, Reliability and Runtime

Timing: only when delivery risk shifts from feature throughput to system reliability

Trigger conditions:

- two parallel engineering streams exist
- release reliability, CI time, observability, or runtime drift consumes more than 20 percent of engineering time
- local/remote workspace sync, auth, or automation reliability becomes a standing bottleneck

Core charter:

- own CI/CD, runtime consistency, observability, and developer workflow
- reduce friction in local and remote execution paths
- formalize deployment, rollback, and review gates

Profile:

- platform-minded but still pragmatic
- good at boring, durable systems
- prefers reliable toolchains over novelty

## Explicit Non-Hires For Now

### Dedicated QA hire

Do not hire first.

Reason:

- SENTINEL covers validation at the agent layer
- early leverage comes from better tests and release discipline, not a separate manual QA function
- a human QA specialist before core product velocity exists would add process before enough signal

### Data scientist / ML specialist

Do not hire first.

Reason:

- the immediate roadmap risk is product execution and orchestration reliability
- current differentiation depends more on system design and shipping quality than model novelty

## Roadmap Decomposition

## Phase A: Foundation and Control Plane Reliability

Window: weeks 0-6 after Hire 1 starts

Outcome:

- the core orchestration stack is stable enough to support rapid iteration

Scope:

- Paperclip auth and agent-loop reliability
- workspace and sync contracts
- baseline CI, test, and release workflow
- issue-backed memory and standup artifact flow
- core technical decision docs

Primary owner:

- Hire 1 with founder support

Exit criteria:

- one end-to-end internal workflow is tested and repeatable
- CI becomes a real merge gate
- the next highest-leverage frontend work is unblocked

## Phase B: Spatial Presence Prototype

Window: weeks 6-12

Outcome:

- internal users can enter rooms, see presence, and use the orchestrator surface

Scope:

- room grid and movement model
- presence state and status indicators
- initial orchestrator map
- personal layer shell
- audio transport spike with fallback behavior

Primary owner:

- Hire 1 initially, then Hire 2 once added

Exit criteria:

- internal dogfooding works for a small team
- presence and room state are reliable enough for daily use
- the UI backlog begins to outrun backend uncertainty

## Phase C: Automation and Operational Hardening

Window: weeks 12-20

Outcome:

- the product is usable as an internal operating layer without heroics

Scope:

- automated standup generation and publishing
- blocker and routing visibility
- observability, error reporting, and performance baselines
- release safety, rollback, and runtime consistency

Primary owner:

- Hire 1 and Hire 2, with Hire 3 added only if reliability work dominates the roadmap

Exit criteria:

- internal operations no longer depend on ad hoc debugging every cycle
- product quality can be measured, not guessed

## Phase D: Expansion and Team Surface Maturity

Window: after Phase C

Outcome:

- the system can support broader adoption and more parallel work

Scope:

- deeper orchestrator dashboards
- richer review queues and issue-backed artifacts
- improved Huly/Paperclip/GitHub bridging
- stronger role-based views and permissions

Hiring implication:

- only after this phase begins should Thoughtseed consider additional specialists

## Hiring-to-Roadmap Map

| Roadmap need | Earliest hire that unlocks it | Why |
|---|---|---|
| Stabilize control plane and shipping discipline | Hire 1 | Needs broad technical ownership |
| Ship spatial client fast enough to matter | Hire 2 | Frontend/product surface becomes the bottleneck |
| Make reliability work non-disruptive | Hire 3 | Platform burden becomes recurring and measurable |

## Immediate Actions

1. Use the existing narrative assets in `vault/content/` for warm outreach.
2. Use this document as the internal approval source for technical scope, interview loop, and sequencing.
3. Start with Hire 1 only. Do not open multiple engineering searches at once.
4. Reassess Hire 2 only after Phase A exit criteria are met.

## Definition of Done For This Workstream

This hiring-plan workstream is complete when:

- candidate-facing narrative stays in `vault/content/`
- engineering-side hiring and roadmap decisions live here in `vault/engineering/`
- the first hire is clearly defined, scoped, and sequenced against the roadmap
- later hires are trigger-based rather than speculative
