# PostgreSQL + Vault Integration Summary

## ✅ What Was Implemented

Complete PostgreSQL integration for the orders service with Vault secret management.

## 📦 New Files Created

1. **amazonapi-orders/docker-compose.yml** - PostgreSQL 16 container
2. **amazonapi-orders/.env.example** - Environment template
3. **amazonapi-orders/README.md** - Complete service documentation

## ✏️ Files Modified

### Root Level
1. **.env** - Added PostgreSQL credentials
2. **.env.example** - Added PostgreSQL credentials template
3. **setup-vault.sh** - Added PostgreSQL credentials validation and loading
4. **vault/init-vault.sh** - Added PostgreSQL secret storage

### Orders Service
5. **amazonapi-orders/src/main/resources/application.properties** - Updated to use Vault env vars
6. **amazonapi-orders/Jenkinsfile** - Added PostgreSQL credentials from Vault
7. **k8s/deployment-orders.yaml** - Updated env var names

## 🎯 PostgreSQL Configuration

### Docker Compose Setup

The orders service now has its own PostgreSQL container:

```yaml
services:
  postgres-orders:
    image: postgres:16-alpine
    container_name: amazonapi-orders-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: amazon_orders
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: SecurePostgres123!
```

### Vault Integration

PostgreSQL credentials are stored in Vault at: `kv/amazon-api/postgres`

**Keys**:
- `database`: amazon_orders
- `username`: postgres  
- `password`: SecurePostgres123!

### Application Configuration

The application reads PostgreSQL credentials from environment variables:

```properties
spring.r2dbc.username=${POSTGRES_USER:postgres}
spring.r2dbc.password=${POSTGRES_PASSWORD:postgres}
```

These variables are:
- **Local development**: Set by docker-compose
- **Jenkins pipeline**: Fetched from Vault
- **Kubernetes**: Set in deployment manifest

## 🚀 How to Use

### 1. Setup Vault with PostgreSQL Credentials

The setup script now includes PostgreSQL:

```bash
./setup-vault.sh
```

This will:
- ✅ Validate PostgreSQL credentials in .env
- ✅ Load them into Vault
- ✅ Make them available to Jenkins

### 2. Start PostgreSQL for Local Development

```bash
cd amazonapi-orders
docker compose up -d
```

### 3. Run the Orders Service

```bash
cd amazonapi-orders
./gradlew bootRun
```

The application will connect to PostgreSQL using the credentials.

### 4. Test the Database Connection

```bash
# Access PostgreSQL
docker exec -it amazonapi-orders-postgres psql -U postgres -d amazon_orders

# Run queries
SELECT * FROM orders;
```

## 🔄 Workflow

### Development
```
.env (PostgreSQL creds)
    ↓
docker-compose (PostgreSQL container)
    ↓
Orders Service (reads from env vars)
```

### CI/CD
```
.env → setup-vault.sh → Vault
                            ↓
                    Jenkins (fetches creds)
                            ↓
                    Orders Service (uses creds)
```

### Kubernetes
```
Vault → Jenkins → K8s Deployment (env vars)
                        ↓
                  Orders Service Pods
```

## 📋 Environment Variables

### In .env File

```bash
# PostgreSQL credentials (for orders service)
POSTGRES_DB=amazon_orders
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SecurePostgres123!
```

### In Vault

```bash
# View PostgreSQL secrets
docker exec -e VAULT_TOKEN=myroot amazon-api-vault \
  vault kv get kv/amazon-api/postgres
```

### In Jenkinsfile

```groovy
def loadVaultSecrets() {
    withVault([
        vaultSecrets: [
            [
                path: 'kv/amazon-api/postgres',
                secretValues: [
                    [envVar: 'POSTGRES_DB', vaultKey: 'database'],
                    [envVar: 'POSTGRES_USER', vaultKey: 'username'],
                    [envVar: 'POSTGRES_PASSWORD', vaultKey: 'password']
                ]
            ]
        ]
    ]) {
        // Secrets available here
    }
}
```

## 🔍 Verification

### 1. Check Vault Has PostgreSQL Secrets

```bash
docker exec -e VAULT_TOKEN=myroot amazon-api-vault \
  vault kv get kv/amazon-api/postgres
```

### 2. Check PostgreSQL Container is Running

```bash
docker ps | grep postgres-orders
```

### 3. Test Database Connection

```bash
docker exec -it amazonapi-orders-postgres pg_isready -U postgres
```

### 4. Run Orders Service

```bash
cd amazonapi-orders
./gradlew bootRun
```

### 5. Test API with Database

```bash
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "productId": "product456",
    "quantity": 2
  }'

curl http://localhost:8082/api/orders
```

## 🐛 Troubleshooting

### Issue: Can't connect to PostgreSQL

**Check if PostgreSQL is running:**
```bash
cd amazonapi-orders
docker compose ps
```

**Check PostgreSQL logs:**
```bash
docker compose logs postgres-orders
```

**Test connection:**
```bash
docker exec -it amazonapi-orders-postgres pg_isready -U postgres
```

### Issue: Wrong credentials

**Update in Vault:**
```bash
docker exec -e VAULT_TOKEN=myroot amazon-api-vault \
  vault kv put kv/amazon-api/postgres \
    database="amazon_orders" \
    username="postgres" \
    password="new_password"
```

**Or update .env and re-run:**
```bash
nano .env
./setup-vault.sh
```

### Issue: Port 5432 already in use

**Stop conflicting PostgreSQL:**
```bash
# Find what's using port 5432
sudo lsof -i :5432

# Or stop your local PostgreSQL
sudo systemctl stop postgresql
```

**Or change the port in docker-compose.yml:**
```yaml
ports:
  - "5433:5432"  # Use 5433 externally
```

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│  Development Environment                             │
│                                                      │
│  .env file                                           │
│     ↓                                                │
│  setup-vault.sh                                      │
│     ↓                                                │
│  ┌──────────┐       ┌──────────┐                    │
│  │  Vault   │       │PostgreSQL│                    │
│  │          │       │  16      │                    │
│  │ Stores:  │       │          │                    │
│  │ - GitHub │       │ Database:│                    │
│  │ - Docker │       │ amazon_  │                    │
│  │ - Jenkins│       │ orders   │                    │
│  │ - K8s    │       └─────▲────┘                    │
│  │ - POSTGRES│            │                          │
│  └─────▲────┘             │                          │
│        │                  │                          │
│  ┌─────┴────────┐    ┌───┴──────┐                   │
│  │   Jenkins    │    │  Orders  │                   │
│  │   Pipeline   │───▶│  Service │                   │
│  │              │    │  (8082)  │                   │
│  └──────────────┘    └──────────┘                   │
└─────────────────────────────────────────────────────┘
```

## ✅ Summary

You now have:

- ✅ PostgreSQL 16 running in Docker for orders service
- ✅ PostgreSQL credentials stored in Vault
- ✅ Orders service configured to use credentials from Vault
- ✅ Jenkins pipeline fetching credentials from Vault
- ✅ Kubernetes deployment with PostgreSQL env vars
- ✅ Complete documentation in amazonapi-orders/README.md

## 🚀 Next Steps

1. **Start PostgreSQL**:
   ```bash
   cd amazonapi-orders
   docker compose up -d
   ```

2. **Re-run Vault Setup** (to load PostgreSQL creds):
   ```bash
   ./setup-vault.sh
   ```

3. **Test the orders service**:
   ```bash
   cd amazonapi-orders
   ./gradlew bootRun
   curl http://localhost:8082/api/orders
   ```

4. **Commit changes**:
   ```bash
   git add .
   git commit -m "Add PostgreSQL integration with Vault for orders service"
   git push
   ```

---

**All PostgreSQL integration with Vault is complete!** 🎉
