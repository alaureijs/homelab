---
name: knowledge-update
description: Update the OKF v0.2 knowledge wiki after infra changes - refresh affected concepts, add log.md entry, run okf.py check and index, update guides index
metadata:
  workflow: knowledge
---

# knowledge-update

## What I do
- Keep `knowledge/` (OKF v0.2 bundle) in sync with the codebase.
- Update affected concept files when roles, playbooks, inventory, versions, or addresses change.
- Regenerate indexes, validate, and fix violations.

## When to use me
Always after any infra change: role edits, new hosts, version bumps,
config changes, new services, new docs. Never leave knowledge out of sync.

## Steps
1. Identify affected concepts under `knowledge/` (infrastructure/, services/,
   roles/, playbooks/, operations/, guides/).
2. Update each concept's YAML frontmatter + body.
   - Required: `type`; use `generated`/`verified` with `human:<id>` or
     `<producer>/<version>` actors; attribute claims via `sources` + `[^id]`.
   - Reserved names: `index.md` (listing), `log.md` (history) - never concepts.
3. Add an entry to `knowledge/log.md` describing the change.
4. Validate: `python3 scripts/okf.py check` (must pass, 0 violations).
5. Regenerate indexes: `python3 scripts/okf.py index --write`.
6. Update hand-authored root `knowledge/index.md` for new top-level entries
   and `knowledge/guides/index.md` for new guides.

## File layout
```
knowledge/
  index.md              # hand-authored bundle root
  log.md                # update history
  <category>/<name>.md  # concept files with frontmatter
  references/okf-spec.md
```
