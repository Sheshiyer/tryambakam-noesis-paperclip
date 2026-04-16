# Paperclip local-cli auth regression

Date: 2026-04-11
Owner: CLAWD

## Symptom

Running `paperclipai agent local-cli clawd -C d89420ba-ce5a-45f6-bd0a-e735d2e02740` from the CLAWD agent runtime returns `403 Board access required`.

## Evidence

1. Server logs captured the failing request for CLAWD's agent id:
   - `POST /api/agents/2215ad10-7a67-4075-a568-71f76ceb4845/keys`
   - Request body: `{"name":"local-cli"}`
   - Response: `403`
   - Authorization header was an agent JWT derived from `PAPERCLIP_API_KEY`

2. The same route succeeds in `local_trusted` mode when called from localhost without an inherited agent bearer:
   - `POST /api/agents/e9e155c6-e9d7-4c94-a90b-2ab6fba5b1a7/keys`
   - Response: `201`
   - No `authorization` header was present in the log entry

3. The CLI source explains the behavior:
   - `resolveCommandContext` prefers `options.apiKey`, then `process.env.PAPERCLIP_API_KEY`, before any stored board credential.
   - `agent local-cli` uses that shared resolver and then calls `POST /api/agents/:id/keys`.
   - Result: inside an agent heartbeat shell, `paperclipai` authenticates as the agent, not as the local board user.

## Root Cause

This is a context-selection bug, not a missing permission grant.

The CLAWD loop environment exports `PAPERCLIP_API_KEY`, so `paperclipai agent local-cli` sends the agent bearer token automatically. The `/api/agents/:id/keys` endpoint expects board-level access. In `local_trusted` mode, localhost requests can succeed without that agent bearer, but once the CLI includes the inherited agent token, the server evaluates the request as agent-authenticated and rejects it with `403 Board access required`.

## Workaround

Run board-facing CLI commands without the inherited agent bearer:

```bash
env -u PAPERCLIP_API_KEY paperclipai auth login -C d89420ba-ce5a-45f6-bd0a-e735d2e02740
env -u PAPERCLIP_API_KEY paperclipai agent local-cli clawd -C d89420ba-ce5a-45f6-bd0a-e735d2e02740
```

If needed, also unset `PAPERCLIP_AGENT_ID` and related runtime env vars to avoid mixing agent-runtime and board-runtime contexts.

## Proper Fix Options

1. Make `paperclipai agent local-cli` ignore `PAPERCLIP_API_KEY` by default and prefer stored board auth.
2. On `403 Board access required`, allow automatic board-auth recovery even when an explicit env API key is present.
3. Split client context resolution into:
   - agent-auth commands
   - board-auth commands

Option 1 is the safest default for this command because it is explicitly provisioning a local CLI key for an agent and should not silently reuse the agent's own bearer.
