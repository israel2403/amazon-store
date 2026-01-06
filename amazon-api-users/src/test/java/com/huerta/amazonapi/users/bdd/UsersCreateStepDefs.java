package com.huerta.amazonapi.users.bdd;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.models.entity.User;
import com.huerta.amazonapi.users.repository.UserRepository;
import com.huerta.amazonapi.users.service.UserService;

import io.cucumber.datatable.DataTable;
import io.cucumber.java.Before;
import io.cucumber.java.en.And;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

public class UsersCreateStepDefs {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserService userService;

    private UserRequest currentRequest;
    private MvcResult latestResult;

    @Before
    public void resetState() {
        userRepository.deleteAll();
        currentRequest = null;
        latestResult = null;
    }

    @Given("a new user payload:")
    public void aNewUserPayload(DataTable dataTable) {
        List<Map<String, String>> rows = dataTable.asMaps(String.class, String.class);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("User payload table must contain at least one row");
        }
        Map<String, String> row = rows.get(0);

        currentRequest = UserRequest.builder()
                .username(row.get("username"))
                .email(row.get("email"))
                .password(row.get("password"))
                .firstName(row.get("firstName"))
                .lastName(row.get("lastName"))
                .phone(row.get("phone"))
                .avatarUrl(row.get("avatarUrl"))
                .roles(parseRoles(row.get("roles")))
                .build();
    }

    @Given("an existing user with username {string} and email {string}")
    public void anExistingUserWithUsernameAndEmail(String username, String email) {
        UserRequest request = UserRequest.builder()
                .username(username)
                .email(email)
                .password("ExistingPass123!")
                .roles(Set.of("ROLE_USER"))
                .build();

        userService.createUser(request);
    }

    @When("the client POSTs to {string}")
    public void theClientPOSTsTo(String path) throws Exception {
        if (currentRequest == null) {
            throw new IllegalStateException("User payload has not been initialized");
        }

        latestResult = mockMvc.perform(
                post(path)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(currentRequest)))
                .andReturn();
    }

    @Then("the response status should be {int}")
    public void theResponseStatusShouldBe(int expectedStatus) {
        assertThat(latestResult).as("response not initialized").isNotNull();
        assertThat(latestResult.getResponse().getStatus()).isEqualTo(expectedStatus);
    }

    @Then("the response should contain the created user with username {string}")
    public void theResponseShouldContainTheCreatedUserWithUsername(String expectedUsername) throws Exception {
        UserResponse response = parseUserResponse();
        assertThat(response.getId()).as("id generated").isNotNull();
        assertThat(response.getUsername()).isEqualTo(expectedUsername);
    }

    @And("the user is persisted with email {string}, enabled flag false, and emailVerified flag false")
    public void theUserIsPersistedWithEmailEnabledFlagFalseAndEmailVerifiedFlagFalse(String expectedEmail) throws Exception {
        UserResponse response = parseUserResponse();
        Optional<User> persisted = userRepository.findById(response.getId());
        assertThat(persisted).isPresent();

        User user = persisted.get();
        assertThat(user.getEmail()).isEqualTo(expectedEmail);
        assertThat(user.isEnabled()).isFalse();
        assertThat(user.isEmailVerified()).isFalse();
        assertThat(user.getPasswordHash()).isNotBlank();
    }

    @Then("the error message should contain {string}")
    public void theErrorMessageShouldContain(String expectedMessage) throws Exception {
        assertThat(latestResult).isNotNull();
        String body = latestResult.getResponse().getContentAsString();
        JsonNode json = objectMapper.readTree(body);
        
        // Check main message
        String message = json.path("message").asText();
        
        // Also check details array for field-specific validation errors
        StringBuilder allMessages = new StringBuilder(message);
        if (json.has("details") && json.get("details").isArray()) {
            for (JsonNode detail : json.get("details")) {
                String field = detail.path("field").asText();
                String detailMessage = detail.path("message").asText();
                allMessages.append(" ").append(field).append(" ").append(detailMessage);
            }
        }
        
        // If message is still empty, try error field
        if (message.isEmpty()) {
            message = json.path("error").asText();
            allMessages.append(" ").append(message);
        }
        
        assertThat(allMessages.toString().toLowerCase())
                .as("Error response should mention %s. Full response: %s", expectedMessage, body)
                .contains(expectedMessage.toLowerCase());
    }

    @And("the password is securely hashed using Argon2")
    public void thePasswordIsSecurelyHashedUsingArgon2() throws Exception {
        UserResponse response = parseUserResponse();
        Optional<User> persisted = userRepository.findById(response.getId());
        assertThat(persisted).isPresent();

        User user = persisted.get();
        String passwordHash = user.getPasswordHash();
        
        // Argon2 hashes start with $argon2
        assertThat(passwordHash)
                .as("password should be hashed with Argon2")
                .isNotNull()
                .startsWith("$argon2");
        
        // Argon2 hash should be long (contains salt, hash, params)
        assertThat(passwordHash.length())
                .as("Argon2 hash should be substantial length")
                .isGreaterThan(50);
    }

    private UserResponse parseUserResponse() throws Exception {
        assertThat(latestResult).isNotNull();
        String responseBody = latestResult.getResponse().getContentAsString();
        return objectMapper.readValue(responseBody, UserResponse.class);
    }

    private Set<String> parseRoles(String roles) {
        if (roles == null || roles.isBlank()) {
            return null;
        }
        return Set.of(roles.split(","));
    }
}
