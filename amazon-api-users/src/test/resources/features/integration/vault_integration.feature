Feature: Vault Integration for Password Security
  As a security-conscious system
  I want to retrieve password pepper from Vault
  So that password hashing includes a secret pepper value

  Scenario: Successfully create user with Vault-provided pepper
    Given a new user payload:
      | username | email                 | password        |
      | vaultuser | vault@example.com    | VaultPass123!   |
    When the client POSTs to "/users-api"
    Then the response status should be 201
    And the response should contain the created user with username "vaultuser"
    And the password is securely hashed using Argon2
    And the password hash includes the Vault pepper

  Scenario: Password hashing uses different pepper than test mock
    Given a new user payload:
      | username  | email                | password        |
      | realuser  | real@example.com     | RealPass123!    |
    When the client POSTs to "/users-api"
    Then the response status should be 201
    And the password hash is different from test environment hash
