# OpenClaw Integration Map

## Architecture Overview

Thoughtseed Labs operates a three-layer system:

```
┌─ Paperclip (Control Plane) ─────────────────────────────────────────┐
│ http://127.0.0.1:3100 | Company: Thoughtseed Labs (d89420ba...)     │
│ 15 agents registered | Issue tracker (THO-xxx) | Skills API         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌─ ts-paperclip (Orchestration Runtime) ──────────────────────────────┐
│ /Volumes/madara/2026/twc-vault/01-Projects/thoughtseed/ts-paperclip │
│ manifest.yaml | agents/ | scripts/ | workflows/ | memory/ | vault/  │
│ cron/jobs.json (18 scheduled jobs from samsclawra)                  │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌─ OpenClaw Gateway (Agent Runtime) ──────────────────────────────────┐
│ ws://127.0.0.1:18789 | Token: <redacted: OpenClaw gateway token, see local config> | Mode: local/loopback   │
│ Config: ~/.openclaw/openclaw.json                                    │
│ Cron runs: ~/.openclaw/cron/runs/*.jsonl                            │
│ Agent workspaces: ~/.openclaw/workspace-{agent}/                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Connected Systems

| System | Location | Port | Purpose |
|---|---|---|---|
| **Paperclip** | `~/.paperclip/instances/default/` | 3100 | Control plane, agent registry, issues |
| **OpenClaw Gateway** | `~/.openclaw/` | 18789 | Agent runtime, cron execution, session mgmt |
| **Brahman Darshanam** | `~/.openclaw/ANNAMAYA/brahman-darshanam-tauri/` | 5199 | Desktop dashboard (Tauri) |
| **Control Center** | `~/.openclaw/ANNAMAYA/openorca-control-center/` | 5199 | Fleet control UI |
| **Selemene Engine** | `selemene.tryambakam.space` | 443 | Vedic timing API (Tithi, Panchanga) |
| **samsclawra** | `/Volumes/madara/.../samsclawra/` | — | Source-of-truth monorepo (16 agents, schemas) |

## Agent Mapping: Paperclip ↔ OpenClaw ↔ Samsclawra

| Paperclip Agent | OpenClaw Agent | Samsclawra Role | Adapter |
|---|---|---|---|
| JARVIS | sadhana-orchestrator | Strategic orchestrator | codex_local |
| OpenClaw | openclaw (gateway) | Gateway bridge | openclaw_gateway |
| Noesis Vishwakarma | noesis-vishwakarma | Nexus Architect (primary orchestrator) | openclaw_gateway |
| ATLAS | pi | Explorer, research, analysis | codex_local |
| SAGE | chitta-weaver | Memory weaver, context management | codex_local |
| PIXEL | nadi-mapper | Connection router, topology | codex_local |
| CLAWD | noesis-vishwakarma | Code execution (shared with Noesis V.) | codex_local |
| SENTINEL | kosha-regulator | Balance monitor, health checks | codex_local |
| SCRIBE | — | Content director (Paperclip-native) | codex_local |
| TRENDY | bird-observer | Social sentinel, trend detection | codex_local |
| NOVA | — | Video production (Paperclip-native) | codex_local |
| VIBE | — | Motion design (Paperclip-native) | codex_local |
| CLIP | — | Short-form optimization (Paperclip-native) | codex_local |

## Cron Jobs (18 Active — from samsclawra)

All jobs assigned to `noesis-vishwakarma`. Stored at `cron/jobs.json`.

### Interval-Based (Real-time)
| Job | Interval | Purpose |
|---|---|---|
| Sankalpa Listener | 13m | Read Discord #sankalpa-orders, route commands |
| Samskara Hunter | 2.1h | Fetch Discord #tattva-stream, extract URLs |
| Satsang Council Listener | 5m | Poll Discord for community feedback |
| Swarm Check-Agents | 15m | Agent health loop |
| Strategic Pressure Audit | 6h | Proactive audit |
| Dashboard Feed Sync | 15m | Sync to brahman-darshanam dashboard |
| Orchestration Worker Run Loop | 2m | Continuous cron job executor |
| Init Audio Courier (TG) | 5m | Telegram voice → text → routing |

### Daily (Cron, Asia/Kolkata)
| Job | Time (IST) | Purpose |
|---|---|---|
| Meru Nightly Vault Build | 1:00 AM | Index full 54GB vault |
| Chitta-Weaver Heartbeat | 2:00 AM | Memory health, skills verification |
| Ritual Preparation | 3:00 AM | Vault scan, GitHub activity, theme synthesis |
| Prana-Sadhana Heartbeat | 10:00 AM | Cron audit, metabolic check, Selemene moon phase |
| Ritual Integration | 11:30 PM | Archive daily logs, extract patterns |
| Lunar Resonance Orchestrator | Midnight | Tithi calculation, lunar themes |
| Full Moon Octave Jump | 12:30 AM | Purnima check, breath work, Discord post |
| New Moon Rupture Audit | 12:30 AM | Amavasya check, karmic release, Discord post |

### Weekly (Cron, Asia/Kolkata)
| Job | Time | Purpose |
|---|---|---|
| Weekly Memory Distillation | Sun midnight | Synthesize week's logs, update MEMORY.md |
| Weekly Vault Maintenance | Sun 2:00 AM | Run maintenance.py, Telegram notify |

## System Crontab
```
*/30 * * * * /Volumes/madara/2026/twc-vault/_System/openclaw/agents/sadhana-orchestrator/agent/sync_x_bookmarks.sh --apply-unbookmark
```

## Environment Keys (from ~/.openclaw/.env)
20 env vars present including: ELEVENLABS_API_KEY, FAL_KEY, XAI_API_KEY, OPENROUTER_API_KEY, MOONSHOT_API_KEY, DISCORD_TOKEN, and more.

## Brahman Darshanam Dashboard Integration
- **PaperclipBridge** → reads from `http://127.0.0.1:3100/api/companies/d89420ba.../` (UPDATED from old org)
- **OpenClawBridge** → reads from `~/.openclaw/openclaw.json` for agent topology
- **SelemeneBridge** → reads from `selemene.tryambakam.space` for Vedic timing
- **ScheduledTasksBridge** → merges 27 Claude Code scheduled tasks with live cron jobs

## Control Center Integration
- **controlRegistry** → Paperclip bootstrap at ts-paperclip (UPDATED from old path)
- **7 operators** registered: noesis-vishwakarma, sadhana-orchestrator, chitta-weaver, kosha-regulator, nadi-mapper, pi, brahman-darshanam
- **Reads cron runs** from `~/.openclaw/cron/runs/*.jsonl`
