# Product Architecture Notes

## Ecosystem Shape
- Selemene API is the computational core.
- The Noesis TUI is the serious operator interface.
- Somatic Canticles is the narrative / philosophical bridge.
- The dashboard and protocols form the next major practice layer.

## Implementation Bias
- Keep product surfaces modular so narrative, software, and mentorship funnels can evolve independently.
- Shared concepts should stay consistent across API, UI, and editorial layers.

## Vault Control Plane Boundary
- Canonical vault bridge: `memory/twc-vault-integration.md`
- Paperclip is the control plane for `twc-vault`, not the knowledge plane.
- The vault owns PARA taxonomy, MOC structure, Meru evidence, and `.claude/skills` semantics.
- Paperclip owns routing, ownership, escalation, and review against staged vault artifacts.
- One candidate evidence surface should correspond to one active Paperclip assignment.
