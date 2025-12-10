# Test Suite Documentation

This directory contains unit tests and integration tests for the Amazon Store API project.

## Java Unit Tests

### OrderController Tests
**Location:** `amazonapi-orders/src/test/java/com/huerta/amazonapi/orders/controller/OrderControllerTest.java`

Tests the OrderController REST endpoints:

1. **`create_shouldCreateOrderAndReturnWithCreatedStatus()`**
   - Verifies that OrderController.create() correctly creates an order
   - Checks that the response has HTTP 201 (CREATED) status
   - Validates that the returned order contains the correct data

2. **`getAll_shouldReturnAllOrders()`**
   - Verifies that OrderController.getAll() returns all existing orders
   - Tests with multiple orders in the system
   - Validates that all orders are returned with correct data

3. **`getAll_shouldReturnEmptyListWhenNoOrdersExist()`**
   - Verifies that OrderController.getAll() returns an empty list when no orders exist
   - Ensures graceful handling of empty state

**Run tests:**
```bash
./amazonapi-orders/gradlew test --tests OrderControllerTest -p amazonapi-orders
```

### OrderService Tests
**Location:** `amazonapi-orders/src/test/java/com/huerta/amazonapi/orders/service/OrderServiceImplTest.java`

Tests the OrderService business logic:

1. **`update_shouldReturnEmptyMonoWhenOrderDoesNotExist()`**
   - Verifies that OrderService.update() returns an empty Mono for non-existent orders
   - Tests the reactive flow completes without errors

2. **`update_shouldNotThrowExceptionWhenUpdatingNonExistentOrder()`**
   - Verifies that OrderService.update() gracefully handles attempts to update non-existent orders
   - Ensures no exceptions are thrown
   - Confirms the service returns an empty result instead of failing

**Run tests:**
```bash
./amazonapi-orders/gradlew test --tests OrderServiceImplTest -p amazonapi-orders
```

**Run all Java tests:**
```bash
./amazonapi-orders/gradlew test -p amazonapi-orders
```

## Shell Script Tests

### Vault Setup Tests
**Location:** `tests/test-setup-vault.sh`

Tests that `setup-vault.sh` successfully populates Vault with all defined environment variables.

**Test Cases:**

1. **`.env file validation`**
   - Verifies the script detects missing .env file
   - Ensures proper error message is displayed

2. **`Required variables validation`**
   - Verifies the script validates all required environment variables
   - Tests with incomplete .env file
   - Confirms script reports missing variables

3. **`Vault environment variables population`**
   - Verifies all required secrets are populated in Vault:
     - DockerHub credentials (username, token)
     - GitHub credentials (username, token)
     - Jenkins credentials (admin_user, admin_password)
     - PostgreSQL credentials (database, username, password)
   - Requires Vault container to be running

4. **`Script execution`**
   - Verifies setup-vault.sh completes successfully
   - Checks for success message

**Run tests:**
```bash
./tests/test-setup-vault.sh
```

**Prerequisites:**
- Vault container must be running: `docker compose up -d vault`
- `.env` file must exist with proper values

### Jenkinsfile Vault Integration Tests
**Location:** `tests/test-jenkinsfile-vault.sh`

Tests that the Orders service Jenkinsfile retrieves DockerHub credentials from Vault and uses them for Docker operations.

**Test Cases:**

1. **`Vault secret loading`**
   - Verifies Jenkinsfile contains withVault block
   - Confirms DockerHub secret path is configured

2. **`DockerHub credentials retrieval`**
   - Verifies DOCKERHUB_USERNAME environment variable is configured
   - Verifies DOCKERHUB_TOKEN environment variable is configured
   - Confirms vault keys (username, token) are properly mapped

3. **`Docker operations`**
   - Verifies docker login uses DOCKERHUB_USERNAME and DOCKERHUB_TOKEN
   - Confirms docker build command exists
   - Verifies docker push uses DOCKERHUB_USERNAME in image name
   - Checks docker logout for security best practice

4. **`loadVaultSecrets() function`**
   - Verifies function is defined
   - Confirms function is called
   - Checks that secrets are loaded in dedicated stage

5. **`Security best practices`**
   - Verifies no hardcoded credentials
   - Confirms --password-stdin is used for secure credential input

**Run tests:**
```bash
./tests/test-jenkinsfile-vault.sh
```

**Prerequisites:**
- None (tests only check Jenkinsfile content)

## Test Summary

### Coverage

✅ **OrderController.create()** - Creates order and returns 201 status  
✅ **OrderController.getAll()** - Returns all orders or empty list  
✅ **OrderService.update()** - Gracefully handles non-existent orders  
✅ **setup-vault.sh** - Populates Vault with all environment variables  
✅ **Jenkinsfile** - Retrieves and uses DockerHub credentials from Vault

### Running All Tests

```bash
# Java tests
./amazonapi-orders/gradlew test -p amazonapi-orders

# Shell script tests
./tests/test-setup-vault.sh
./tests/test-jenkinsfile-vault.sh
```

## Technologies Used

- **JUnit 5** - Java testing framework
- **Mockito** - Mocking framework for Java
- **Reactor Test** - Testing utilities for reactive streams
- **AssertJ** - Fluent assertions for Java
- **Bash** - Shell scripting for integration tests
