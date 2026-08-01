---
name: commit-release
description: Commit changes following repo conventions and update CHANGELOG.md (Keep a Changelog) with Unreleased -> Added entries before pushing
metadata:
  workflow: release
---

# commit-release

## What I do
- Commit repo changes following the project's commit style.
- Update `CHANGELOG.md` (Keep a Changelog) under `## [Unreleased]` -> `### Added`.
- Only commit when the user explicitly asks (commit/push/PR).

## When to use me
Use when the user asks to "commit", "push", or "update changelog" after a
set of changes is complete.

## Steps
1. Inspect state: `git status --short`, `git diff`, `git log --oneline -10`.
2. Update `CHANGELOG.md`:
   - Add `### Added` bullets under `## [Unreleased]`.
   - Describe features/changes, reference docs, roles, or components.
3. Stage only intended files - never secrets, binaries, or tarballs
   (see `.gitignore`: `files/prometheus/exporters/`, etc.).
4. Commit with imperative, descriptive message matching repo style
   (e.g. "Register ansible-mcp server in opencode config and correct AGENTS.md tool references").
5. Push to `origin master` when asked.

## Rules
- Never commit vault plaintext, `CHANGEME-*`, or decrypted secrets.
- Never stage generated downloads/artifacts.
- Run `python3 scripts/okf.py check` before commit if knowledge/ changed.
- Do not commit unless explicitly requested.
