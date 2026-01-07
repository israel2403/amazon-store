# Testcontainers Integration Guide

This guide covers the Testcontainers setup for integration tests, enabling tests to run anywhere without manual infrastructure setup.

## Overview

**Testcontainers** automatically starts Docker containers (MySQL, Vault) for integration tests. This follows industry best practices used by Netflix, Spotify, and many other companies.

### Benefits

✅ **No Manual Setup** - Tests start their own infrastructure  
✅ **Works Everywhere** - Local, CI/CD, developer machines  
✅ **Isolated** - Each test run uses fresh containers  
✅ **Fast** - Containers reused across test methods  
✅ **Reproducible** - Same environment every time  
✅ **CI-Friendly** - No need to configure Jenkins with external services

---

## Architecture

```
Integration Test
    ↓
CucumberIntegrationConfiguration
    ↓
TestcontainersConfiguration
    ├── MySQLContainer (automatic @ServiceConnection)
    ├── VaultContainer (with pre-seeded secrets)
    └── VaultInitializer (sets up pepper secret)
```

### What Gets Started

1. **MySQL Container** (`mysql:8.0`)
   - Database: `amazon_users_test`
   - User: `test` / Password: `test`
   - Automatically configured via `@ServiceConnection`

2. **Vault Container** (`hashicorp/vault:1.15`)
   - Dev mode with root token: `myroot`
   - Pre-seeded with password pepper
   - KV v2 secrets engine enabled

---

## Dependencies

All required dependencies are in `pom.xml`:

```xml
<!-- Spring Boot Testcontainers Support -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
</dependency>

<!-- Testcontainers Core -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>testcontainers</artifactId>
</dependency>

<!-- MySQL Container -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>mysql</artifactId>
</dependency>

<!-- Vault Container -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>vault</artifactId>
</dependency>

<!-- JUnit Jupiter Integration -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
</dependency>
```

---

## Running Tests

### Prerequisites

Only **Docker** is required:

```bash
# Check Docker is running
docker ps

# If not running
sudo systemctl start docker
```

### Run Integration Tests

```bash
cd amazon-api-users
mvn test -Dtest=CucumberIntegrationTest
```

**What happens:**
1. Testcontainers pulls Docker images (first time only)
2. Starts MySQL container
3. Starts Vault container
4. Initializes Vault with test secrets
5. Runs all 12 integration test scenarios
6. Containers automatically cleaned up

### Run All Tests

```bash
mvn test
```

This runs:
- 18 unit tests (no containers)
- 10 BDD tests (H2 in-memory)
- 12 integration tests (Testcontainers)

---

## Configuration

### TestcontainersConfiguration.java

```java
@TestConfiguration
public class TestcontainersConfiguration {
    
    @Bean
    @ServiceConnection  // Auto-configures datasource
    MySQLContainer<?> mysqlContainer() {
        return new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("amazon_users_test")
            .withUsername("test")
            .withPassword("test")
            .withReuse(true);  // Reuse for speed
    }
    
    @Bean
    GenericContainer<?> vaultContainer() {
        return new GenericContainer<>("hashicorp/vault:1.15")
            .withExposedPorts(8200)
            .withEnv("VAULT_DEV_ROOT_TOKEN_ID", "myroot")
            .withCommand("server", "-dev")
            .waitingFor(Wait.forHttp("/v1/sys/health"))
            .withReuse(true);
    }
}
```

### Container Reuse

Containers are reused across test methods for performance:

```java
.withReuse(true)
```

**Benefits:**
- First test: ~15s (container startup)
- Subsequent tests: ~3s (reuse existing)

To disable reuse:
```java
.withReuse(false)
```

---

## Vault Initialization

Vault is automatically initialized with test secrets:

```java
public class VaultInitializer {
    private void initializeVault() {
        // Enable KV v2
        vaultContainer.execInContainer(
            "vault", "secrets", "enable", "-version=2", "-path=kv", "kv"
        );
        
        // Store password pepper
        vaultContainer.execInContainer(
            "vault", "kv", "put", "kv/amazon-api/security",
            "password_pepper=testcontainers-pepper-value-for-integration-tests"
        );
    }
}
```

---

## CI/CD Integration

### Jenkins Pipeline

No changes needed! Testcontainers works automatically in Jenkins:

```groovy
stage('Test') {
    steps {
        sh 'mvn test'  // Integration tests work automatically
    }
}
```

**Requirements:**
- Jenkins agent must have Docker access
- Docker socket mounted: `/var/run/docker.sock`

### GitHub Actions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '21'
      - run: mvn test
```

Testcontainers works out-of-the-box on GitHub Actions!

---

## Troubleshooting

### Issue: Docker Not Found

**Error:**
```
Could not find a valid Docker environment
```

**Solution:**
```bash
# Check Docker is running
docker ps

# Start Docker
sudo systemctl start docker

# Verify Docker socket
ls -l /var/run/docker.sock
```

---

### Issue: Permission Denied

**Error:**
```
Permission denied while trying to connect to Docker daemon
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker
```

---

### Issue: Slow First Run

**Expected Behavior:**
First run downloads Docker images (~500MB total):
- `mysql:8.0` (~150MB)
- `hashicorp/vault:1.15` (~80MB)
- Testcontainers ryuk (~5MB)

**Solution:**
This is normal. Subsequent runs are fast (images cached).

---

### Issue: Port Already in Use

**Error:**
```
Port 8200 is already allocated
```

**Solution:**
```bash
# Find process using port
sudo lsof -i :8200

# Kill port forward if needed
pkill -f "port-forward.*vault"
```

Testcontainers uses random ports, so this is rare.

---

### Issue: Container Startup Timeout

**Error:**
```
Container startup failed
```

**Solution:**
1. Check Docker has enough resources:
   ```bash
   docker info | grep -i memory
   ```

2. Increase timeout in test:
   ```java
   .withStartupTimeout(Duration.ofSeconds(120))
   ```

---

## Advanced Configuration

### Custom MySQL Configuration

```java
@Bean
@ServiceConnection
MySQLContainer<?> mysqlContainer() {
    return new MySQLContainer<>("mysql:8.0")
        .withConfigurationOverride("mysql-config")  // Custom my.cnf
        .withInitScript("init.sql")                 // Init SQL script
        .withEnv("MYSQL_ROOT_PASSWORD", "rootpass");
}
```

### Custom Vault Secrets

```java
vaultContainer.execInContainer(
    "vault", "kv", "put", "kv/my-app/config",
    "key1=value1",
    "key2=value2"
);
```

### Network Configuration

```java
Network network = Network.newNetwork();

MySQLContainer<?> mysql = new MySQLContainer<>()
    .withNetwork(network)
    .withNetworkAliases("mysql");

GenericContainer<?> vault = new GenericContainer<>()
    .withNetwork(network)
    .withNetworkAliases("vault");
```

---

## Performance Tips

### 1. Enable Container Reuse

```java
.withReuse(true)
```

Also set environment variable:
```bash
export TESTCONTAINERS_REUSE_ENABLE=true
```

### 2. Use Lighter Images

```java
new MySQLContainer<>("mysql:8.0-slim")
```

### 3. Parallel Test Execution

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <parallel>classes</parallel>
        <threadCount>4</threadCount>
    </configuration>
</plugin>
```

### 4. Docker Layer Caching

Build images with proper layer caching:
```dockerfile
# Dependencies first (rarely change)
COPY pom.xml .
RUN mvn dependency:go-offline

# Code last (changes often)
COPY src/ .
```

---

## Comparison: Before vs After

### Before (Manual Infrastructure)

❌ Need to start MySQL manually  
❌ Need to start Vault manually  
❌ Need to seed Vault with secrets  
❌ Port conflicts between developers  
❌ CI requires infrastructure setup  
❌ Flaky tests due to shared state  

### After (Testcontainers)

✅ Everything automatic  
✅ Fresh containers per run  
✅ No port conflicts  
✅ Works in CI without setup  
✅ Isolated, reproducible tests  
✅ Fast with container reuse  

---

## Resources

- [Testcontainers Documentation](https://testcontainers.com/)
- [Spring Boot Testcontainers](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.testing.testcontainers)
- [Testcontainers MySQL Module](https://testcontainers.com/modules/mysql/)
- [Testcontainers Vault Module](https://testcontainers.com/modules/hashicorp-vault/)

---

## Summary

### Quick Commands

```bash
# Run integration tests
mvn test -Dtest=CucumberIntegrationTest

# Run all tests
mvn test

# Clean up containers
docker container prune -f
```

### Key Files

- `TestcontainersConfiguration.java` - Container definitions
- `CucumberIntegrationConfiguration.java` - Test configuration
- `application-integration.yml` - Spring configuration
- `pom.xml` - Testcontainers dependencies

---

**Last Updated:** 2026-01-07  
**Maintained By:** Development Team
