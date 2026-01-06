package com.huerta.amazonapi.users.exception;

/**
 * Thrown when user creation fails due to unexpected errors during the process.
 */
public class UserCreationException extends RuntimeException {

    private static final long serialVersionUID = 1L;
    
    private final String username;

    public UserCreationException(String username, String message) {
        super(String.format("Failed to create user '%s': %s", username, message));
        this.username = username;
    }

    public UserCreationException(String username, String message, Throwable cause) {
        super(String.format("Failed to create user '%s': %s", username, message), cause);
        this.username = username;
    }

    public String getUsername() {
        return username;
    }
}
