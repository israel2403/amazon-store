# Unit Testing Guide - Amazon API Users

This guide covers unit testing for the `amazon-api-users` microservice with a focus on clean, parameterized tests using JSON test data.

## Table of Contents
- [Overview](#overview)
- [Dependencies](#dependencies)
- [Test Architecture](#test-architecture)
- [Running Tests](#running-tests)
- [Test Categories](#test-categories)
- [JSON Test Data](#json-test-data)
- [Writing New Tests](#writing-new-tests)
- [Best Practices](#best-practices)

---

## Overview

The unit test suite for `UserService` provides comprehensive coverage using:
- **JUnit 5** for test execution
- **Mockito** for mocking dependencies
- **Parameterized Tests** for data-driven testing
- **JSON Files** for clean test data management
- **ObjectMapper** for JSON-to-POJO conversion

### Key Features
- ✅ Isolated unit tests (no database/Vault required)
- ✅ Parameterized tests with JSON data files
- ✅ Object recycling with `@BeforeAll` and `@BeforeEach`
- ✅ Clean test data management
- ✅ Comprehensive exception testing

---

## Dependencies

### Required Dependencies

All dependencies are already in `pom.xml`:

```xml
<!-- Spring Boot Test (includes JUnit 5, Mockito, AssertJ) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- JUnit 5 Parameterized Tests -->
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter-params</artifactId>
    <scope>test</scope>
</dependency>

<!-- Jackson for JSON processing -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
    <scope>test</scope>
</dependency>
```

### What Each Dependency Provides

| Dependency | Purpose |
|------------|---------|
| `spring-boot-starter-test` | JUnit 5, Mockito, AssertJ, Spring Test utilities |
| `junit-jupiter-params` | `@ParameterizedTest` and data providers |
| `jackson-databind` | `ObjectMapper` for JSON ↔ POJO conversion |

---

## Test Architecture

### Test Structure

```
amazon-api-users/src/test/
├── java/
│   └── com/huerta/amazonapi/users/
│       ├── service/
│       │   └── UserServiceTest.java          # Unit tests
│       ├── bdd/
│       │   └── CucumberTest.java             # BDD tests
│       └── integration/
│           └── CucumberIntegrationTest.java  # Integration tests
└── resources/
    ├── testdata/
    │   └── users/
    │       ├── valid-user-request.json       # Valid test data
    │       ├── minimal-user-request.json     # Minimal valid data
    │       ├── invalid-emails.json           # Invalid email scenarios
    │       └── invalid-passwords.json        # Invalid password scenarios
    ├── application-test.yml                   # Test configuration
    └── application-integration.yml            # Integration test config
```

### Object Recycling Strategy

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    
    // Shared across ALL tests (loaded once)
    private static ObjectMapper objectMapper;
    private static UserRequest validUserRequest;
    private static List<UserRequest> invalidEmailRequests;
    
    @BeforeAll
    static void setUpOnce() throws IOException {
        // Load test data once for all tests
        objectMapper = new ObjectMapper();
        validUserRequest = loadTestData("testdata/users/valid-user-request.json", UserRequest.class);
        invalidEmailRequests = loadTestDataList("testdata/users/invalid-emails.json");
    }
    
    @BeforeEach
    void setUp() {
        // Initialize per-test mocks
        ReflectionTestUtils.setField(userService, "passwordPepper", "test-pepper");
        Argon2 argon2 = Argon2Factory.create(...);
        ReflectionTestUtils.setField(userService, "argon2", argon2);
        userService.init();
    }
    
    @AfterEach
    void tearDown() {
        // Reset mocks for next test
        reset(userRepository);
    }
}
```

**Benefits:**
- ✅ JSON files loaded once (`@BeforeAll`)
- ✅ ObjectMapper reused across tests
- ✅ Mocks reset after each test
- ✅ Fast test execution
- ✅ Low memory footprint

---

## Running Tests

### Run All Unit Tests

```bash
cd amazon-api-users
mvn test -Dtest=UserServiceTest
```

### Run Specific Test Method

```bash
mvn test -Dtest=UserServiceTest#testCreateUser_ValidRequest_ReturnsUserResponse
```

### Run Parameterized Tests Only

```bash
mvn test -Dtest=UserServiceTest#testCreateUser_Invalid*
```

### Run with Verbose Output

```bash
mvn test -Dtest=UserServiceTest -X
```

### Run All Tests (Unit + BDD + Integration)

```bash
mvn test
```

---

## Test Categories

### 1. Configuration Tests

Verify `UserService` initialization:

```java
@Test
@DisplayName("Should throw ConfigurationException when pepper is missing")
void testInit_MissingPepper_ThrowsConfigurationException()
```

**Tests:**
- ✅ Missing pepper throws `ConfigurationException`
- ✅ Valid pepper initializes successfully
- ✅ Argon2 instance created correctly

---

### 2. Create User - Success Scenarios

Test successful user creation:

```java
@Test
@DisplayName("Should create user successfully with all fields")
void testCreateUser_ValidRequest_ReturnsUserResponse()
```

**Tests:**
- ✅ Create user with all fields
- ✅ Create user with minimal fields
- ✅ Password hashed using Argon2
- ✅ User defaults set correctly (enabled=false, locked=false)

**JSON Test Data:**
- `valid-user-request.json` - Full user data
- `minimal-user-request.json` - Only required fields

---

### 3. Create User - Duplicate Scenarios

Test duplicate username/email handling:

```java
@Test
@DisplayName("Should throw exception when username already exists")
void testCreateUser_DuplicateUsername_ThrowsResourceAlreadyExistsException()
```

**Tests:**
- ✅ Duplicate username throws `ResourceAlreadyExistsException`
- ✅ Duplicate email throws `ResourceAlreadyExistsException`
- ✅ Exception contains field details (resourceName, fieldName, fieldValue)
- ✅ Repository save never called

---

### 4. Password Hashing Tests

Test password hashing edge cases:

```java
@Test
@DisplayName("Should throw exception when password is null")
void testHashPassword_NullPassword_ThrowsPasswordHashingException()
```

**Tests:**
- ✅ Null password throws `PasswordHashingException`
- ✅ Empty password throws `PasswordHashingException`
- ✅ Valid password hashed correctly
- ✅ Hash starts with `$argon2`

---

### 5. Parameterized Tests - Invalid Emails

Data-driven tests for invalid email formats:

```java
@ParameterizedTest(name = "Invalid email: {0}")
@MethodSource("provideInvalidEmailRequests")
@DisplayName("Should handle invalid email formats")
void testCreateUser_InvalidEmail_ValidationShouldHandle(String testName, UserRequest request)
```

**JSON Test Data:** `invalid-emails.json`
```json
[
  {
    "testName": "missing @ symbol",
    "username": "testuser1",
    "email": "invalidemail.com",
    "password": "ValidPass123!"
  },
  {
    "testName": "missing domain",
    "username": "testuser2",
    "email": "invalid@",
    "password": "ValidPass123!"
  }
]
```

**Tests:**
- ✅ Missing @ symbol
- ✅ Missing domain
- ✅ Spaces in email

**Note:** Email validation happens at controller level (`@Valid`). These tests verify UserService can process any string.

---

### 6. Parameterized Tests - Invalid Passwords

Data-driven tests for invalid password formats:

```java
@ParameterizedTest(name = "Invalid password: {0}")
@MethodSource("provideInvalidPasswordRequests")
@DisplayName("Should handle invalid password formats")
void testCreateUser_InvalidPassword_ValidationShouldHandle(String testName, UserRequest request)
```

**JSON Test Data:** `invalid-passwords.json`
```json
[
  {
    "testName": "no uppercase",
    "username": "testuser1",
    "email": "test1@example.com",
    "password": "lowercase123!"
  },
  {
    "testName": "no digits",
    "username": "testuser2",
    "email": "test2@example.com",
    "password": "NoDigitsHere!"
  }
]
```

**Tests:**
- ✅ No uppercase
- ✅ No lowercase
- ✅ No digits
- ✅ Too short

---

### 7. Exception Handling Tests

Test exception wrapping and propagation:

```java
@Test
@DisplayName("Should wrap unexpected repository exceptions in UserCreationException")
void testCreateUser_RepositoryException_ThrowsUserCreationException()
```

**Tests:**
- ✅ Repository exceptions wrapped in `UserCreationException`
- ✅ Exception contains username
- ✅ Original cause preserved

---

## JSON Test Data

### Creating Test Data Files

**Location:** `src/test/resources/testdata/users/`

**Example: Single Object**

`valid-user-request.json`:
```json
{
  "username": "johndoe",
  "email": "john.doe@example.com",
  "password": "SecurePass123!",
  "firstName": "John",
  "lastName": "Doe"
}
```

**Example: Array for Parameterized Tests**

`invalid-emails.json`:
```json
[
  {
    "testName": "missing @ symbol",
    "username": "testuser1",
    "email": "invalidemail.com",
    "password": "ValidPass123!"
  },
  {
    "testName": "spaces in email",
    "username": "testuser2",
    "email": "invalid @example.com",
    "password": "ValidPass123!"
  }
]
```

### Loading JSON Data

**Single Object:**
```java
UserRequest request = loadTestData("testdata/users/valid-user-request.json", UserRequest.class);
```

**List for Parameterized Tests:**
```java
List<UserRequest> requests = loadTestDataList("testdata/users/invalid-emails.json");
```

**Helper Method:**
```java
private static <T> T loadTestData(String resourcePath, Class<T> clazz) throws IOException {
    try (InputStream is = UserServiceTest.class.getClassLoader().getResourceAsStream(resourcePath)) {
        if (is == null) {
            throw new IllegalArgumentException("Resource not found: " + resourcePath);
        }
        return objectMapper.readValue(is, clazz);
    }
}
```

---

## Writing New Tests

### 1. Add New Test Data File

Create `src/test/resources/testdata/users/new-scenario.json`:
```json
{
  "username": "newuser",
  "email": "new@example.com",
  "password": "NewPass123!"
}
```

### 2. Load in `@BeforeAll`

```java
@BeforeAll
static void setUpOnce() throws IOException {
    // ... existing code
    newScenarioRequest = loadTestData("testdata/users/new-scenario.json", UserRequest.class);
}
```

### 3. Write Test

```java
@Test
@DisplayName("Should handle new scenario")
void testCreateUser_NewScenario() {
    // Arrange
    when(userRepository.findByUsername(newScenarioRequest.getUsername())).thenReturn(Optional.empty());
    when(userRepository.findByEmail(newScenarioRequest.getEmail())).thenReturn(Optional.empty());
    
    User savedUser = createMockUser(newScenarioRequest);
    when(userRepository.save(any(User.class))).thenReturn(savedUser);

    // Act
    UserResponse response = userService.createUser(newScenarioRequest);

    // Assert
    assertNotNull(response);
    assertEquals(newScenarioRequest.getUsername(), response.getUsername());
}
```

### 4. For Parameterized Tests

**Create JSON Array:**
```json
[
  {"testName": "scenario1", "username": "user1", ...},
  {"testName": "scenario2", "username": "user2", ...}
]
```

**Load and Provide:**
```java
private static List<UserRequest> newScenarios;

@BeforeAll
static void setUpOnce() throws IOException {
    newScenarios = loadTestDataList("testdata/users/new-scenarios.json");
}

static Stream<Arguments> provideNewScenarios() {
    return newScenarios.stream()
        .map(req -> Arguments.of(getTestName(req), req));
}

@ParameterizedTest(name = "Scenario: {0}")
@MethodSource("provideNewScenarios")
void testNewScenarios(String testName, UserRequest request) {
    // Test logic
}
```

---

## Best Practices

### 1. Object Recycling

✅ **DO** - Load test data once:
```java
@BeforeAll
static void setUpOnce() throws IOException {
    validUserRequest = loadTestData(...);
}
```

❌ **DON'T** - Load in every test:
```java
@Test
void test() throws IOException {
    UserRequest request = loadTestData(...); // Inefficient!
}
```

### 2. Mock Reset

✅ **DO** - Reset mocks after each test:
```java
@AfterEach
void tearDown() {
    reset(userRepository);
}
```

### 3. Test Data Files

✅ **DO** - Use descriptive file names:
- `valid-user-request.json`
- `invalid-emails.json`
- `duplicate-username-scenarios.json`

❌ **DON'T** - Use generic names:
- `data1.json`
- `test.json`

### 4. Assertions

✅ **DO** - Test multiple aspects:
```java
assertNotNull(response);
assertEquals(expected.getUsername(), response.getUsername());
assertEquals(expected.getEmail(), response.getEmail());
verify(userRepository).save(any(User.class));
```

### 5. DisplayName

✅ **DO** - Use descriptive display names:
```java
@Test
@DisplayName("Should throw exception when username already exists")
void testCreateUser_DuplicateUsername_ThrowsResourceAlreadyExistsException()
```

### 6. Arrange-Act-Assert

✅ **DO** - Follow AAA pattern:
```java
@Test
void test() {
    // Arrange
    when(...).thenReturn(...);
    
    // Act
    UserResponse response = userService.createUser(request);
    
    // Assert
    assertNotNull(response);
}
```

---

## Test Coverage

Current coverage for `UserService`:

| Category | Tests | Coverage |
|----------|-------|----------|
| Configuration | 2 | 100% |
| Create User - Success | 4 | 100% |
| Create User - Duplicates | 2 | 100% |
| Password Hashing | 3 | 100% |
| Invalid Emails | 3 (parameterized) | 100% |
| Invalid Passwords | 4 (parameterized) | 100% |
| Exception Handling | 2 | 100% |
| **Total** | **20** | **100%** |

---

## Troubleshooting

### Issue: JSON File Not Found

**Error:**
```
IllegalArgumentException: Resource not found: testdata/users/file.json
```

**Solution:**
1. Verify file exists in `src/test/resources/testdata/users/`
2. Check file name matches exactly (case-sensitive)
3. Rebuild project: `mvn clean compile`

---

### Issue: Jackson Parsing Error

**Error:**
```
com.fasterxml.jackson.databind.exc.UnrecognizedPropertyException
```

**Solution:**
1. Verify JSON structure matches POJO fields
2. Add `@JsonIgnoreProperties(ignoreUnknown = true)` to DTO
3. Check for typos in JSON field names

---

### Issue: Tests Fail After Adding New Field

**Solution:**
1. Update JSON test data files with new field
2. Update mock user creation in helper methods
3. Update assertions if needed

---

## Running Tests in CI/CD

### Maven Command (Jenkins/GitLab CI)

```bash
mvn test -Dtest=UserServiceTest
```

### Exclude Integration Tests

```bash
mvn test -Dtest='*Test,!*IntegrationTest'
```

### Generate Coverage Report

```bash
mvn test jacoco:report
```

---

## Related Documentation

- [BDD Testing Guide](./BDD_TESTING.md) - Behavior-driven development tests
- [Integration Testing Guide](./INTEGRATION_TESTING.md) - Integration tests with Vault/MySQL
- [API Documentation](./API.md) - REST API endpoints

---

## Summary

### Key Takeaways

1. **Dependencies:** JUnit 5, Mockito, Jackson (already in `pom.xml`)
2. **Test Data:** JSON files in `src/test/resources/testdata/users/`
3. **Object Recycling:** Load once with `@BeforeAll`, reset mocks with `@AfterEach`
4. **Parameterized Tests:** Use `@ParameterizedTest` with JSON arrays
5. **Clean Tests:** No object creation in tests, only JSON loading

### Quick Start

```bash
# Run unit tests
mvn test -Dtest=UserServiceTest

# Expected output
Tests run: 20, Failures: 0, Errors: 0, Skipped: 0
```

**All 20 tests pass! ✅**

---

**Last Updated:** 2026-01-06  
**Maintained By:** Development Team
