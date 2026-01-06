package com.huerta.amazonapi.users.exception;

/**
 * Thrown when attempting to create or update a resource that must be unique
 * (e.g., username or email already in use).
 */
public class ResourceAlreadyExistsException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    public ResourceAlreadyExistsException() {
        super("Resource already exists");
    }

    public ResourceAlreadyExistsException(String message) {
        super(message);
    }

    public ResourceAlreadyExistsException(String resourceName, String fieldName, Object fieldValue) {
        super(String.format("%s with %s '%s' already exists", resourceName, fieldName, fieldValue));
    }

    public ResourceAlreadyExistsException(String message, Throwable cause) {
        super(message, cause);
    }
}
