# Integration Testing Guide

This guide covers integration tests that connect to real external services (Vault, MySQL, etc.) to verify the complete application stack.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Running Integration Tests](#running-integration-tests)
- [What Integration Tests Cover](#what-integration-tests-cover)
- [Setup Instructions](#setup-instructions)
- [Troubleshooting](#troubleshooting)
- [Differences from Unit Tests](#differences-from-unit-tests)

---

## Overview

**Integration tests** verify that the application works correctly with real external dependencies:
- ✅ **Vault** - Password pepper retrieval
- ✅ **MySQL** - Database connectivity and operations
- ✅ **Spring Boot** - Full application context

Unlike unit tests that use mocks (H2 database, disabled Vault), integration tests connect to actual services running in your environment.

---

## Prerequisites

### 1. Vault Must Be Running

```bash
# Check Vault status
kubectl get pods -n amazon-api -l app=vault

# Unseal Vault if needed
kubectl exec -n amazon-api vault-xxx -- vault operator unseal <unseal_key>

# Verify pepper secret exists
kubectl exec -n amazon-api vault-xxx -- sh -c \
  "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/security"
```

Expected output:
```
Key                Value
---                -----
password_pepper    H8431v7qg/TA20LkvpaL3dFz9++/CTsvmzecGBPrqB4=
```

### 2. MySQL Must Be Running

```bash
# Check MySQL status
kubectl get pods -n amazon-api-dev -l app=mysql

# Or use local MySQL
mysql -u mysql -p -e "SELECT 1"
```

### 3. Test Database Must Exist

```bash
# Create test database and grant permissions
kubectl exec -n amazon-api-dev $(kubectl get pods -n amazon-api-dev -l app=mysql -o name | head -1) -- \
  mysql -u root -prootpassword123 -e "
    CREATE DATABASE IF NOT EXISTS amazon_users_test;
    GRANT ALL PRIVILEGES ON amazon_users_test.* TO 'mysql'@'%';
    FLUSH PRIVILEGES;"
```

### 4. Port Forwarding (If Using Kubernetes)

```bash
# Forward Vault port
kubectl port-forward -n amazon-api svc/vault 8200:8200 &

# Forward MySQL port (if testing with K8s MySQL)
kubectl port-forward -n amazon-api-dev svc/mysql 3306:3306 &
```

---

## Running Integration Tests

### Quick Start (Using Helper Script)

```bash
cd amazon-api-users
./run-integration-tests.sh
```

The script automatically:
- ✅ Checks Vault and MySQL connectivity
- ✅ Creates test database if needed
- ✅ Runs integration tests with correct environment

### Manual Run (All Integration Tests)

```bash
cd amazon-api-users
VAULT_ADDR=http://localhost:8200 mvn test -Dtest=CucumberIntegrationTest
```

**Note:** `VAULT_ADDR` environment variable is required to override the default Kubernetes service URL.

### Run with Environment Variables

```bash
# Specify Vault and MySQL connection details
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV \
MYSQL_HOST=localhost \
MYSQL_PORT=3306 \
MYSQL_DATABASE=amazon_users_test \
MYSQL_USER=mysql \
MYSQL_PASSWORD=testpassword \
mvn test -Dtest=CucumberIntegrationTest
```

### Run Specific Feature

```bash
mvn test -Dtest=CucumberIntegrationTest \
  -Dcucumber.features=src/test/resources/features/integration/vault_integration.feature
```

### Run with Debug Logging

```bash
mvn test -Dtest=CucumberIntegrationTest -X
```

---

## What Integration Tests Cover

### 1. Vault Integration (`vault_integration.feature`)

#### Scenario: Successfully Create User with Vault-Provided Pepper

```gherkin
Scenario: Successfully create user with Vault-provided pepper
  Given a new user payload:
    | username  | email              | password      |
    | vaultuser | vault@example.com  | VaultPass123! |
  When the client POSTs to "/users-api"
  Then the response status should be 201
  And the response should contain the created user with username "vaultuser"
  And the password is securely hashed using Argon2
  And the password hash includes the Vault pepper
```

**Verifies:**
- ✅ Vault connection successful
- ✅ Password pepper retrieved from Vault
- ✅ Pepper is not the test mock value
- ✅ Pepper is substantial length (>20 chars)

#### Scenario: Password Hashing Uses Different Pepper

```gherkin
Scenario: Password hashing uses different pepper than test mock
  Given a new user payload:
    | username | email            | password      |
    | realuser | real@example.com | RealPass123!  |
  When the client POSTs to "/users-api"
  Then the response status should be 201
  And the password hash is different from test environment hash
```

**Verifies:**
- ✅ Not using test mock pepper ("test-pepper-value-for-unit-tests")
- ✅ Actually connecting to real Vault

### 2. All User Creation Scenarios

Integration tests also run all the standard user creation scenarios from `create_user.feature`, but with:
- Real Vault pepper (not mock)
- Real MySQL database (not H2)
- Full Spring Boot context

---

## Setup Instructions

### Local Development Setup

#### 1. Start Local Vault (Docker)

```bash
# Start Vault in dev mode
docker run -d --name vault-dev \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=myroot \
  hashicorp/vault:latest

# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=myroot

# Add password pepper
docker exec vault-dev vault kv put secret/amazon-api/security \
  password_pepper="H8431v7qg/TA20LkvpaL3dFz9++/CTsvmzecGBPrqB4="
```

#### 2. Start Local MySQL (Docker)

```bash
# Start MySQL
docker run -d --name mysql-test \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=amazon_users_test \
  -e MYSQL_USER=mysql \
  -e MYSQL_PASSWORD=testpassword \
  mysql:8.0

# Wait for MySQL to be ready
docker exec mysql-test mysqladmin ping -h localhost --silent
```

#### 3. Run Integration Tests

```bash
cd amazon-api-users
VAULT_ADDR=http://localhost:8200 mvn test -Dtest=CucumberIntegrationTest
```

### Kubernetes Development Setup

```bash
# 1. Port forward Vault
kubectl port-forward -n amazon-api svc/vault 8200:8200 &

# 2. Port forward MySQL
kubectl port-forward -n amazon-api-dev svc/mysql 3306:3306 &

# 3. Get Vault token (if needed)
export VAULT_TOKEN=$(kubectl exec -n amazon-api vault-xxx -- \
  vault print token 2>/dev/null || echo "hvs.qb4jSCwkdHBZwFZw14A7M7qV")

# 4. Run tests
cd amazon-api-users
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$VAULT_TOKEN \
MYSQL_HOST=localhost \
MYSQL_PORT=3306 \
MYSQL_DATABASE=amazon_users_test \
MYSQL_USER=mysql \
MYSQL_PASSWORD=devpassword123 \
mvn test -Dtest=CucumberIntegrationTest
```

---

## Troubleshooting

### Issue: "Vault connection refused"

**Symptoms:**
```
java.net.ConnectException: Connection refused
  at org.springframework.vault.client.RestTemplateFactory
```

**Solutions:**

1. **Check Vault is running:**
   ```bash
   curl http://localhost:8200/v1/sys/health
   ```

2. **Verify port forwarding:**
   ```bash
   lsof -i :8200
   kubectl port-forward -n amazon-api svc/vault 8200:8200
   ```

3. **Check Vault token:**
   ```bash
   export VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV
   ```

---

### Issue: "Password pepper is not configured"

**Symptoms:**
```
IllegalStateException: Password pepper is not configured
```

**Solutions:**

1. **Verify secret exists in Vault:**
   ```bash
   kubectl exec -n amazon-api vault-xxx -- sh -c \
     "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/security"
   ```

2. **Check Vault path in application-integration.yml:**
   ```yaml
   spring:
     config:
       import: optional:vault://kv/amazon-api/security
   ```

3. **Verify Vault token is valid:**
   ```bash
   kubectl exec -n amazon-api vault-xxx -- vault token lookup
   ```

---

### Issue: "MySQL connection failed"

**Symptoms:**
```
com.mysql.cj.jdbc.exceptions.CommunicationsException: Communications link failure
```

**Solutions:**

1. **Check MySQL is running:**
   ```bash
   kubectl get pods -n amazon-api-dev -l app=mysql
   # or
   docker ps | grep mysql
   ```

2. **Test connection manually:**
   ```bash
   mysql -h localhost -P 3306 -u mysql -p
   ```

3. **Verify credentials in application-integration.yml:**
   ```yaml
   spring:
     datasource:
       url: jdbc:mysql://localhost:3306/amazon_users_test
       username: mysql
       password: testpassword
   ```

---

### Issue: Tests Pass Locally But Fail in CI

**Cause:** CI environment doesn't have Vault/MySQL running.

**Solutions:**

1. **Use testcontainers in CI:**
   - Add Testcontainers dependency
   - Configure containers to start automatically

2. **Separate test profiles:**
   ```bash
   # Run only unit tests in CI
   mvn test -Dtest='*Test,!*IntegrationTest'
   
   # Run integration tests only when services available
   mvn test -Dtest=CucumberIntegrationTest -DskipTests=false
   ```

3. **Add integration test stage in CI pipeline** (optional)

---

## Differences from Unit Tests

| Aspect | Unit Tests (`CucumberTest`) | Integration Tests (`CucumberIntegrationTest`) |
|--------|----------------------------|-----------------------------------------------|
| **Profile** | `test` | `integration` |
| **Vault** | Disabled, mock pepper | Enabled, real Vault |
| **Database** | H2 in-memory | MySQL |
| **Speed** | Fast (~10s) | Slower (~30s+) |
| **Dependencies** | None | Vault, MySQL must be running |
| **Purpose** | Validate logic | Validate integration |
| **CI** | Always run | Optional/staged |

### When to Use Each

**Use Unit Tests (`CucumberTest`):**
- ✅ Quick feedback during development
- ✅ CI/CD pipeline (fast, no external dependencies)
- ✅ Validating business logic
- ✅ Testing edge cases and validation

**Use Integration Tests (`CucumberIntegrationTest`):**
- ✅ Before production deployment
- ✅ Verifying Vault integration works
- ✅ Testing with actual database
- ✅ End-to-end validation
- ✅ Debugging connection issues

---

## Test Configuration Files

### application-integration.yml
```yaml
spring:
  cloud:
    vault:
      enabled: true  # ← Real Vault connection
  datasource:
    url: jdbc:mysql://localhost:3306/amazon_users_test  # ← Real MySQL
```

### application-test.yml
```yaml
spring:
  cloud:
    vault:
      enabled: false  # ← Vault disabled
  datasource:
    url: jdbc:h2:mem:testdb  # ← In-memory H2
password_pepper: test-pepper-value-for-unit-tests  # ← Mock
```

---

## Running Both Test Suites

### Run Unit Tests Only
```bash
mvn test -Dtest=CucumberTest
```

### Run Integration Tests Only
```bash
VAULT_ADDR=http://localhost:8200 mvn test -Dtest=CucumberIntegrationTest
```

### Run All Tests
```bash
mvn test
```

### Run Tests in Sequence
```bash
# Fast feedback from unit tests first
mvn test -Dtest=CucumberTest && \
mvn test -Dtest=CucumberIntegrationTest
```

---

## Best Practices

### 1. Run Unit Tests First
Always run fast unit tests before slower integration tests.

### 2. Keep Integration Tests Minimal
Focus on verifying external integration, not re-testing business logic.

### 3. Use Separate Test Databases
Never run integration tests against production database.

### 4. Clean Up After Tests
```bash
# Stop port forwards
pkill -f "port-forward.*vault"
pkill -f "port-forward.*mysql"

# Clean test data
mysql -u mysql -p amazon_users_test -e "TRUNCATE TABLE users"
```

### 5. Document Prerequisites Clearly
Make it obvious what must be running for tests to pass.

---

## Related Documentation

- [BDD Testing Guide](./BDD_TESTING.md) - Unit test documentation
- [Vault Documentation](./VAULT.md) - Vault setup and configuration
- [MySQL Setup](../k8s/MYSQL_SETUP.md) - MySQL deployment guide

---

## Quick Reference

```bash
# Prerequisites
kubectl port-forward -n amazon-api svc/vault 8200:8200 &
kubectl port-forward -n amazon-api-dev svc/mysql 3306:3306 &

# Run integration tests
cd amazon-api-users
VAULT_ADDR=http://localhost:8200 mvn test -Dtest=CucumberIntegrationTest

# With custom env
VAULT_ADDR=http://localhost:8200 \
MYSQL_HOST=localhost \
mvn test -Dtest=CucumberIntegrationTest

# Check prerequisites
curl http://localhost:8200/v1/sys/health
mysql -h localhost -u mysql -p -e "SELECT 1"
```

---

**Last Updated:** 2026-01-06  
**Maintained By:** Development Team
