# Amazon API Users - Documentation

Comprehensive documentation for the `amazon-api-users` microservice.

## 📚 Documentation Index

### Testing Documentation

1. **[Unit Testing Guide](./UNIT_TESTING.md)**
   - Parameterized unit tests with JUnit 5
   - JSON-based test data management
   - Object recycling and best practices
   - 20 comprehensive tests for UserService
   - **Coverage:** 100%

2. **[BDD Testing Guide](./BDD_TESTING.md)**
   - Behavior-Driven Development with Cucumber
   - Gherkin feature files
   - 10 BDD scenarios for user creation
   - Running tests from command line

3. **[Integration Testing Guide](./INTEGRATION_TESTING.md)**
   - Tests with real Vault and MySQL
   - Vault pepper integration verification
   - 12 integration test scenarios
   - Setup and troubleshooting guide

### Quick Start

```bash
# Run unit tests
cd amazon-api-users
mvn test -Dtest=UserServiceTest

# Run BDD tests
mvn test -Dtest=CucumberTest

# Run integration tests (requires Vault + MySQL)
./run-integration-tests.sh
```

## Test Summary

| Test Type | Count | Duration | Dependencies |
|-----------|-------|----------|--------------|
| Unit Tests | 20 | ~2s | None |
| BDD Tests | 10 | ~10s | H2 in-memory |
| Integration Tests | 12 | ~15s | Vault + MySQL |
| **Total** | **42** | **~27s** | - |

## Architecture

### Service Layer
- **UserService** - Main business logic for user management
  - User creation with validation
  - Password hashing with Argon2 + pepper
  - Duplicate detection (username/email)
  - Exception handling

### Security
- **Password Hashing:** Argon2id with pepper from Vault
- **Pepper Storage:** HashiCorp Vault (`kv/amazon-api/security`)
- **Configuration Validation:** Fail-fast at startup

### Exception Handling
- `ConfigurationException` - Configuration errors
- `PasswordHashingException` - Password hashing failures
- `ResourceAlreadyExistsException` - Duplicate username/email
- `UserCreationException` - Unexpected creation errors

## Dependencies

### Core Dependencies
- Spring Boot 3.4.1
- Spring Data JPA
- Spring Cloud Vault Config 2023.0.5
- MySQL Connector 8.4.0
- Argon2 JVM 2.11

### Test Dependencies
- JUnit 5 (jupiter)
- Mockito
- Cucumber 7.16.1
- Jackson (JSON processing)
- H2 Database (in-memory)

## Development Workflow

1. **Write Unit Tests** → Test business logic in isolation
2. **Write BDD Tests** → Document behavior with Gherkin
3. **Write Integration Tests** → Verify external integrations
4. **Run All Tests** → Ensure everything works together

```bash
mvn test
```

## Contributing

When adding new features:
1. Write unit tests first (TDD)
2. Add BDD scenarios for user-facing behavior
3. Update integration tests if external systems affected
4. Update documentation

## Related Documentation

- [Vault Setup](../../k8s/VAULT.md)
- [MySQL Setup](../../k8s/MYSQL_SETUP.md)
- [Kubernetes Deployment](../../k8s/README.md)

---

**Last Updated:** 2026-01-06  
**Maintained By:** Development Team
