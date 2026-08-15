# SOPS Secrets

How to work with SOPS-encrypted secrets in this repo: encrypt, decrypt,
edit, add age keys — with reading TLS certs as the worked example.

## Overview

Secrets are committed to `cluster/` encrypted with [SOPS] + [age]. Plaintext
never lands in git.

- `.sops.yaml` at repo root drives encryption:
  - any `cluster/*.y(a)ml` file gets its `data`/`stringData` fields encrypted
  - recipients: the age public key `age1vhsg9zcjsyhzqxvaj9rmkwva27ur0s3ymunxfxx2e2vlr2m26aps3vfa98`
- Controller already has `sops` and `age` installed and the age private key
  at `~/.config/sops/age/keys.txt`.
- On the cluster side, ArgoCD's [ksops] plugin decrypts committed secrets at
  sync time (image `viaductoss/ksops:v4.5.1`, SOPS age key mounted from the
  `argocd-sops-age-key` Secret, `SOPS_AGE_KEY_FILE` set).

[SOPS]: https://github.com/getsops/sops
[age]: https://github.com/FiloSottile/age
[ksops]: https://github.com/viaduct-ai/kustomize-sops

## Reading (decrypting) a secret

### One-off view

```bash
# Decrypt a committed secret to stdout (plaintext, never written to disk)
sops --decrypt cluster/base/monitoring/secrets/grafana-admin.sops.yaml

# Decrypt and pipe into kubectl (create secret from the repo value)
sops --decrypt cluster/secrets/argocd-admin-password.yaml | kubectl apply -f -
```

### Interactive edit (encrypts in place, keeps a .tmp)

```bash
sops --edit cluster/base/monitoring/secrets/grafana-admin.sops.yaml
```

### Re-encrypt after editing or adding recipients

```bash
sops --encrypt --in-place cluster/base/monitoring/secrets/grafana-admin.sops.yaml
```

## Reading TLS certs (worked example)

cert-manager issues certs into k8s Secrets (`tls.crt`, `tls.key`, `ca.crt`),
e.g. `monitoring-tls` for `monitoring.homelab.internal`. Inspect without
decrypting to a file:

```bash
# Live cluster secret — no SOPS involved
kubectl get secret -n monitoring monitoring-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout \
  -subject -dates -ext subjectAltName

# Expect:
#   subject=CN=monitoring.homelab.internal
#   notBefore/notAfter 30-day validity
#   X509v3 Subject Alternative Name: DNS:monitoring.homelab.internal
```

To check expiry or SANs across all cert-manager secrets:

```bash
for ns in argocd longhorn-system monitoring; do
  kubectl get secrets -n "$ns" -l cert-manager.io/... -o name 2>/dev/null | while read s; do
    echo "== $s =="
    kubectl get "$s" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d \
      | openssl x509 -noout -subject -dates -ext subjectAltName 2>/dev/null
  done
done
```

### Cert inside a SOPS-encrypted Secret

If a cert has been exported into a committed `cluster/` Secret, decrypt then
pipe through the same pipeline:

```bash
sops --decrypt cluster/base/example/tls.sops.yaml \
  | grep -A1 'tls.crt' \
  | tail -1 | base64 -d | openssl x509 -noout -dates
```

Certs are base64 in `data` like any other Secret value; the SOPS
`encrypted_regex: "^(data|stringData)$"` rule means the whole map is
encrypted, so the decoded `tls.crt` is only visible after decryption.

## Backing up a live cluster cert into the repo

Export a cert-manager Secret to a SOPS-encrypted `cluster/` file:

```bash
# 1. Capture the live secret
kubectl get secret -n monitoring monitoring-tls -o yaml > /tmp/monitoring-tls.yaml

# 2. Place it under cluster/ and encrypt in place
mkdir -p cluster/base/monitoring/secrets
cp /tmp/monitoring-tls.yaml cluster/base/monitoring/secrets/monitoring-tls.sops.yaml
sops --encrypt --in-place cluster/base/monitoring/secrets/monitoring-tls.sops.yaml

# 3. Sanity check it decrypts
sops --decrypt cluster/base/monitoring/secrets/monitoring-tls.sops.yaml | grep -c tls.crt

# 4. Commit the .sops.yaml (encrypted) file; never the plaintext
```

Restore the same way — decrypt to stdout and `kubectl apply -f -`.

## Adding an age key (new recipient / machine)

1. Generate a keypair on the new machine:

   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

   `age-keygen` prints the `# public key: age1...` line — that is the
   recipient to add.

2. Add the public key to `.sops.yaml`:

   ```yaml
   creation_rules:
     - path_regex: cluster/.*\.ya?ml$
       encrypted_regex: "^(data|stringData)$"
       age:
         - age1vhsg9zcjsyhzqxvaj9rmkwva27ur0s3ymunxfxx2e2vlr2m26aps3vfa98
         - age1NEWKEYNEWKEYNEWKEYNEWKEYNEWKEYNEWKEYNEWKEYNE
   ```

3. Re-encrypt all committed secrets so they carry the new recipient:

   ```bash
   find cluster -name '*.sops.yaml' -o -name '*.ya*ml' \
     | xargs -I{} sops --encrypt --in-place {}
   ```

   (sops re-reads `.sops.yaml` and adds the new key to each file's
   `sops.age` recipients.)

4. On the cluster, the ksops plugin reads the age key from the
   `argocd-sops-age-key` Secret (`keys.txt`). Rotate/export that too if the
   private key changed — update `cluster/secrets/argocd-sops-age-key.yaml`
   (encrypted with the controller key) and sync ArgoCD.

## Troubleshooting

### "no age keys found" / cannot decrypt

- Confirm `~/.config/sops/age/keys.txt` exists with the matching private key
  (`sops --decrypt` uses it automatically; no env var needed locally).
- On the cluster: ArgoCD's SOPS age key Secret must contain the private key
  whose public half is a recipient on the committed file.

### File is plaintext or half-encrypted

Only files created through sops are encrypted. Check with:

```bash
sops --decrypt <file>   # prints the file if OK
head -1 <file>          # SOPS files are valid YAML, not raw ciphertext
```

### Want to see the raw encrypted value

```bash
cat <file>   # data/stringData contain ciphertext (age-encrypted); metadata
             # under a top-level `sops` key lists recipients + encrypted regex
```
