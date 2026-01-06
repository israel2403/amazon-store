package com.huerta.amazonapi.users.error;

import java.time.Instant;
import java.util.Collections;
import java.util.List;

import org.springframework.http.HttpStatus;

import lombok.Getter;

/**
 * Standard error envelope for API responses.
 */
@Getter
public class ApiError {
    private final Instant timestamp = Instant.now();
    private final int status;
    private final String error;
    private final String message;
    private final List<ErrorDetail> details;

    private ApiError(HttpStatus status, String message, List<ErrorDetail> details) {
        this.status = status.value();
        this.error = status.getReasonPhrase();
        this.message = message;
        this.details = details == null ? Collections.emptyList() : List.copyOf(details);
    }

    public static ApiError of(HttpStatus status, String message) {
        return new ApiError(status, message, Collections.emptyList());
    }

    public static ApiError of(HttpStatus status, String message, List<ErrorDetail> details) {
        return new ApiError(status, message, details);
    }
}
