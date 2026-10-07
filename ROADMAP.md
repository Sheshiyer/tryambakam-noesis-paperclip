# Roadmap

Open work is tracked in GitHub issues. This file lists [epic #19](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/19) and its items in dependency order. Each item is a link. Issue bodies stay on the issues.

`tasks/todo.md` is a loop-cycle log, not this plan.

Tenant sync: direction pending ([#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6)).

OpenClaw is an ingest source only. Host guardrails are in [AGENTS.md](AGENTS.md).

Cost stays UNRESOLVED. Nothing here authorizes paid dispatch.

## Epic

[#19](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/19) — runtime health, tenant reconciliation, and OpenClaw ingest as host-agnostic modules.

## Dependency order

Items in one tier may run in parallel unless a bullet names an issue it waits on. A named dependency overrides the tier.

### Start now

- [#17](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/17) — this roadmap and the agent guide
- [#21](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/21) — can start now; live wiring stays in [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9)
- [#4](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/4) — existing item linked from the epic; not a sub-issue
- [#16](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/16)

### Hygiene

- [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6) — direction pending (#6). Blocks [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8), [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9), and [#15](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/15). Soft dependency for [#20](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/20).
- [#20](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/20) — after [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6), so a later sync does not bring the bindings back. Job-file bindings stay in [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8).
- [#7](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/7) — related to [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6). Before [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9), [#10](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/10), and [#14](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/14).
- [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8) — after [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6)

### Reliability

Epic sequence: retry and the delivery queue, then heartbeat and the state machine, then the watchdog.

- [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9) — after [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6), [#7](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/7), and the contract in [#21](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/21)
- [#10](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/10) — schema can follow [#21](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/21); live wiring after [#7](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/7) and [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9)
- [#14](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/14) — after [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8), [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9), [#7](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/7), and [#10](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/10)

### Ingest

Epic sequence after reliability: Telegram notify, Selemene prompt wiring, the bridger, the vikara detector, then the low-priority candidates.

- [#11](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/11) — after [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9) and [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8)
- [#15](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/15) — after [#6](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/6)
- [#12](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/12) — after [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9) and [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8)
- [#13](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/13) — after [#10](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/10)
- [#18](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/18) — after [#21](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/21) and [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9)

## Not in this list

- Antahkarana only reads outputs from this repo and never drives it. Its issues stay in that repository. The module contract is [Sheshiyer/antahkarana#134](https://github.com/Sheshiyer/antahkarana/issues/134).
- No Discord targets. Retired surfaces stay retired. Superseded OpenClaw pieces are not ingested.
