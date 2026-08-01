---
name: molecule-test
description: Run molecule tests for a role in isolated Podman containers - default/minimum/full scenarios plus idempotence verification
metadata:
  workflow: testing
---

# molecule-test

## What I do
- Test roles with molecule inside isolated Podman containers (never on live VMs).
- Run the three required scenarios: `default`, `minimum`, `full`.
- Verify idempotency (second run must be clean).

## When to use me
Use when modifying an existing role or creating a new one. Also when asked
to validate role correctness, port allocation, container pulls, or PV/PVC
mounts.

## Required scenarios per role
- `default` - default variables, basic connectivity
- `minimum` - minimal deployment, essential services only
- `full` - all features enabled

## Commands
```bash
# Run all tests for a role
cd roles/<role> && molecule test

# Test one scenario
cd roles/<role> && molecule scenario default test

# Converge + verify idempotency
cd roles/<role> && molecule converge
cd roles/<role> && molecule idempotence
```

## Sandbox rules
- All testing runs in containers via `molecule` / podman driver.
- NEVER execute host-modifying commands outside the sandbox.
- If tests fail: mark task FAILED, fix role, re-run.

## Assertions
- Tasks execute without errors
- Services start and pass health checks
- Config files generated correctly
- Ports allocated without conflicts
- Images pull successfully
- PV/PVC mounts work
