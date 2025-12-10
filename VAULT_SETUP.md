# Vault Setup Guide - Simplified Approach

This project uses **HashiCorp Vault** for secure secret management. Secrets are automatically loaded from your `.env` file into Vault when you run the setup script.

## 🎯 Why Vault?

- ✅ **Centralized secret management** - All secrets in one secure place
- ✅ **Audit logging** - Know who accessed what and when
- ✅ **No plaintext secrets in Jenkins** - Secrets fetched on-demand
- ✅ **Easy rotation** - Update secrets without redeploying
- ✅ **Encryption** - Secrets encrypted at rest and in transit

## 🚀 Quick Start

### 1. Create Your .env File

```bash
# Copy the example
cp .env.example .env

# Edit with your real credentials
nano .env
```

Your `.env` should look like this:

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

### 2. Run the Setup Script

```bash
./setup-vault.sh
```

This script will:
1. ✅ Validate your `.env` file
2. ✅ Start Vault container
3. ✅ Load all secrets into Vault
4. ✅ Verify secrets were stored

### 3. Start Jenkins

```bash
docker compose up -d jenkins
```

### 4. Done!

Your pipelines will now fetch secrets from Vault automatically! 🎉

## 🔍 How It Works

### Architecture

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
│  │  Vault Dev     │←──── Jenkins            │
│  │  Container     │      (fetches secrets)  │
│  │                │                          │
│  │  Stores:       │                          │
│  │  - GitHub      │                          │
│  │  - DockerHub   │                          │
│  │  - Jenkins     │                          │
│  │  - K8s config  │                          │
│  └────────────────┘                         │
└─────────────────────────────────────────────┘
```

### Jenkinsfile Integration

Both service Jenkinsfiles already have Vault integration:

```groovy
def loadVaultSecrets() {
    withVault([
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

## 📋 Secrets Stored in Vault

| Path | Keys | Used By |
|------|------|---------|
| `kv/amazon-api/github` | `username`, `token` | Jenkins (future use) |
| `kv/amazon-api/dockerhub` | `username`, `token` | Jenkins pipelines |
| `kv/amazon-api/jenkins` | `admin_user`, `admin_password` | Jenkins CASC |
| `kv/amazon-api/kubernetes` | `namespace` | Deployment scripts |

## 🔧 Common Operations

### View Secrets in Vault

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

### Reset Vault (Start Over)

```bash
# Stop and remove Vault container
docker compose down vault

# Remove Vault data
rm -rf vault/data/*

# Re-run setup
./setup-vault.sh
```

## 🐛 Troubleshooting

### Issue: "Vault container not running"

**Solution:**
```bash
docker compose up -d vault
docker compose logs vault
```

### Issue: "Secrets not found in Vault"

**Solution:**
```bash
# Re-run the setup script
./setup-vault.sh
```

### Issue: "Jenkins can't connect to Vault"

**Solution:**
```bash
# Check vault is accessible from Jenkins
docker exec -it amazon-api-jenkins curl http://vault:8200/v1/sys/health

# Check Jenkins logs
docker logs amazon-api-jenkins
```

### Issue: "withVault step not found in Jenkins"

**Solution:**
Jenkins needs the HashiCorp Vault plugin. Check `jenkins/Dockerfile` includes:
```dockerfile
RUN jenkins-plugin-cli --plugins hashicorp-vault-plugin
```

## 🔐 Security Notes

### Development Setup (Current)

- Uses Vault in **dev mode** (unsealed automatically)
- Root token is simple (`myroot`)
- ✅ Good for: Local development, learning
- ❌ Not for: Production

### Production Setup (Future)

For production, you should:
1. Use Vault in **production mode** (not dev mode)
2. Use proper **seal/unseal** keys
3. Enable **TLS/SSL**
4. Use **AppRole authentication** instead of root token
5. Implement **secret rotation policies**
6. Enable **audit logging**
7. Use cloud KMS for **auto-unseal**

See `VAULT_MIGRATION.md` for detailed production setup.

## 📁 Related Files

- **setup-vault.sh** - Automated Vault setup script
- **vault/init-vault.sh** - Script that runs inside Vault container
- **.env** - Your secrets (never commit!)
- **.env.example** - Template for .env
- **docker-compose.yml** - Defines Vault service
- **VAULT_MIGRATION.md** - Production hardening guide

## 🎓 Learn More

- [HashiCorp Vault Docs](https://www.vaultproject.io/docs)
- [Vault Getting Started](https://learn.hashicorp.com/vault)
- [Jenkins Vault Plugin](https://plugins.jenkins.io/hashicorp-vault-plugin/)

## ✅ Verification Checklist

After running `setup-vault.sh`, verify:

- [ ] Vault container is running: `docker ps | grep vault`
- [ ] Secrets are stored: `docker exec -e VAULT_TOKEN=myroot amazon-api-vault vault kv list kv/amazon-api`
- [ ] DockerHub secret exists: `docker exec -e VAULT_TOKEN=myroot amazon-api-vault vault kv get kv/amazon-api/dockerhub`
- [ ] Jenkins can access Vault: `docker exec -it amazon-api-jenkins curl http://vault:8200/v1/sys/health`
- [ ] Pipelines can fetch secrets (run a test build)

---

**Need help?** Check the troubleshooting section or open an issue!
