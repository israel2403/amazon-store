# BDD Testing Guide

Behavior-Driven Development (BDD) testing documentation for the Amazon Store microservices.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Running BDD Tests](#running-bdd-tests)
- [Test Structure](#test-structure)
- [User Creation Scenarios](#user-creation-scenarios)
- [Understanding Test Results](#understanding-test-results)
- [Writing New Scenarios](#writing-new-scenarios)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Amazon Store project uses **Cucumber** for BDD testing with **JUnit Platform** integration. Tests are written in Gherkin syntax (`.feature` files) and executed using step definitions in Java.

### Why BDD?

- ✅ **Living Documentation** - Feature files serve as executable specifications
- ✅ **Business-Readable** - Non-technical stakeholders can understand test scenarios
- ✅ **Test-First Development** - Define behavior before implementation
- ✅ **Comprehensive Coverage** - Scenario outlines enable data-driven testing

### Technology Stack

- **Cucumber**: 7.16.1
- **JUnit Platform**: 6.0.1
- **Spring Boot Test**: 3.4.1
- **AssertJ**: For fluent assertions
- **H2 Database**: In-memory database for tests

---

## Prerequisites

Before running BDD tests, ensure you have:

1. **Java 21** installed
   ```bash
   java -version  # Should show version 21
   ```

2. **Maven** installed
   ```bash
   mvn -version
   ```

3. Navigate to the service directory:
   ```bash
   cd amazon-api-users
   ```

---

## Running BDD Tests

### Run All BDD Tests

```bash
mvn test -Dtest=CucumberTest
```

### Run All Tests (Including Unit Tests)

```bash
mvn test
```

### Run Tests with Verbose Output

```bash
mvn test -Dtest=CucumberTest -X
```

### Run Specific Feature File

```bash
mvn test -Dtest=CucumberTest -Dcucumber.filter.tags="@create_user"
```

### Generate HTML Report

```bash
mvn test -Dtest=CucumberTest
# Report will be in target/cucumber-reports/
```

### Clean and Test

```bash
mvn clean test -Dtest=CucumberTest
```

---

## Test Structure

```
amazon-api-users/
├── src/
│   └── test/
│       ├── java/
│       │   └── com/huerta/amazonapi/users/bdd/
│       │       ├── CucumberTest.java              # Test runner
│       │       ├── CucumberSpringConfiguration.java # Spring context
│       │       └── UsersCreateStepDefs.java       # Step definitions
│       └── resources/
│           ├── features/
│           │   └── users/
│           │       └── create_user.feature        # Feature scenarios
│           └── application-test.yml               # Test configuration
```

### Key Files

#### `CucumberTest.java`
```java
@Suite
@IncludeEngines("cucumber")
@SelectClasspathResource("features")
@ConfigurationParameter(key = GLUE_PROPERTY_NAME, value = "com.huerta.amazonapi.users.bdd")
public class CucumberTest {}
```
- JUnit Platform suite configuration
- Points to feature files location
- Specifies step definitions package

#### `CucumberSpringConfiguration.java`
```java
@CucumberContextConfiguration
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class CucumberSpringConfiguration {}
```
- Integrates Cucumber with Spring Boot
- Activates test profile (H2 database, disabled Vault)
- Configures MockMvc for HTTP testing

#### `UsersCreateStepDefs.java`
- Contains step definitions (Given, When, Then)
- Uses MockMvc to simulate HTTP requests
- Validates responses and database state

---

## User Creation Scenarios

### Feature File: `create_user.feature`

#### Scenario 1: Successfully Create User with All Fields

```gherkin
Scenario: Successfully create a new user with all fields
  Given a new user payload:
    | username | email              | password        | firstName | lastName | phone        |
    | johndoe  | john@example.com   | Sup3rS3cret!    | John      | Doe      | +1234567890  |
  When the client POSTs to "/users-api"
  Then the response status should be 201
  And the response should contain the created user with username "johndoe"
  And the user is persisted with email "john@example.com", enabled flag false, and emailVerified flag false
  And the password is securely hashed using Argon2
```

**What it tests:**
- ✅ User creation with all optional fields
- ✅ 201 Created response
- ✅ Correct user data returned
- ✅ User stored in database
- ✅ Password hashed with Argon2id
- ✅ Account starts disabled and unverified

---

#### Scenario 2: Successfully Create Minimal User

```gherkin
Scenario: Successfully create a minimal user
  Given a new user payload:
    | username | email                | password         |
    | minuser  | minimal@example.com  | MinimalPass123!  |
  When the client POSTs to "/users-api"
  Then the response status should be 201
  And the response should contain the created user with username "minuser"
  And the user is persisted with email "minimal@example.com", enabled flag false, and emailVerified flag false
```

**What it tests:**
- ✅ User creation with only required fields
- ✅ Optional fields can be omitted

---

#### Scenario 3: Reject Duplicate Usernames

```gherkin
Scenario: Reject duplicate usernames
  Given an existing user with username "dupuser" and email "dup@example.com"
  And a new user payload:
    | username | email               | password         |
    | dupuser  | another@example.com | AnotherPass123!  |
  When the client POSTs to "/users-api"
  Then the response status should be 409
  And the error message should contain "already exists"
```

**What it tests:**
- ✅ Duplicate username detection
- ✅ 409 Conflict response
- ✅ Meaningful error message

---

#### Scenario 4: Reject Duplicate Email Addresses

```gherkin
Scenario: Reject duplicate email addresses
  Given an existing user with username "existinguser" and email "shared@example.com"
  And a new user payload:
    | username  | email               | password          |
    | newuser   | shared@example.com  | NewUserPass123!   |
  When the client POSTs to "/users-api"
  Then the response status should be 409
  And the error message should contain "already exists"
```

**What it tests:**
- ✅ Duplicate email detection
- ✅ 409 Conflict response

---

#### Scenario Outline 5: Reject Invalid Passwords

```gherkin
Scenario Outline: Reject invalid passwords
  Given a new user payload:
    | username   | email                  | password   |
    | testuser   | test@example.com       | <password> |
  When the client POSTs to "/users-api"
  Then the response status should be 400
  And the error message should contain "<error_message>"

  Examples:
    | password  | error_message |
    | short     | password      |
    | 12345678  | password      |
```

**What it tests:**
- ✅ Password must be at least 8 characters
- ✅ Password must contain uppercase, lowercase, and digit
- ✅ 400 Bad Request for validation errors
- ✅ Data-driven testing with multiple examples

---

#### Scenario Outline 6: Reject Invalid Email Formats

```gherkin
Scenario Outline: Reject invalid email formats
  Given a new user payload:
    | username   | email         | password        |
    | testuser   | <email>       | ValidPass123!   |
  When the client POSTs to "/users-api"
  Then the response status should be 400
  And the error message should contain "email"

  Examples:
    | email           |
    | invalid         |
    | @example.com    |
    | user@           |
```

**What it tests:**
- ✅ Email format validation
- ✅ Various invalid email patterns
- ✅ 400 Bad Request response

---

#### Scenario 7: Reject Missing Required Fields

```gherkin
Scenario: Reject missing required fields
  Given a new user payload:
    | email               | password        |
    | test@example.com    | ValidPass123!   |
  When the client POSTs to "/users-api"
  Then the response status should be 400
```

**What it tests:**
- ✅ Username is required
- ✅ 400 Bad Request when required field missing

---

## Understanding Test Results

### Successful Test Run

```
[INFO] Tests run: 10, Failures: 0, Errors: 0, Skipped: 0

Scenario: Successfully create a new user with all fields              ✅
Scenario: Successfully create a minimal user                          ✅
Scenario: Reject duplicate usernames                                  ✅
Scenario: Reject duplicate email addresses                            ✅
Scenario Outline: Reject invalid passwords - Example #1              ✅
Scenario Outline: Reject invalid passwords - Example #2              ✅
Scenario Outline: Reject invalid email formats - Example #1          ✅
Scenario Outline: Reject invalid email formats - Example #2          ✅
Scenario Outline: Reject invalid email formats - Example #3          ✅
Scenario: Reject missing required fields                             ✅

[INFO] BUILD SUCCESS
```

### Failed Test Example

```
Scenario: Reject duplicate usernames                                 ❌
  Given an existing user with username "dupuser" and email "dup@example.com"
  And a new user payload:
    | username | email               | password         |
    | dupuser  | another@example.com | AnotherPass123!  |
  When the client POSTs to "/users-api"
  Then the response status should be 409                             ❌
      expected: 409 but was: 201

java.lang.AssertionError: expected: 409 but was: 201
    at UsersCreateStepDefs.theResponseStatusShouldBe(UsersCreateStepDefs.java:103)
```

**Reading the output:**
- `❌` indicates the failing step
- Shows actual vs expected values
- Points to exact line in step definition
- Helps identify what went wrong

---

## Writing New Scenarios

### Basic Template

```gherkin
Feature: [Feature Name]
  As a [role]
  I want to [action]
  So that [benefit]

  Scenario: [Scenario Name]
    Given [precondition]
    When [action]
    Then [expected result]
    And [additional assertion]
```

### Example: Add New Scenario

1. **Add to feature file** (`create_user.feature`):

```gherkin
Scenario: Successfully update user profile
  Given an existing user with username "john" and email "john@example.com"
  And an update payload:
    | firstName | lastName |
    | Johnny    | Doe      |
  When the client PUTs to "/users-api/john"
  Then the response status should be 200
  And the user's firstName should be "Johnny"
```

2. **Add step definitions** (`UsersCreateStepDefs.java`):

```java
@When("the client PUTs to {string}")
public void theClientPUTsTo(String path) throws Exception {
    latestResult = mockMvc.perform(
            put(path)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(currentRequest)))
            .andReturn();
}

@Then("the user's firstName should be {string}")
public void theUsersFirstNameShouldBe(String expectedFirstName) throws Exception {
    UserResponse response = parseUserResponse();
    assertThat(response.getFirstName()).isEqualTo(expectedFirstName);
}
```

### Using Scenario Outlines

**When to use:**
- Testing multiple similar inputs
- Validation testing with various invalid values
- Boundary testing

**Example:**

```gherkin
Scenario Outline: Test various username formats
  Given a new user payload with username "<username>"
  When the client POSTs to "/users-api"
  Then the response status should be <status>

  Examples:
    | username      | status |
    | validuser     | 201    |
    | ab            | 400    |  # Too short
    | user@invalid  | 400    |  # Invalid chars
```

---

## Troubleshooting

### Issue: Tests fail with "Cannot load ApplicationContext"

**Cause:** H2 database or test profile not properly configured.

**Solution:**
```bash
# Verify application-test.yml exists
ls -la src/test/resources/application-test.yml

# Check H2 dependency in pom.xml
mvn dependency:tree | grep h2
```

---

### Issue: "Vault connection refused" during tests

**Cause:** Tests trying to connect to Vault (which is disabled in tests).

**Solution:** Verify `application-test.yml` contains:
```yaml
spring:
  cloud:
    vault:
      enabled: false
```

---

### Issue: Step definition not found

**Cause:** Glue path mismatch or missing `@CucumberContextConfiguration`.

**Solution:**
```java
// In CucumberTest.java
@ConfigurationParameter(
    key = GLUE_PROPERTY_NAME, 
    value = "com.huerta.amazonapi.users.bdd"  // ← Must match package
)
```

---

### Issue: Tests pass locally but fail in Jenkins

**Cause:** Different Spring Boot version or missing dependencies.

**Solution:**
```bash
# Check Jenkins uses same Java version
mvn -version

# Ensure clean build
mvn clean test -Dtest=CucumberTest
```

---

## Best Practices

### 1. Keep Scenarios Independent
- Each scenario should set up its own data
- Use `@Before` hook to reset state between scenarios

### 2. Use Descriptive Scenario Names
```gherkin
✅ Good: "Reject invalid email formats"
❌ Bad: "Test email validation"
```

### 3. Follow Given-When-Then Structure
- **Given**: Set up preconditions
- **When**: Perform action
- **Then**: Assert expected outcome

### 4. Use Background for Common Steps
```gherkin
Feature: User Management

  Background:
    Given the database is empty
    And default test data is loaded

  Scenario: Create user
    Given a new user payload...
```

### 5. Keep Step Definitions Reusable
```java
// ✅ Good - reusable
@Then("the response status should be {int}")
public void theResponseStatusShouldBe(int status) { ... }

// ❌ Bad - too specific
@Then("the create user response status should be 201")
public void theCreateUserResponseStatusShouldBe201() { ... }
```

---

## Related Documentation

- [Testing Strategy](./TESTING.md) - Overall testing approach
- [API Documentation](../amazon-api-users/README.md) - API endpoints
- [Cucumber Documentation](https://cucumber.io/docs/cucumber/) - Official Cucumber docs

---

## Quick Reference

```bash
# Run all BDD tests
mvn test -Dtest=CucumberTest

# Run with specific tag
mvn test -Dcucumber.filter.tags="@smoke"

# Generate report
mvn test -Dtest=CucumberTest -Dcucumber.plugin=html:target/cucumber-reports.html

# Run in parallel (if configured)
mvn test -Dtest=CucumberTest -Dparallel=4

# Debug mode
mvn test -Dtest=CucumberTest -X
```

---

**Last Updated:** 2026-01-06  
**Maintained By:** Development Team
