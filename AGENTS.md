# Agent guide

This is the agent guide for this repository. It applies to every host. A host-specific note such as [CLAUDE.md](CLAUDE.md) only points here.

## Public repository

This repository is public.

- No secrets, tokens, private paths, or personal data, including birth data.
- No machine-specific paths in commits, issues, or pull requests.
- Credentials come from the environment.
- Cron payloads are secret-scanned before commit. A scan reports names and match counts only and does not print values.
- No Discord targets.
- No paid dispatch without owner approval. Cost stays UNRESOLVED.
- Antahkarana only reads from this repo. It only reads outputs and never drives this repo.

## OpenClaw and modules

OpenClaw is not a runtime or dependency. It is an ingest source only.

Agent bindings are roles, not runtime ids. Reusable pieces are host-agnostic modules usable from Grok Bot, dots, Muse and Hermes. The contract is tracked in [Sheshiyer/antahkarana#134](https://github.com/Sheshiyer/antahkarana/issues/134).

## Where work lives

Open work and its order are in [ROADMAP.md](ROADMAP.md), by issue link. Items in one tier may run in parallel unless a bullet names an issue it waits on. `tasks/todo.md` is a loop-cycle log, not the plan.

Files under `agents/` are role notes for that role. They do not replace this guide.

`manifest.yaml` changes belong to [#20](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/20). `cron/jobs.json` changes belong to [#8](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/8). Do not edit either from unrelated work.
