# Amazon API Orders Service

Orders microservice for the Amazon Store API built with Spring Boot (Reactive) and PostgreSQL.

## 🏗️ Technology Stack

- **Java 21**
- **Spring Boot 3.x** (WebFlux - Reactive)
- **Spring Data R2DBC** (Reactive database access)
- **PostgreSQL 16** (Database)
- **Flyway** (Database migrations)
- **Gradle** (Build tool)

## 🚀 Quick Start

### Prerequisites

- Java 21
- Docker & Docker Compose
- PostgreSQL 16 (via Docker)

### 1. Start PostgreSQL Database

```bash
# Start PostgreSQL container
docker compose up -d

# Verify PostgreSQL is running
docker ps | grep postgres-orders

# Check logs
docker compose logs postgres-orders
```

### 2. Run the Application

```bash
# Build
./gradlew clean build

# Run (set profile as needed)
# Examples:
#   SPRING_PROFILES_ACTIVE=development ./gradlew bootRun
#   ./gradlew bootRun -Dspring.profiles.active=local
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun

# Or run the JAR directly
SPRING_PROFILES_ACTIVE=local java -jar build/libs/amazonapi-orders-*.jar
```

The application will start on **port 8082**.

### 3. Test the API

```bash
# Health check
curl http://localhost:8082/api/orders

# Create an order
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "productId": "product456",
    "quantity": 2,
    "totalPrice": 59.99
  }'

# Get all orders
curl http://localhost:8082/api/orders

# Get order by ID
curl http://localhost:8082/api/orders/{id}

# Update an order
curl -X PUT http://localhost:8082/api/orders/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "productId": "product456",
    "quantity": 3,
    "totalPrice": 89.99
  }'

# Delete an order
curl -X DELETE http://localhost:8082/api/orders/{id}
```

## 🔐 Database Configuration

### Local Development

The application uses these defaults (in `src/main/resources/application.yml`, shared by all profiles):

```properties
spring.r2dbc.url=r2dbc:postgresql://localhost:5432/amazon_orders
spring.r2dbc.username=postgres
spring.r2dbc.password=postgres
```

Use `application-{profile}.yml` for overrides:
- `application-development.yml` – dev defaults (Kubernetes service URL, dev password)
- `application-production.yml` – production tuning, secrets expected from env/secret mounts
- `application-local.yml` – local overrides (localhost DB)

### Using Vault (Production)

PostgreSQL credentials are stored in HashiCorp Vault:

**Vault Path**: `kv/amazon-api/postgres`

**Keys**:
- `database`: amazon_orders
- `username`: postgres
- `password`: <your-secure-password>

The Jenkins pipeline automatically fetches these credentials from Vault.

### Environment Variables

You can override database settings with environment variables:

```bash
export SPRING_R2DBC_URL=r2dbc:postgresql://localhost:5432/amazon_orders
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=your_password

./gradlew bootRun
```

## 📋 Database Management

### Access PostgreSQL

```bash
# Connect to PostgreSQL container
docker exec -it amazonapi-orders-postgres psql -U postgres -d amazon_orders

# List tables
\dt

# Query orders
SELECT * FROM orders;

# Exit
\q
```

### Database Migrations

Flyway manages database migrations automatically.

Migration files location: `src/main/resources/db/migration/`

```
db/migration/
  ├── V1__create_orders_table.sql
  └── V2__add_indexes.sql
```

### Stop PostgreSQL

```bash
# Stop and remove containers
docker compose down

# Stop and remove containers + volumes (deletes data!)
docker compose down -v
```

## 🔧 Configuration Files

- **docker-compose.yml** - PostgreSQL container definition
- **.env.example** - Environment variables template
- **application.properties** - Spring Boot configuration
- **Dockerfile** - Container image build
- **Jenkinsfile** - CI/CD pipeline (uses Vault)

## 🐳 Docker

### Build Docker Image

```bash
docker build -t amazonapi-orders:latest .
```

### Run with Docker

```bash
# Run PostgreSQL first
docker compose up -d postgres-orders

# Run the application
docker run -p 8082:8082 \
  -e SPRING_R2DBC_URL=r2dbc:postgresql://host.docker.internal:5432/amazon_orders \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  amazonapi-orders:latest
```

## ☸️ Kubernetes Deployment

The service is deployed to Kubernetes as part of the CI/CD pipeline.

**Manifests**:
- `k8s/deployment-orders.yaml` - Deployment configuration
- `k8s/service-orders.yaml` - Service configuration (NodePort 30082)

**Deploy manually**:
```bash
bash ../k8s/deploy-orders.sh
```

## 🔄 CI/CD Pipeline

The Jenkinsfile automatically:
1. Loads secrets from Vault (DockerHub + PostgreSQL)
2. Builds with Gradle
3. Creates Docker image
4. Pushes to DockerHub
5. Deploys to Kubernetes

**Trigger**: Push to `master` branch

## 📊 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/orders` | Get all orders |
| GET | `/api/orders/{id}` | Get order by ID |
| POST | `/api/orders` | Create new order |
| PUT | `/api/orders/{id}` | Update order |
| DELETE | `/api/orders/{id}` | Delete order |

## 🐛 Troubleshooting

### Can't connect to PostgreSQL

```bash
# Check if PostgreSQL is running
docker ps | grep postgres-orders

# Check PostgreSQL logs
docker compose logs postgres-orders

# Test connection
docker exec -it amazonapi-orders-postgres pg_isready -U postgres
```

### Port already in use

The service uses port **8082**. If there's a conflict:

1. Stop the conflicting service
2. Or change the port in `application.properties`:
   ```properties
   server.port=8083
   ```

### Flyway migration errors

```bash
# Check Flyway history
docker exec -it amazonapi-orders-postgres psql -U postgres -d amazon_orders \
  -c "SELECT * FROM flyway_schema_history;"

# Reset database (WARNING: deletes all data!)
docker compose down -v
docker compose up -d
```

## 📁 Project Structure

```
amazonapi-orders/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/huerta/amazonapi/orders/
│   │   │       ├── controller/
│   │   │       ├── model/
│   │   │       ├── repository/
│   │   │       └── service/
│   │   └── resources/
│   │       ├── application.properties
│   │       └── db/migration/
│   └── test/
├── build.gradle
├── Dockerfile
├── Jenkinsfile
├── docker-compose.yml
└── README.md
```

## 🔗 Related Services

- **Users Service**: Port 8081
- **Jenkins**: Port 8080
- **Vault**: Port 8200
- **PostgreSQL**: Port 5432

## 📚 Documentation

- [Spring Data R2DBC](https://spring.io/projects/spring-data-r2dbc)
- [Flyway Migrations](https://flywaydb.org/documentation/)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)
- [Vault Setup Guide](../VAULT_SETUP.md)
