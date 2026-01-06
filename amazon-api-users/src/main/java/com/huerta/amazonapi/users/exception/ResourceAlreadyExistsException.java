package com.huerta.amazonapi.users.exception;

import lombok.Getter;

/**
 * Thrown when attempting to create or update a resource that must be unique
 * (e.g., username or email already in use).
 */
@Getter
public class ResourceAlreadyExistsException extends RuntimeException {

    private static final long serialVersionUID = 1L;
    
    private final String resourceName;
    private final String fieldName;
    private final Object fieldValue;

    public ResourceAlreadyExistsException() {
        super("Resource already exists");
        this.resourceName = null;
        this.fieldName = null;
        this.fieldValue = null;
    }

    public ResourceAlreadyExistsException(String message) {
        super(message);
        this.resourceName = null;
        this.fieldName = null;
        this.fieldValue = null;
    }

    public ResourceAlreadyExistsException(String resourceName, String fieldName, Object fieldValue) {
        super(String.format("%s with %s '%s' already exists", resourceName, fieldName, fieldValue));
        this.resourceName = resourceName;
        this.fieldName = fieldName;
        this.fieldValue = fieldValue;
    }

    public ResourceAlreadyExistsException(String message, Throwable cause) {
        super(message, cause);
        this.resourceName = null;
        this.fieldName = null;
        this.fieldValue = null;
    }
}
