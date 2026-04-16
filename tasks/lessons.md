# Lessons

## 2026-03-24

- When the user says an interview is "for you to get to know my needs better," do not frame it as an internal agent/company intake workflow. Build the artifact as a founder discovery interview first, then translate answers into system configuration second.
- For Thoughtseed work, treat older website and brand material as background context only. Do not present it as current truth unless the user explicitly confirms it.
- When the user says to ignore the current website direction, stop optimizing around the live site's IA, CTA, or portfolio framing. Use the site only as diagnostic context and pivot to the explicitly requested target experience.
- For the current Thoughtseed implementation pass, keep consciousness and mystical framing out of the execution flow unless the user reintroduces it. Anchor the novel positioning on the Krebs Cycle and orchestration model instead.
- Do not force a commercial offer frame onto an implementation the user explicitly defines as internal tooling. Mark the commercialization question as not applicable for that flow and continue the interview in the correct operating context.
- When the user asks for interactive multiple-choice style discovery, stop using long-form interview wording. Ask one constrained decision prompt at a time with a small set of selectable directions, then refine from the chosen option.
- When the user tells you to stop the question flow, stop immediately and switch to a synthesis/memory-check response that states the current understanding, assumptions, and open gaps without continuing discovery prompts.
- When the user says the system should move beyond CXO silos, do not keep visible `CEO` naming in the implemented org just because the underlying product role enum still uses `ceo`. Rename the user-facing top node to the orchestration-specific label and note the internal mapping separately.

## 2026-04-03

- When working on Thoughtseed spatial ops, do not collapse the shared spatial layer into a Paperclip-hosted local dev artifact if the intended model is a live team space with per-user local Paperclip instances feeding it. Verify the deployment boundary explicitly before freezing contracts or wiring bootstrap flows.

## 2026-04-09 — Full reinstall notes

- Paperclip install layout: runtime lives at `~/.paperclip/instances/default/` (embedded postgres 17 at `db/`, secrets in `secrets/master.key`, company data under `companies/<id>/`, each with its own `codex-home/`). The git checkout at `ts-paperclip/paperclip/` was a dev source tree — NOT required when using the published `paperclipai` CLI.
- `paperclipai onboard -y` runs the full quickstart non-interactively: creates the instance, starts the embedded postgres + server on :3100, seeds a stock company (name derived from env — landed on "Thoughtseed Labs" this time with prefix `THO`), plus CEO/CTO agents and an Onboarding project. The command does NOT return — it stays attached as the running server, so launch it in the background.
- CLI has `company export` and `company import` producing portable markdown packages. Next time, export BEFORE scrubbing instead of hand-crafting API payloads from JSON snapshots.
- `company delete <selector>` supports deleting by ID or prefix — useful for pruning the BrahmaSthanam-style archived orgs.
- `agent local-cli <agentRef>` creates an API key, installs local Paperclip skills for Codex/Claude, and prints shell exports — use this to wire each agent's Codex CLI session to Paperclip.
- `paperclipai doctor` flags port :3100 as a warning when the server is already running from the same CLI — not an error.
- The embedded postgres binaries (`pg_ctl` only) do NOT ship `pg_dump`. For ad-hoc dumps use `paperclipai db:backup` which does the pg_dump internally via the `@paperclipai/db` package.
- macOS LibreSSL does not support `openssl genpkey -algorithm ed25519`. Use `node -e "…generateKeyPairSync('ed25519')…"` instead.
- POST `/api/companies/<cid>/agents` accepts the GET shape minus `id`, `companyId`, `status`, `createdAt`, `updatedAt`, `lastHeartbeatAt`, `urlKey`, `budget*`, `spent*`, `pause*`, `metadata`. `reportsTo` needs new ids — create parents before children.
- Agents with `role: "ceo"` or with `permissions.canCreateAgents: true` bypass `requireBoardApprovalForNewAgents` and come up in `idle` status directly.
- The 2 OpenClaw gateway agents (OpenClaw, Noesis Vishwakarma) point at `ws://127.0.0.1:18789/` — until an OpenClaw gateway is actually running there with a matching token, these agents cannot heartbeat. New token + ed25519 private key stored at `_archive-2026-04-09/openclaw-new-secrets.txt`; user must pair them with the gateway when it comes online.

## 2026-04-09 — Fresh install state

- **Instance**: `~/.paperclip/instances/default/`, paperclipai v2026.403.0
- **Org**: Thoughtseed Labs (ID `d89420ba-ce5a-45f6-bd0a-e735d2e02740`), prefix `THO`, `requireBoardApprovalForNewAgents: true`
- **Agents (15 total)**:
  - Seeded by onboard: CEO (idle), CTO (pending_approval)
  - Rebuilt from archive: JARVIS (root, Chief Strategy Officer), OpenClaw, Noesis Vishwakarma, PIXEL (→NOVA/VIBE/CLIP), ATLAS (→TRENDY), CLAWD (→SENTINEL), SAGE (→SCRIBE)
- **Projects**: Onboarding (seeded). Old 11 projects intentionally not recreated per user decision; archive at `_archive-2026-04-09/api-snapshot/projects-tryambakam.json` if you want to add them back.
- **Agent cwd**: all 12 codex_local agents point at `/Users/sheshnarayaniyer/thoughtseed-labs` (seeded from the archived `tryambakam-noesis-paperclip` tarball — minus node_modules). Noesis Vishwakarma still points at `~/.openclaw/workspace-noesis-vishwakarma`.
- **Archive root**: `_archive-2026-04-09/` (381 MB) — `MANIFEST.md` is the index. Safe to move out of the vault whenever.
- **Next steps for the user**:
  1. Open `http://127.0.0.1:3100` — sign in as CEO via onboarding flow (first-run auth wizard in the UI).
  2. Decide fate of the onboard-seeded CTO (pending_approval) — either approve or delete it.
  3. When OpenClaw gateway is up, regenerate gateway token + device key on the gateway side and PATCH the 2 openclaw_gateway agents (or delete + recreate).
  4. For each agent, run `paperclipai agent local-cli <agentRef>` to get its API key + install Codex/Claude skill glue.
  5. Recreate projects from the archive as needed via UI or API.
