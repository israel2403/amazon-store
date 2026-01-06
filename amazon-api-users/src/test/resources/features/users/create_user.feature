Feature: Create users through the API
  As an API client
  I want to create users
  So that they can access the platform

  Scenario: Successfully create a new user with all fields
    Given a new user payload:
      | username | email              | password        | firstName | lastName | phone        |
      | johndoe  | john@example.com   | Sup3rS3cret!    | John      | Doe      | +1234567890  |
    When the client POSTs to "/users-api"
    Then the response status should be 201
    And the response should contain the created user with username "johndoe"
    And the user is persisted with email "john@example.com", enabled flag false, and emailVerified flag false
    And the password is securely hashed using Argon2

  Scenario: Successfully create a minimal user
    Given a new user payload:
      | username | email                | password         |
      | minuser  | minimal@example.com  | MinimalPass123!  |
    When the client POSTs to "/users-api"
    Then the response status should be 201
    And the response should contain the created user with username "minuser"
    And the user is persisted with email "minimal@example.com", enabled flag false, and emailVerified flag false

  Scenario: Reject duplicate usernames
    Given an existing user with username "dupuser" and email "dup@example.com"
    And a new user payload:
      | username | email               | password         |
      | dupuser  | another@example.com | AnotherPass123!  |
    When the client POSTs to "/users-api"
    Then the response status should be 409
    And the error message should contain "already exists"

  Scenario: Reject duplicate email addresses
    Given an existing user with username "existinguser" and email "shared@example.com"
    And a new user payload:
      | username  | email               | password          |
      | newuser   | shared@example.com  | NewUserPass123!   |
    When the client POSTs to "/users-api"
    Then the response status should be 409
    And the error message should contain "already exists"

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

  Scenario: Reject missing required fields
    Given a new user payload:
      | email               | password        |
      | test@example.com    | ValidPass123!   |
    When the client POSTs to "/users-api"
    Then the response status should be 400
