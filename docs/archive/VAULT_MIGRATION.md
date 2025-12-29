# HashiCorp Vault Migration Guide

This guide outlines the migration from shell-based credential management to HashiCorp Vault for production deployments.

## 📋 Current Setup (Development)

**Location**: `~/.zshrc`
```bash
export GITHUB_USERNAME="israel2403"
export GITHUB_TOKEN="ghp_..."
export DOCKERHUB_USERNAME="israelhf24"
export DOCKERHUB_TOKEN="dckr_pat_..."
```

**Workflow**:
1. Credentials stored in `~/.zshrc`
2. `generate-env.sh` creates `.env` file
3. Docker Compose reads `.env`
4. Jenkins uses credentials from environment

**Limitations**:
- ❌ Secrets stored in plaintext
- ❌ No audit logging
- ❌ Manual rotation required
- ❌ Not suitable for production
- ❌ Single point of failure

## 🎯 Target Setup (Production with Vault)

**Architecture**:
```
┌─────────────────────────────────────────────────────┐
│                 Docker Network                       │
│                                                      │
│  ┌──────────┐       ┌──────────┐      ┌─────────┐ │
│  │ Jenkins  │──────▶│  Vault   │      │  App    │ │
│  │          │       │          │      │         │ │
│  │ Requests │       │ Provides │      │ Gets    │ │
│  │ Secrets  │       │ Secrets  │      │ Secrets │ │
│  └──────────┘       └──────────┘      └─────────┘ │
│                            │                        │
│                     ┌──────▼──────┐                │
│                     │   Storage   │                │
│                     │  (Encrypted)│                │
│                     └─────────────┘                │
└─────────────────────────────────────────────────────┘
```

## 🚀 Step-by-Step Migration

### Step 1: Add Vault to Docker Compose

Update `docker-compose.yml`:

```yaml
services:
  vault:
    image: vault:latest
    container_name: amazon-api-vault
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: ${VAULT_ROOT_TOKEN}
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - ./vault/config:/vault/config
      - ./vault/data:/vault/data
      - ./vault/logs:/vault/logs
    command: server
    networks:
      - ci-cd-network

  jenkins:
    # ... existing jenkins config
    depends_on:
      - vault
    networks:
      - ci-cd-network

networks:
  ci-cd-network:
    driver: bridge
```

### Step 2: Initialize Vault

```bash
# Start Vault
docker-compose up -d vault

# Wait for Vault to be ready
sleep 5

# Initialize Vault (save these keys securely!)
docker exec -it amazon-api-vault vault operator init

# Unseal Vault (use 3 of 5 unseal keys)
docker exec -it amazon-api-vault vault operator unseal <key1>
docker exec -it amazon-api-vault vault operator unseal <key2>
docker exec -it amazon-api-vault vault operator unseal <key3>

# Login with root token
docker exec -it amazon-api-vault vault login <root-token>
```

### Step 3: Store Secrets in Vault

```bash
# Enable KV secrets engine
docker exec -it amazon-api-vault vault secrets enable -version=2 kv

# Store GitHub credentials
docker exec -it amazon-api-vault vault kv put kv/amazon-api/github \
  username="your_github_username" \
  token="your_github_token_here"

# Store DockerHub credentials
docker exec -it amazon-api-vault vault kv put kv/amazon-api/dockerhub \
  username="your_dockerhub_username" \
  token="your_dockerhub_token_here"

# Store Jenkins admin credentials
docker exec -it amazon-api-vault vault kv put kv/amazon-api/jenkins \
  admin_user="admin" \
  admin_password="your_jenkins_password_here"

# Verify secrets
docker exec -it amazon-api-vault vault kv get kv/amazon-api/github
```

### Step 4: Configure Vault Authentication for Jenkins

```bash
# Enable AppRole authentication
docker exec -it amazon-api-vault vault auth enable approle

# Create policy for Jenkins
docker exec -it amazon-api-vault vault policy write jenkins-policy - <<EOF
path "kv/data/amazon-api/*" {
  capabilities = ["read", "list"]
}
EOF

# Create AppRole for Jenkins
docker exec -it amazon-api-vault vault write auth/approle/role/jenkins \
  token_policies="jenkins-policy" \
  token_ttl=1h \
  token_max_ttl=4h

# Get Role ID and Secret ID (save these!)
docker exec -it amazon-api-vault vault read auth/approle/role/jenkins/role-id
docker exec -it amazon-api-vault vault write -f auth/approle/role/jenkins/secret-id
```

### Step 5: Install HashiCorp Vault Plugin in Jenkins

Add to `jenkins/Dockerfile`:

```dockerfile
RUN jenkins-plugin-cli --plugins \
    configuration-as-code \
    git \
    workflow-aggregator \
    docker-workflow \
    kubernetes-cli \
    credentials-binding \
    hashicorp-vault-plugin
```

### Step 6: Configure Jenkins to Use Vault

Update `jenkins/casc.yaml`:

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - vaultAppRoleCredential:
              id: "vault-approle"
              path: "approle"
              roleId: "${VAULT_ROLE_ID}"
              secretId: "${VAULT_SECRET_ID}"
              description: "Vault AppRole"
              scope: GLOBAL

unclassified:
  hashicorpVault:
    configuration:
      vaultUrl: "http://vault:8200"
      vaultCredentialId: "vault-approle"
      engineVersion: 2
      skipSslVerification: true  # Only for dev/testing
```

### Step 7: Update Jenkinsfile to Use Vault

```groovy
pipeline {
    agent any
    
    environment {
        VAULT_ADDR = 'http://vault:8200'
    }
    
    stages {
        stage('Fetch Secrets from Vault') {
            steps {
                script {
                    withVault([
                        vaultSecrets: [
                            [
                                path: 'kv/amazon-api/dockerhub',
                                secretValues: [
                                    [envVar: 'DOCKERHUB_USERNAME', vaultKey: 'username'],
                                    [envVar: 'DOCKERHUB_TOKEN', vaultKey: 'token']
                                ]
                            ],
                            [
                                path: 'kv/amazon-api/github',
                                secretValues: [
                                    [envVar: 'GITHUB_USERNAME', vaultKey: 'username'],
                                    [envVar: 'GITHUB_TOKEN', vaultKey: 'token']
                                ]
                            ]
                        ]
                    ]) {
                        // Your build steps here with secrets available
                        sh 'echo "Building with user: $DOCKERHUB_USERNAME"'
                    }
                }
            }
        }
        
        stage('Build & Test') {
            steps {
                dir('amazon-api-users') {
                    sh 'mvn clean package'
                }
            }
        }
        
        stage('Docker Build & Push') {
            when { branch 'main' }
            steps {
                script {
                    withVault([vaultSecrets: [...]]) {
                        dir('amazon-api-users') {
                            sh """
                                echo \${DOCKERHUB_TOKEN} | docker login -u \${DOCKERHUB_USERNAME} --password-stdin
                                docker build -t \${DOCKERHUB_USERNAME}/amazon-api-users:${BUILD_NUMBER} .
                                docker push \${DOCKERHUB_USERNAME}/amazon-api-users:${BUILD_NUMBER}
                                docker logout
                            """
                        }
                    }
                }
            }
        }
    }
}
```

### Step 8: Update Environment Variable Loading

Update `.env.example`:

```bash
# .env.example - For Vault-based setup
# These are only needed for Vault authentication

VAULT_ADDR=http://localhost:8200
VAULT_ROOT_TOKEN=your_vault_root_token
VAULT_ROLE_ID=your_jenkins_role_id
VAULT_SECRET_ID=your_jenkins_secret_id

K8S_NAMESPACE=amazon-api
```

### Step 9: Create Vault Helper Scripts

`vault-setup.sh`:
```bash
#!/usr/bin/env bash
# Automated Vault setup script

set -e

echo "🔐 Setting up HashiCorp Vault..."

# Start Vault
docker-compose up -d vault
sleep 10

# Initialize and configure
# ... (include steps from Step 2 and 3)

echo "✅ Vault setup complete!"
```

## 🔄 Secret Rotation

### Automated Rotation with Vault

```bash
# Create a dynamic secret policy
vault write kv/config \
  max_versions=5 \
  delete_version_after=90d

# Rotate DockerHub token
vault kv put kv/amazon-api/dockerhub \
  username="israelhf24" \
  token="new_token_here"

# Jenkins will automatically use new secret on next run
```

### Manual Rotation Schedule

- **GitHub tokens**: Every 90 days
- **DockerHub tokens**: Every 90 days
- **Jenkins admin password**: Every 180 days
- **Vault root token**: Rotate and revoke old tokens

## 📊 Vault Audit Logging

Enable audit logging:

```bash
docker exec -it amazon-api-vault vault audit enable file \
  file_path=/vault/logs/audit.log

# View audit logs
docker exec -it amazon-api-vault tail -f /vault/logs/audit.log
```

## 🔒 Production Security Best Practices

1. **Use TLS**: Enable SSL/TLS for Vault communication
2. **Seal Vault**: Use auto-unseal with cloud KMS
3. **Backup**: Regular backups of Vault data
4. **Monitoring**: Set up Vault metrics and alerts
5. **Access Control**: Implement least-privilege policies
6. **MFA**: Enable multi-factor authentication
7. **Network Segmentation**: Isolate Vault in private network

## 📈 Migration Checklist

- [ ] Add Vault to docker-compose.yml
- [ ] Initialize and unseal Vault
- [ ] Store all secrets in Vault
- [ ] Configure Jenkins AppRole authentication
- [ ] Install Vault plugin in Jenkins
- [ ] Update Jenkins configuration (casc.yaml)
- [ ] Update Jenkinsfile to fetch from Vault
- [ ] Test pipeline with Vault secrets
- [ ] Enable audit logging
- [ ] Document Vault unsealing procedure
- [ ] Set up secret rotation schedule
- [ ] Remove credentials from ~/.zshrc
- [ ] Update team documentation

## 🆘 Troubleshooting

### Vault is sealed
```bash
docker exec -it amazon-api-vault vault status
docker exec -it amazon-api-vault vault operator unseal <key>
```

### Jenkins can't connect to Vault
- Check network connectivity: `docker exec -it amazon-api-jenkins curl http://vault:8200`
- Verify AppRole credentials are correct
- Check Vault audit logs for denied requests

### Secrets not updating in Jenkins
- Verify secret path in Jenkinsfile
- Check Vault policy allows read access
- Review Jenkins Vault plugin configuration

## 📚 Additional Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Jenkins Vault Plugin](https://plugins.jenkins.io/hashicorp-vault-plugin/)
- [Vault Best Practices](https://learn.hashicorp.com/tutorials/vault/production-hardening)
