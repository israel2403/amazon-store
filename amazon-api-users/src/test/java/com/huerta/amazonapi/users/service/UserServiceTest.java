package com.huerta.amazonapi.users.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.io.IOException;
import java.io.InputStream;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.huerta.amazonapi.users.exception.ConfigurationException;
import com.huerta.amazonapi.users.exception.PasswordHashingException;
import com.huerta.amazonapi.users.exception.ResourceAlreadyExistsException;
import com.huerta.amazonapi.users.exception.UserCreationException;
import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.models.entity.User;
import com.huerta.amazonapi.users.repository.UserRepository;

import de.mkammerer.argon2.Argon2;
import de.mkammerer.argon2.Argon2Factory;

/**
 * Parameterized unit tests for UserService.
 * Uses JSON test data files for cleaner and more maintainable tests.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("UserService Unit Tests")
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    private static ObjectMapper objectMapper;
    private static UserRequest validUserRequest;
    private static UserRequest minimalUserRequest;

    // Test data for parameterized tests
    private static java.util.List<UserRequest> invalidEmailRequests;
    private static java.util.List<UserRequest> invalidPasswordRequests;

    @BeforeAll
    static void setUpOnce() throws IOException {
        objectMapper = new ObjectMapper();
        
        // Load valid user requests
        validUserRequest = loadTestData("testdata/users/valid-user-request.json", UserRequest.class);
        minimalUserRequest = loadTestData("testdata/users/minimal-user-request.json", UserRequest.class);
        
        // Load parameterized test data
        invalidEmailRequests = loadTestDataList("testdata/users/invalid-emails.json");
        invalidPasswordRequests = loadTestDataList("testdata/users/invalid-passwords.json");
    }

    @BeforeEach
    void setUp() {
        // Initialize UserService with test pepper
        ReflectionTestUtils.setField(userService, "passwordPepper", "test-pepper-value-for-unit-tests");
        
        // Initialize Argon2 instance
        Argon2 argon2 = Argon2Factory.create(Argon2Factory.Argon2Types.ARGON2id, 16, 32);
        ReflectionTestUtils.setField(userService, "argon2", argon2);
        
        // Call init to validate configuration
        userService.init();
    }

    @AfterEach
    void tearDown() {
        // Reset mocks
        reset(userRepository);
    }

    // ==================== Configuration Tests ====================

    @Test
    @DisplayName("Should throw ConfigurationException when pepper is missing")
    void testInit_MissingPepper_ThrowsConfigurationException() {
        // Arrange
        UserService serviceWithoutPepper = new UserService(userRepository);
        ReflectionTestUtils.setField(serviceWithoutPepper, "passwordPepper", "");

        // Act & Assert
        ConfigurationException exception = assertThrows(
            ConfigurationException.class,
            serviceWithoutPepper::init
        );
        
        assertEquals("password_pepper", exception.getConfigurationKey());
        assertTrue(exception.getMessage().contains("Password pepper is not configured"));
    }

    @Test
    @DisplayName("Should initialize successfully with valid pepper")
    void testInit_ValidPepper_InitializesSuccessfully() {
        // Act & Assert
        assertDoesNotThrow(() -> userService.init());
    }

    // ==================== Create User - Success Scenarios ====================

    @Test
    @DisplayName("Should create user successfully with all fields")
    void testCreateUser_ValidRequest_ReturnsUserResponse() {
        // Arrange
        when(userRepository.findByUsername(validUserRequest.getUsername())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(validUserRequest.getEmail())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(validUserRequest);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // Act
        UserResponse response = userService.createUser(validUserRequest);

        // Assert
        assertNotNull(response);
        assertEquals(validUserRequest.getUsername(), response.getUsername());
        assertNotNull(response.getId());
        
        verify(userRepository).findByUsername(validUserRequest.getUsername());
        verify(userRepository).findByEmail(validUserRequest.getEmail());
        verify(userRepository).save(any(User.class));
    }

    @Test
    @DisplayName("Should create user successfully with minimal fields")
    void testCreateUser_MinimalRequest_ReturnsUserResponse() {
        // Arrange
        when(userRepository.findByUsername(minimalUserRequest.getUsername())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(minimalUserRequest.getEmail())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(minimalUserRequest);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // Act
        UserResponse response = userService.createUser(minimalUserRequest);

        // Assert
        assertNotNull(response);
        assertEquals(minimalUserRequest.getUsername(), response.getUsername());
        assertNotNull(response.getId());
    }

    @Test
    @DisplayName("Should hash password using Argon2")
    void testCreateUser_HashesPasswordCorrectly() {
        // Arrange
        when(userRepository.findByUsername(anyString())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(validUserRequest);
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            // Verify password is hashed (Argon2 format starts with $argon2)
            assertTrue(user.getPasswordHash().startsWith("$argon2"));
            return savedUser;
        });

        // Act
        userService.createUser(validUserRequest);

        // Assert
        verify(userRepository).save(argThat(user -> 
            user.getPasswordHash() != null && 
            user.getPasswordHash().startsWith("$argon2")
        ));
    }

    // ==================== Create User - Duplicate Scenarios ====================

    @Test
    @DisplayName("Should throw exception when username already exists")
    void testCreateUser_DuplicateUsername_ThrowsResourceAlreadyExistsException() {
        // Arrange
        User existingUser = createMockUser(validUserRequest);
        when(userRepository.findByUsername(validUserRequest.getUsername())).thenReturn(Optional.of(existingUser));

        // Act & Assert
        ResourceAlreadyExistsException exception = assertThrows(
            ResourceAlreadyExistsException.class,
            () -> userService.createUser(validUserRequest)
        );
        
        assertEquals("User", exception.getResourceName());
        assertEquals("username", exception.getFieldName());
        assertEquals(validUserRequest.getUsername(), exception.getFieldValue());
        assertTrue(exception.getMessage().contains("username"));
        
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    @DisplayName("Should throw exception when email already exists")
    void testCreateUser_DuplicateEmail_ThrowsResourceAlreadyExistsException() {
        // Arrange
        when(userRepository.findByUsername(validUserRequest.getUsername())).thenReturn(Optional.empty());
        
        User existingUser = createMockUser(validUserRequest);
        when(userRepository.findByEmail(validUserRequest.getEmail())).thenReturn(Optional.of(existingUser));

        // Act & Assert
        ResourceAlreadyExistsException exception = assertThrows(
            ResourceAlreadyExistsException.class,
            () -> userService.createUser(validUserRequest)
        );
        
        assertEquals("User", exception.getResourceName());
        assertEquals("email", exception.getFieldName());
        assertEquals(validUserRequest.getEmail(), exception.getFieldValue());
        assertTrue(exception.getMessage().contains("email"));
        
        verify(userRepository, never()).save(any(User.class));
    }

    // ==================== Password Hashing Tests ====================

    @Test
    @DisplayName("Should throw exception when password is null")
    void testHashPassword_NullPassword_ThrowsPasswordHashingException() {
        // Arrange
        UserRequest requestWithNullPassword = new UserRequest();
        requestWithNullPassword.setUsername("testuser");
        requestWithNullPassword.setEmail("test@example.com");
        requestWithNullPassword.setPassword(null);
        
        when(userRepository.findByUsername(anyString())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());

        // Act & Assert
        assertThrows(
            PasswordHashingException.class,
            () -> userService.createUser(requestWithNullPassword)
        );
    }

    @Test
    @DisplayName("Should throw exception when password is empty")
    void testHashPassword_EmptyPassword_ThrowsPasswordHashingException() {
        // Arrange
        UserRequest requestWithEmptyPassword = new UserRequest();
        requestWithEmptyPassword.setUsername("testuser");
        requestWithEmptyPassword.setEmail("test@example.com");
        requestWithEmptyPassword.setPassword("");
        
        when(userRepository.findByUsername(anyString())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());

        // Act & Assert
        assertThrows(
            PasswordHashingException.class,
            () -> userService.createUser(requestWithEmptyPassword)
        );
    }

    // ==================== Parameterized Tests - Invalid Emails ====================

    @ParameterizedTest(name = "Invalid email: {0}")
    @MethodSource("provideInvalidEmailRequests")
    @DisplayName("Should handle invalid email formats")
    void testCreateUser_InvalidEmail_ValidationShouldHandle(String testName, UserRequest request) {
        // Note: This test verifies that UserService can process the request
        // Actual validation is done at the controller level with @Valid annotation
        
        // Arrange
        when(userRepository.findByUsername(request.getUsername())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(request);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // Act & Assert
        // UserService itself doesn't validate email format (that's done by @Valid)
        // This test ensures the service can handle various email strings
        assertDoesNotThrow(() -> userService.createUser(request));
    }

    static Stream<Arguments> provideInvalidEmailRequests() {
        return invalidEmailRequests.stream()
            .map(req -> Arguments.of(getTestName(req), req));
    }

    // ==================== Parameterized Tests - Invalid Passwords ====================

    @ParameterizedTest(name = "Invalid password: {0}")
    @MethodSource("provideInvalidPasswordRequests")
    @DisplayName("Should handle invalid password formats")
    void testCreateUser_InvalidPassword_ValidationShouldHandle(String testName, UserRequest request) {
        // Note: Password validation is done at controller level
        // This test verifies UserService can hash any string password
        
        // Arrange
        when(userRepository.findByUsername(request.getUsername())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(request);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // Act & Assert
        assertDoesNotThrow(() -> userService.createUser(request));
    }

    static Stream<Arguments> provideInvalidPasswordRequests() {
        return invalidPasswordRequests.stream()
            .map(req -> Arguments.of(getTestName(req), req));
    }

    // ==================== Exception Handling Tests ====================

    @Test
    @DisplayName("Should wrap unexpected repository exceptions in UserCreationException")
    void testCreateUser_RepositoryException_ThrowsUserCreationException() {
        // Arrange
        when(userRepository.findByUsername(anyString())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenThrow(new RuntimeException("Database error"));

        // Act & Assert
        UserCreationException exception = assertThrows(
            UserCreationException.class,
            () -> userService.createUser(validUserRequest)
        );
        
        assertEquals(validUserRequest.getUsername(), exception.getUsername());
        assertTrue(exception.getMessage().contains("Failed to create user"));
    }

    @Test
    @DisplayName("Should set user defaults correctly")
    void testCreateUser_SetsDefaultValues() {
        // Arrange
        when(userRepository.findByUsername(anyString())).thenReturn(Optional.empty());
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());
        
        User savedUser = createMockUser(validUserRequest);
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            // Verify defaults are set
            assertFalse(user.isEnabled());
            assertFalse(user.isEmailVerified());
            assertFalse(user.isLocked());
            return savedUser;
        });

        // Act
        userService.createUser(validUserRequest);

        // Assert
        verify(userRepository).save(argThat(user ->
            !user.isEnabled() && 
            !user.isEmailVerified() && 
            !user.isLocked()
        ));
    }

    // ==================== Helper Methods ====================

    private static <T> T loadTestData(String resourcePath, Class<T> clazz) throws IOException {
        try (InputStream is = UserServiceTest.class.getClassLoader().getResourceAsStream(resourcePath)) {
            if (is == null) {
                throw new IllegalArgumentException("Resource not found: " + resourcePath);
            }
            return objectMapper.readValue(is, clazz);
        }
    }

    private static java.util.List<UserRequest> loadTestDataList(String resourcePath) throws IOException {
        try (InputStream is = UserServiceTest.class.getClassLoader().getResourceAsStream(resourcePath)) {
            if (is == null) {
                throw new IllegalArgumentException("Resource not found: " + resourcePath);
            }
            return objectMapper.readValue(is, new TypeReference<java.util.List<UserRequest>>() {});
        }
    }

    private static String getTestName(UserRequest request) {
        // Extracts test name from the JSON (if it has a testName field)
        // For simplicity, using username as identifier
        return request.getUsername();
    }

    private User createMockUser(UserRequest request) {
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setPasswordHash("$argon2id$v=19$m=65536,t=3,p=1$mockSalt$mockHash");
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        user.setEnabled(false);
        user.setEmailVerified(false);
        user.setLocked(false);
        return user;
    }
}
