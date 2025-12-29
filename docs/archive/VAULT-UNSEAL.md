# Vault Unsealing Procedure

## Credentials
**⚠️ IMPORTANT: Keep these credentials secure!**

- **Unseal Key**: `jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=`
- **Root Token**: `hvs.qb4jSCwkdHBZwFZw14A7M7qV`

## When to Unseal
Vault needs to be unsealed after:
- Pod restarts
- Server reboots
- Vault crashes

## Unsealing Steps

1. Check Vault status:
```bash
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault status
```

2. If `Sealed: true`, unseal it:
```bash
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault operator unseal jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=
```

3. Verify it's unsealed:
```bash
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault status
```

Should show `Sealed: false`

## Testing Secret Persistence

Test that secrets survive restarts:
```bash
# Check secret before restart
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/dockerhub"

# Restart pod
kubectl delete pod -n amazon-api -l app=vault
sleep 15

# Unseal
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault operator unseal jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=

# Verify secret still exists
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/dockerhub"
```

## Architecture

- **Dev environment**: Uses K8s secrets (`dockerhub-secret`)
- **Prod environment**: Uses Vault for centralized secret management
- **Storage**: File backend with PVC (`/vault/data`)
- **Persistence**: YES - secrets survive restarts

## Adding New Secrets

```bash
VAULT_TOKEN="hvs.qb4jSCwkdHBZwFZw14A7M7qV"
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault kv put kv/amazon-api/SECRET_NAME key1=value1 key2=value2"
```

## Troubleshooting

### Vault pod is sealed
Run the unseal command above.

### Can't connect to Vault
Check pod status:
```bash
kubectl get pods -n amazon-api -l app=vault
kubectl logs -n amazon-api -l app=vault --tail=50
```

### Lost unseal key
If you lose the unseal key, you'll need to:
1. Delete the PVC data
2. Reinitialize Vault (creates new keys)
3. Re-add all secrets
