# Environment Configuration Guide

## Overview

This guide explains how environment-specific configurations are managed across **development** and **production** environments using ConfigMaps, Secrets, and Vault.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DEVELOPMENT                          │
├─────────────────────────────────────────────────────────┤
│  ConfigMap (app-config)                                 │
│  ├─ DB_HOST, DB_PORT, KAFKA_BROKERS                    │
│  ├─ NODE_ENV=development, LOG_LEVEL=debug              │
│  └─ Kafka Topics configuration                         │
│                                                         │
│  Kubernetes Secret (app-secrets)                        │
│  ├─ POSTGRES_USER (base64)                            │
│  └─ POSTGRES_PASSWORD (base64)                        │
│                                                         │
│  Simple & Fast - No Vault needed                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    PRODUCTION                           │
├─────────────────────────────────────────────────────────┤
│  ConfigMap (app-config)                                 │
│  ├─ DB_HOST, DB_PORT, KAFKA_BROKERS (3 brokers)       │
│  ├─ NODE_ENV=production, LOG_LEVEL=info               │
│  └─ Kafka Topics configuration                         │
│                                                         │
│  Vault (Encrypted Secrets)                             │
│  ├─ POSTGRES_USER (encrypted)                         │
│  ├─ POSTGRES_PASSWORD (encrypted)                     │
│  └─ Audit logs, rotation, access control              │
│                                                         │
│  Secure & Enterprise-ready                             │
└─────────────────────────────────────────────────────────┘
```

## Configuration Files

### Development Environment

**Location**: `k8s/overlays/dev/`

1. **configmap.yaml** - Non-sensitive configuration
   - Database hosts and ports
   - Kafka broker addresses (single broker)
   - Application settings (NODE_ENV=development, LOG_LEVEL=debug)
   - Kafka topic names

2. **secrets.yaml** - Sensitive data (base64 encoded)
   - Database credentials
   - Simple for local development

### Production Environment

**Location**: `k8s/overlays/prod/`

1. **configmap.yaml** - Non-sensitive configuration
   - Database hosts and ports
   - Kafka broker addresses (3 brokers for HA)
   - Application settings (NODE_ENV=production, LOG_LEVEL=info)
   - Kafka topic names

2. **vault-auth.yaml** - Vault integration
   - Service account for Vault authentication
   - Vault configuration (address, role, secret path)
   - Secrets are stored encrypted in Vault

## How Services Use Configuration

### Orders Service (Spring Boot)

```yaml
env:
  # From ConfigMap
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: DB_HOST
  
  # From Secret (dev) or Vault (prod)
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: POSTGRES_PASSWORD
```

**Result**: Service gets environment-specific values automatically based on which overlay is deployed.

### Notifications Service (Node.js)

```yaml
env:
  # Kafka configuration from ConfigMap
  - name: KAFKA_BROKERS
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: KAFKA_BROKERS  # Single broker in dev, 3 in prod
  
  - name: NODE_ENV
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: NODE_ENV  # "development" or "production"
```

## Deployment

### Deploy Development Environment

```bash
cd k8s/scripts
./deploy-dev.sh

# Or using kustomize directly
kubectl apply -k k8s/overlays/dev/
```

**What happens**:
- Creates namespace `amazon-api`
- Deploys ConfigMap with dev settings
- Deploys Secrets with dev credentials (base64)
- Deploys services with 1 replica each
- Connects to single Kafka broker
- Uses debug logging

### Deploy Production Environment

```bash
cd k8s/scripts
./deploy-prod.sh

# Or using kustomize directly
kubectl apply -k k8s/overlays/prod/
```

**What happens**:
- Creates namespace `amazon-api`
- Deploys ConfigMap with prod settings
- Sets up Vault integration
- Deploys services with 5 replicas (users/orders), 3 replicas (notifications)
- Connects to 3 Kafka brokers (HA)
- Uses info-level logging
- Includes Vault and Jenkins infrastructure

## Vault Setup (Production Only)

### Initial Setup

```bash
cd k8s/scripts
./setup-vault-secrets.sh
```

This script:
1. Enables Kubernetes authentication in Vault
2. Creates policy for amazon-store
3. Creates role for service account
4. Stores initial secrets (you should change the password!)

### Update Production Secrets

```bash
# Get Vault pod name
VAULT_POD=$(kubectl get pod -n vault-system -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Update database password
kubectl exec -n vault-system $VAULT_POD -- vault kv put secret/amazon-store/prod/database \
  POSTGRES_USER="postgres" \
  POSTGRES_PASSWORD="YOUR_SECURE_PASSWORD"
```

### Verify Secrets

```bash
# Read secrets from Vault
kubectl exec -n vault-system $VAULT_POD -- vault kv get secret/amazon-store/prod/database
```

## Environment Differences

| Component | Development | Production |
|-----------|-------------|------------|
| **ConfigMap** | ✅ app-config | ✅ app-config |
| **Secrets Storage** | Kubernetes Secret (base64) | Vault (encrypted) |
| **Database Credentials** | Simple password | Strong password in Vault |
| **Kafka Brokers** | 1 broker | 3 brokers (HA) |
| **Service Replicas** | 1 each | 5 (users/orders), 3 (notifications) |
| **Logging Level** | debug | info |
| **NODE_ENV** | development | production |
| **Infrastructure** | Minimal | Full (Vault, Jenkins) |

## Configuration Updates

### Updating Non-Sensitive Config

1. Edit the appropriate ConfigMap:
   - `k8s/overlays/dev/configmap.yaml` for dev
   - `k8s/overlays/prod/configmap.yaml` for prod

2. Apply the changes:
   ```bash
   kubectl apply -k k8s/overlays/dev/  # or prod
   ```

3. Restart pods to pick up new config:
   ```bash
   kubectl rollout restart -n amazon-api deployment/amazonapi-orders-deployment
   ```

### Updating Secrets

**Development**:
```bash
# Update the base64 values in k8s/overlays/dev/secrets.yaml
echo -n "newpassword" | base64  # Get base64 value
# Edit secrets.yaml with new value
kubectl apply -k k8s/overlays/dev/
kubectl rollout restart -n amazon-api deployment/amazonapi-orders-deployment
```

**Production**:
```bash
# Update directly in Vault (no file changes needed)
kubectl exec -n vault-system $VAULT_POD -- vault kv put secret/amazon-store/prod/database \
  POSTGRES_USER="postgres" \
  POSTGRES_PASSWORD="new_secure_password"

# Restart services to pick up new secrets
kubectl rollout restart -n amazon-api deployment/amazonapi-orders-deployment
```

## Testing Configuration

### Verify ConfigMap

```bash
kubectl get configmap -n amazon-api app-config -o yaml
```

### Verify Secrets (Dev)

```bash
# Get secret (base64 encoded)
kubectl get secret -n amazon-api app-secrets -o yaml

# Decode a value
kubectl get secret -n amazon-api app-secrets -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

### Verify Service Environment Variables

```bash
# Check what environment variables a service has
kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- env | grep -E "(DB_|KAFKA_|NODE_ENV)"
```

### Test Database Connection

```bash
# Port-forward and test
kubectl port-forward -n amazon-api svc/amazonapi-orders-service 8082:8082 &
curl http://localhost:8082/
```

## Adding New Configuration

When adding a new microservice:

1. **Update base deployment** (`k8s/apps/your-service/deployment.yaml`):
   ```yaml
   env:
     - name: YOUR_CONFIG
       valueFrom:
         configMapKeyRef:
           name: app-config
           key: YOUR_CONFIG
   ```

2. **Add to ConfigMaps**:
   - `k8s/overlays/dev/configmap.yaml`
   - `k8s/overlays/prod/configmap.yaml`

3. **If sensitive, add to Secrets**:
   - Dev: `k8s/overlays/dev/secrets.yaml`
   - Prod: Store in Vault using `setup-vault-secrets.sh`

4. **Reference in kustomization**:
   - `k8s/overlays/dev/kustomization.yaml`
   - `k8s/overlays/prod/kustomization.yaml`

## Troubleshooting

### Service can't connect to database

```bash
# Check if secret exists
kubectl get secret -n amazon-api app-secrets

# Check service logs
kubectl logs -n amazon-api deployment/amazonapi-orders-deployment

# Verify environment variables in pod
kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- env | grep POSTGRES
```

### ConfigMap not updating

```bash
# Delete and recreate
kubectl delete configmap -n amazon-api app-config
kubectl apply -k k8s/overlays/dev/

# Restart pods
kubectl rollout restart -n amazon-api deployment/amazonapi-orders-deployment
```

### Vault authentication failing (prod)

```bash
# Check Vault status
kubectl get pods -n vault-system

# Check service account
kubectl get sa -n amazon-api amazon-store-sa

# Re-run setup script
cd k8s/scripts
./setup-vault-secrets.sh
```

## Security Best Practices

### Development
- ✅ Use simple passwords (it's just dev)
- ✅ Commit ConfigMaps to git
- ✅ Commit Secrets to git (base64 is not real encryption)
- ✅ Focus on speed and iteration

### Production
- ✅ Use strong, unique passwords
- ✅ Store secrets in Vault, NOT in git
- ✅ Rotate secrets regularly
- ✅ Use Vault audit logs
- ✅ Limit access to Vault
- ✅ Use different credentials than dev

## Summary

✅ **ConfigMaps** → Non-sensitive config (DB hosts, Kafka brokers, log levels)
✅ **Kubernetes Secrets** → Dev environment (simple base64)
✅ **Vault** → Production environment (encrypted, audited, rotatable)
✅ **Services** → Automatically get environment-specific config based on deployment overlay

When you deploy `k8s/overlays/dev/`, services get dev configuration.
When you deploy `k8s/overlays/prod/`, services get prod configuration (with Vault).

**No code changes needed!** Configuration is externalized and environment-specific.
