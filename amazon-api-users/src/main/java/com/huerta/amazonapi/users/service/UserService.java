package com.huerta.amazonapi.users.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import com.huerta.amazonapi.users.exception.ConfigurationException;
import com.huerta.amazonapi.users.exception.PasswordHashingException;
import com.huerta.amazonapi.users.exception.ResourceAlreadyExistsException;
import com.huerta.amazonapi.users.exception.UserCreationException;
import com.huerta.amazonapi.users.mappers.UserMapper;
import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.models.entity.User;
import com.huerta.amazonapi.users.repository.UserRepository;

import de.mkammerer.argon2.Argon2;
import de.mkammerer.argon2.Argon2Factory;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    // Argon2 configuration constants
    private static final int ARGON2_ITERATIONS = 3;
    private static final int ARGON2_MEMORY_KB = 65536; // 64MB
    private static final int ARGON2_PARALLELISM = 1;
    private static final int ARGON2_SALT_LENGTH = 16;
    private static final int ARGON2_HASH_LENGTH = 32;
    
    // Default user state constants
    private static final boolean DEFAULT_ENABLED = false;
    private static final boolean DEFAULT_EMAIL_VERIFIED = false;
    private static final boolean DEFAULT_LOCKED = false;

    private final UserRepository userRepository;
    
    @Value("${password_pepper:}")
    private String passwordPepper;
    
    // Reusable Argon2 instance (thread-safe)
    private Argon2 argon2;
    
    @PostConstruct
    public void init() {
        // Validate pepper at startup
        if (!StringUtils.hasText(this.passwordPepper)) {
            throw new ConfigurationException(
                "password_pepper",
                "Password pepper is not configured. Please check Vault configuration at 'kv/amazon-api/security'."
            );
        }
        log.info("Password pepper loaded successfully from Vault (length: {} chars)", this.passwordPepper.length());
        
        // Initialize reusable Argon2 instance
        try {
            this.argon2 = Argon2Factory.create(
                Argon2Factory.Argon2Types.ARGON2id, 
                ARGON2_SALT_LENGTH, 
                ARGON2_HASH_LENGTH
            );
            log.info("Argon2 password hasher initialized successfully");
        } catch (Exception e) {
            throw new ConfigurationException(
                "argon2",
                "Failed to initialize Argon2 password hasher",
                e
            );
        }
    }
    
    @PreDestroy
    public void cleanup() {
        // Clean up resources
        if (this.argon2 != null) {
            log.debug("Cleaning up Argon2 resources");
        }
    }

    public UserResponse createUser(UserRequest userRequest) {
        String username = userRequest.getUsername();
        String email = userRequest.getEmail();

        try {
            // Check for existing user
            this.userRepository.findByUsername(username)
                .ifPresent(user -> {
                    log.warn("Attempt to create duplicate username: {}", username);
                    throw new ResourceAlreadyExistsException("User", "username", username);
                });

            this.userRepository.findByEmail(email)
                .ifPresent(user -> {
                    log.warn("Attempt to create duplicate email: {}", email);
                    throw new ResourceAlreadyExistsException("User", "email", email);
                });

            // Build new user with defaults
            User newUser = UserMapper.fromUserRequestToUser.apply(userRequest);
            newUser.setEnabled(DEFAULT_ENABLED);
            newUser.setEmailVerified(DEFAULT_EMAIL_VERIFIED);
            newUser.setLocked(DEFAULT_LOCKED);

            // Hash password securely
            String hashedPassword = hashPassword(userRequest.getPassword());
            newUser.setPasswordHash(hashedPassword);

            // Save user
            User saved = this.userRepository.save(newUser);
            log.info("User created successfully: {} (ID: {})", username, saved.getId());
            
            return UserMapper.fromUserToUserResponse.apply(saved);
            
        } catch (ResourceAlreadyExistsException | PasswordHashingException e) {
            // Re-throw known exceptions
            throw e;
        } catch (Exception e) {
            // Wrap unexpected exceptions
            log.error("Unexpected error creating user: {}", username, e);
            throw new UserCreationException(username, "Unexpected error during user creation", e);
        }
    }

    /**
     * Hashes password using Argon2id with pepper.
     * 
     * @param rawPassword The plain text password
     * @return Argon2 hash string
     * @throws PasswordHashingException if hashing fails
     */
    private String hashPassword(String rawPassword) {
        if (rawPassword == null || rawPassword.isEmpty()) {
            throw new PasswordHashingException("Password cannot be null or empty");
        }
        
        // Convert to char array immediately to minimize time in memory as String
        char[] passwordChars = rawPassword.toCharArray();
        char[] passwordWithPepper = null;
        
        try {
            // Combine password with pepper
            String combined = new String(passwordChars) + this.passwordPepper;
            passwordWithPepper = combined.toCharArray();
            
            // Hash with Argon2id
            String hash = this.argon2.hash(
                ARGON2_ITERATIONS, 
                ARGON2_MEMORY_KB, 
                ARGON2_PARALLELISM, 
                passwordWithPepper
            );
            
            if (hash == null || hash.isEmpty()) {
                throw new PasswordHashingException("Argon2 returned null or empty hash");
            }
            
            log.debug("Password hashed successfully (hash length: {} chars)", hash.length());
            return hash;
            
        } catch (PasswordHashingException e) {
            throw e;
        } catch (Exception e) {
            log.error("Failed to hash password", e);
            throw new PasswordHashingException("Failed to hash password with Argon2", e);
        } finally {
            // Securely wipe sensitive data from memory
            if (passwordChars != null) {
                this.argon2.wipeArray(passwordChars);
            }
            if (passwordWithPepper != null) {
                this.argon2.wipeArray(passwordWithPepper);
            }
        }
    }
}
