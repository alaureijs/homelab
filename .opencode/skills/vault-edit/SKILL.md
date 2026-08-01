---
name: vault-edit
description: Manage ansible-vault encrypted secrets - edit/view vault files, encrypt_string for inline !vault tags, never commit plaintext passwords
metadata:
  workflow: secrets
---

# vault-edit

## What I do
- Edit encrypted variables in `inventory/group_vars/all/vault.yml`.
- Create new inline `!vault |` encrypted strings (preferred over full-file encryption).
- Add new vault variables referenced by roles (e.g. `vault_harbor_sync_password`).

## When to use me
Use when adding/rotating passwords, tokens, keys, or any secret referenced
by roles and playbooks. Never put plaintext secrets in git.

## Vault file
`inventory/group_vars/all/vault.yml` - individual `!vault |` tagged strings,
not full-file encryption.

## Commands
```bash
# View / edit existing vault
ansible-vault view inventory/group_vars/all/vault.yml
ansible-vault edit inventory/group_vars/all/vault.yml

# Encrypt a new string for inline use
ansible-vault encrypt_string 'my-secret' --name 'vault_new_password'
```

## Naming convention
`vault_<variable_name>` (e.g. `vault_elasticsearch_password`).
Reference in roles as `"{{ vault_elasticsearch_password }}"`.

## Rules
- Never print or echo decrypted secrets into chat or logs.
- Never commit plaintext or `CHANGEME-*` secrets.
- Prefer inline `!vault |` blocks over full-file encryption.
- Run `ansible-vault view` to confirm edits landed before committing.
