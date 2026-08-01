---
type: Reference
title: Open Knowledge Format (OKF) v0.2
description: Bundle structure, frontmatter, trust/provenance, and conformance rules for this wiki.
resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
tags: [okf, spec, wiki]
status: stable
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: OKF SPEC v0.2
    author: GoogleCloudPlatform
    last_modified: 2026-07-15
generated:
  by: human:alaureijs
  at: 2026-08-01T12:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T12:00:00Z
---

This bundle follows OKF v0.2.[^okf-spec] The rules that govern it:

## Bundle structure

- A bundle is a directory tree of markdown files with YAML frontmatter.
- Reserved filenames: `index.md` (directory listing, no frontmatter except
  a root `okf_version`) and `log.md` (ISO 8601 date-grouped history,
  newest first). Everything else is a concept.

## Concept frontmatter

- **Required**: `type` — a short, self-explanatory type string.
- **Recommended**: `title`, `description`, `resource`, `tags`.
- **Trust family**: `sources` (per-claim attribution via `[^id]` footnotes),
  `generated: {by, at}`, `verified: [{by, at}]`.
- **Lifecycle**: `status` (`draft`/`stable`/`deprecated`, default `stable`),
  `stale_after` (absolute date).
- Unknown extra keys are preserved; consumers must not reject them.

## Trust tiers

Derived from `verified`: absent → unverified; non-`human:` only →
machine-confirmed; any `human:<id>` → human-reviewed.

## Cross-linking

- Absolute bundle-relative links start with `/` (recommended).
- Relative links are standard markdown paths.
- Broken links must be tolerated.

## Conformance

A bundle is conformant when: every non-reserved `.md` has parseable
frontmatter with a non-empty `type`; reserved files follow their structure.
Checked by `scripts/okf.py check`.

[^okf-spec]: OKF SPEC v0.2 — GoogleCloudPlatform/knowledge-catalog
