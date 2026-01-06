package com.huerta.amazonapi.users.service;

import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import com.huerta.amazonapi.users.exception.ResourceAlreadyExistsException;
import com.huerta.amazonapi.users.mappers.UserMapper;
import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.models.entity.User;
import com.huerta.amazonapi.users.repository.UserRepository;

import de.mkammerer.argon2.Argon2;
import de.mkammerer.argon2.Argon2Factory;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class UserService {

    private static final int ARGON2_ITERATIONS = 3;
    private static final int ARGON2_MEMORY_KB = 65536; // 64MB
    private static final int ARGON2_PARALLELISM = 1;
    private static final int ARGON2_SALT_LENGTH = 16;
    private static final int ARGON2_HASH_LENGTH = 32;

    private final UserRepository userRepository;
    @Value("${password_pepper:}")
    private String passwordPepper;

    public UserResponse createUser(UserRequest  userRequest){

        String username = userRequest.getUsername();
        String email = userRequest.getEmail();

        Optional<User> byUsername = this.userRepository.findByUsername(username);
        Optional<User> byEmail = this.userRepository.findByEmail(email);

        if (byUsername.isPresent()) {
            throw new ResourceAlreadyExistsException("User", "username", username);
        } 

        if (byEmail.isPresent()) {
            throw new ResourceAlreadyExistsException("User", "email", email);
        }

        boolean isEnabled = false;
        boolean isEmailVerified = false;
        
        User newUser = UserMapper.fromUserRequestToUser.apply(userRequest);
        newUser.setEnabled(isEnabled);
        newUser.setEmailVerified(isEmailVerified);
        newUser.setLocked(false);

        String hashedPassword = hashPassword(userRequest.getPassword());
        newUser.setPasswordHash(hashedPassword);

        User saved = this.userRepository.save(newUser);
        return UserMapper.fromUserToUserResponse.apply(saved);
    }

    private String hashPassword(String rawPassword) {
        if (!StringUtils.hasText(this.passwordPepper)) {
            throw new IllegalStateException("Password pepper is not configured");
        }

        Argon2 argon2 = Argon2Factory.create(Argon2Factory.Argon2Types.ARGON2id, ARGON2_SALT_LENGTH, ARGON2_HASH_LENGTH);
        char[] passwordWithPepper = (rawPassword + this.passwordPepper).toCharArray();
        try {
            return argon2.hash(ARGON2_ITERATIONS, ARGON2_MEMORY_KB, ARGON2_PARALLELISM, passwordWithPepper);
        } finally {
            argon2.wipeArray(passwordWithPepper);
        }
    }
}
