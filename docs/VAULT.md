# Vault Documentation

Complete guide for HashiCorp Vault integration in the Amazon Store project.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [Unsealing Vault](#unsealing-vault)
4. [Managing Secrets](#managing-secrets)
5. [PostgreSQL Integration](#postgresql-integration)
6. [Production Migration](#production-migration)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Why Vault?

- ✅ **Centralized secret management** - All secrets in one secure place
- ✅ **Audit logging** - Know who accessed what and when
- ✅ **No plaintext secrets in Jenkins** - Secrets fetched on-demand
- ✅ **Easy rotation** - Update secrets without redeploying
- ✅ **Encryption** - Secrets encrypted at rest and in transit

### Setup Steps

#### 1. Create Your .env File

```bash
# Copy the example
cp .env.example .env

# Edit with your real credentials
nano .env
```

Your `.env` should contain:

```bash
# Vault Configuration
VAULT_ADDR=http://localhost:8200
VAULT_ROOT_TOKEN=myroot

# GitHub credentials
GITHUB_USERNAME=israel2403
GITHUB_TOKEN=ghp_your_token_here

# DockerHub credentials
DOCKERHUB_USERNAME=israelhf24
DOCKERHUB_TOKEN=dckr_pat_your_token_here

# Jenkins admin credentials
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=your_secure_password

# Kubernetes configuration
K8S_NAMESPACE=amazon-api
```

⚠️ **NEVER commit the `.env` file!** It's in `.gitignore`.

#### 2. Run the Setup Script

```bash
./setup-vault.sh
```

This script will:
1. ✅ Validate your `.env` file
2. ✅ Start Vault container
3. ✅ Load all secrets into Vault
4. ✅ Verify secrets were stored

#### 3. Start Jenkins

```bash
docker compose up -d jenkins
```

#### 4. Done!

Your pipelines will now fetch secrets from Vault automatically! 🎉

---

## Architecture

### How It Works

```
┌─────────────────────────────────────────────┐
│  Your Machine                                │
│                                              │
│  .env file (your secrets)                   │
│      │                                       │
│      ↓                                       │
│  setup-vault.sh                             │
│      │                                       │
│      ↓                                       │
│  ┌────────────────┐                         │
│  │  Vault         │←──── Jenkins            │
│  │  Container     │      (fetches secrets)  │
│  │                │                          │
│  │  Stores:       │                          │
│  │  - GitHub      │                          │
│  │  - DockerHub   │                          │
│  │  - Jenkins     │                          │
│  │  - K8s config  │                          │
│  │  - PostgreSQL  │                          │
│  └────────────────┘                         │
└─────────────────────────────────────────────┘
```

### Secrets Stored in Vault

| Path | Keys | Used By |
|------|------|---------|
| `kv/amazon-api/github` | `username`, `token` | Jenkins (future use) |
| `kv/amazon-api/dockerhub` | `username`, `token` | Jenkins pipelines |
| `kv/amazon-api/jenkins` | `admin_user`, `admin_password` | Jenkins CASC |
| `kv/amazon-api/kubernetes` | `namespace` | Deployment scripts |
| `kv/amazon-api/postgres` | `user`, `password`, `db` | Applications |

### Jenkinsfile Integration

Both service Jenkinsfiles have Vault integration:

```groovy
def loadDockerHubCredsFromVault() {
    withVault([
        configuration: [
            vaultUrl: 'http://vault.amazon-api.svc.cluster.local:8200',
            vaultCredentialId: 'vault-root-token',
            engineVersion: 2
        ],
        vaultSecrets: [[
            path: 'kv/amazon-api/dockerhub',
            secretValues: [
                [envVar: 'DOCKERHUB_USERNAME', vaultKey: 'username'],
                [envVar: 'DOCKERHUB_TOKEN', vaultKey: 'token']
            ]
        ]]
    ]) {
        env.DOCKERHUB_USERNAME = "${DOCKERHUB_USERNAME}"
        env.DOCKERHUB_TOKEN = "${DOCKERHUB_TOKEN}"
    }
}
```

---

## Unsealing Vault

### When to Unseal

Vault needs to be unsealed after:
- Pod restarts
- Server reboots
- Vault crashes

### Credentials

**⚠️ IMPORTANT: Keep these credentials secure!**

- **Unseal Key**: `jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=`
- **Root Token**: `hvs.qb4jSCwkdHBZwFZw14A7M7qV`

### Unsealing Steps

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

### Testing Secret Persistence

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

---

## Managing Secrets

### View Secrets

```bash
# Set vault token
export VAULT_TOKEN=myroot

# View DockerHub credentials
docker exec -e VAULT_TOKEN=$VAULT_TOKEN amazon-api-vault \
  vault kv get kv/amazon-api/dockerhub

# View all secrets (keys only)
docker exec -e VAULT_TOKEN=$VAULT_TOKEN amazon-api-vault \
  vault kv list kv/amazon-api
```

### Update a Secret

```bash
# Update DockerHub token
docker exec -e VAULT_TOKEN=myroot amazon-api-vault \
  vault kv put kv/amazon-api/dockerhub \
    username="israelhf24" \
    token="new_token_here"

# Jenkins will use the new token on next pipeline run!
```

### Add New Secrets

```bash
VAULT_TOKEN="hvs.qb4jSCwkdHBZwFZw14A7M7qV"
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault kv put kv/amazon-api/SECRET_NAME key1=value1 key2=value2"
```

### Reset Vault

```bash
# Stop and remove Vault container
docker compose down vault

# Remove Vault data
rm -rf vault/data/*

# Re-run setup
./setup-vault.sh
```

---

## PostgreSQL Integration

Vault can manage PostgreSQL credentials securely. Applications retrieve database credentials from Vault at runtime.

### Configuration

PostgreSQL credentials are stored at:
- Path: `kv/amazon-api/postgres`
- Keys: `user`, `password`, `db`

### Application Usage

Applications can fetch PostgreSQL credentials using:

```java
// Example: Spring Boot with Vault integration
@Configuration
@VaultPropertySource("kv/amazon-api/postgres")
public class VaultConfig {
    // Credentials injected automatically
}
```

---

## Production Migration

### Current Setup (Development)

- Uses Vault in **dev mode** (unsealed automatically)
- Root token is simple (`myroot`)
- ✅ Good for: Local development, learning
- ❌ Not for: Production

### Production Requirements

For production deployment, implement:

#### 1. Production Mode
- Disable dev mode
- Use proper seal/unseal with Shamir's Secret Sharing
- Distribute unseal keys to multiple people

#### 2. TLS/SSL
```bash
# Generate certificates
vault operator generate-root -init

# Configure TLS
vault write pki/root/generate/internal \
    common_name=vault.company.com \
    ttl=8760h
```

#### 3. AppRole Authentication
```bash
# Create AppRole for Jenkins
vault auth enable approle

vault write auth/approle/role/jenkins \
    token_policies="jenkins-policy" \
    token_ttl=1h \
    token_max_ttl=4h

# Get RoleID and SecretID
vault read auth/approle/role/jenkins/role-id
vault write -f auth/approle/role/jenkins/secret-id
```

#### 4. Secret Rotation Policies
```bash
# Create rotation policy
vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/amazon_orders" \
    username="postgres" \
    password="$POSTGRES_PASSWORD"

# Create role with TTL
vault write database/roles/amazon-api \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
    default_ttl="1h" \
    max_ttl="24h"
```

#### 5. Audit Logging
```bash
# Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# Enable syslog audit
vault audit enable syslog
```

#### 6. Auto-Unseal with Cloud KMS

**AWS KMS:**
```hcl
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "your-kms-key-id"
}
```

**Google Cloud KMS:**
```hcl
seal "gcpckms" {
  project     = "your-project"
  region      = "us-central1"
  key_ring    = "vault"
  crypto_key  = "vault-key"
}
```

#### 7. High Availability Setup
```yaml
# Vault HA with Raft storage
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
data:
  vault.hcl: |
    storage "raft" {
      path = "/vault/data"
      node_id = "node1"
    }
    
    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_cert_file = "/vault/tls/cert.pem"
      tls_key_file  = "/vault/tls/key.pem"
    }
```

### Migration Checklist

- [ ] Switch from dev mode to production mode
- [ ] Generate and distribute Shamir unseal keys
- [ ] Enable TLS with valid certificates
- [ ] Migrate from root token to AppRole authentication
- [ ] Implement secret rotation policies
- [ ] Enable audit logging
- [ ] Set up auto-unseal with cloud KMS
- [ ] Configure high availability (3+ nodes)
- [ ] Set up monitoring and alerting
- [ ] Document disaster recovery procedures
- [ ] Test backup and restore procedures

---

## Troubleshooting

### Vault container not running

```bash
docker compose up -d vault
docker compose logs vault
```

### Secrets not found in Vault

```bash
# Re-run the setup script
./setup-vault.sh
```

### Jenkins can't connect to Vault

```bash
# Check vault is accessible from Jenkins
docker exec -it amazon-api-jenkins curl http://vault:8200/v1/sys/health

# Check Jenkins logs
docker logs amazon-api-jenkins
```

### withVault step not found in Jenkins

Jenkins needs the HashiCorp Vault plugin. Check `jenkins/Dockerfile` includes:
```dockerfile
RUN jenkins-plugin-cli --plugins hashicorp-vault-plugin
```

### Vault pod is sealed

Run the unseal command:
```bash
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault operator unseal jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=
```

### Can't connect to Vault in Kubernetes

```bash
# Check pod status
kubectl get pods -n amazon-api -l app=vault

# Check logs
kubectl logs -n amazon-api -l app=vault --tail=50
```

### Lost unseal key

If you lose the unseal key:
1. Delete the PVC data
2. Reinitialize Vault (creates new keys)
3. Re-add all secrets

---

## Related Files

- **setup-vault.sh** - Automated Vault setup script
- **vault/init-vault.sh** - Script that runs inside Vault container
- **.env** - Your secrets (never commit!)
- **.env.example** - Template for .env
- **docker-compose.yml** - Defines Vault service

## Learn More

- [HashiCorp Vault Docs](https://www.vaultproject.io/docs)
- [Vault Getting Started](https://learn.hashicorp.com/vault)
- [Jenkins Vault Plugin](https://plugins.jenkins.io/hashicorp-vault-plugin/)

## Verification Checklist

After running `setup-vault.sh`, verify:

- [ ] Vault container is running: `docker ps | grep vault`
- [ ] Secrets are stored: `docker exec -e VAULT_TOKEN=myroot amazon-api-vault vault kv list kv/amazon-api`
- [ ] DockerHub secret exists: `docker exec -e VAULT_TOKEN=myroot amazon-api-vault vault kv get kv/amazon-api/dockerhub`
- [ ] Jenkins can access Vault: `docker exec -it amazon-api-jenkins curl http://vault:8200/v1/sys/health`
- [ ] Pipelines can fetch secrets (run a test build)
