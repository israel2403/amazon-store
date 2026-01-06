package com.huerta.amazonapi.users.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Represents a single validation error detail.
 */
@Getter
@AllArgsConstructor
public class ErrorDetail {
    private final String field;
    private final String message;
}
