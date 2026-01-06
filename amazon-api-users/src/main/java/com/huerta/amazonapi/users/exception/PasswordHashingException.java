package com.huerta.amazonapi.users.exception;

/**
 * Thrown when password hashing fails due to cryptographic errors.
 */
public class PasswordHashingException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    public PasswordHashingException(String message) {
        super(message);
    }

    public PasswordHashingException(String message, Throwable cause) {
        super(message, cause);
    }
}
