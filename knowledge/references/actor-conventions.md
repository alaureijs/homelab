---
type: Reference
title: Actor Conventions
description: Identity conventions used in generated and verified frontmatter fields.
resource: /references/okf-spec.md
tags: [okf, conventions]
status: stable
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: OKF SPEC v0.2, section 7
    last_modified: 2026-07-15
generated:
  by: human:alaureijs
  at: 2026-08-01T12:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T12:00:00Z
---

Fields recording an identity use one actor convention:[^okf-spec]

| Form | Meaning | Example |
|------|---------|---------|
| `<producer>/<version>` | Agent or tool | `reference_agent/gemini-2.5-pro` |
| `human:<id>` | Person | `human:alaureijs` |
| `process:<id>` | Automated process | `process:finance-nightly` |

## Rules

- `human:` prefix marks hand-authored or human-confirmed content and drives
  the `human-reviewed` trust tier.
- In this bundle all concepts are authored and confirmed by
  `human:alaureijs` until an agent or process takes over a file; agents
  must use `<producer>/<version>` for `generated.by` when they rewrite a
  concept.

[^okf-spec]: OKF SPEC v0.2, section 7 — Actor convention
