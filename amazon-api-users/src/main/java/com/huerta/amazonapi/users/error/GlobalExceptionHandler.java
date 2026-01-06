package com.huerta.amazonapi.users.error;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import com.huerta.amazonapi.users.exception.ConfigurationException;
import com.huerta.amazonapi.users.exception.PasswordHashingException;
import com.huerta.amazonapi.users.exception.ResourceAlreadyExistsException;
import com.huerta.amazonapi.users.exception.UserCreationException;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;

@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {

        List<ErrorDetail> details = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(this::toErrorDetail)
                .collect(Collectors.toList());

        ApiError body = ApiError.of(HttpStatus.BAD_REQUEST, "Validation failed", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiError> handleConstraintViolation(ConstraintViolationException ex) {
        List<ErrorDetail> details = ex.getConstraintViolations()
                .stream()
                .map(this::toErrorDetail)
                .collect(Collectors.toList());
        ApiError body = ApiError.of(HttpStatus.BAD_REQUEST, "Validation failed", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(ResourceAlreadyExistsException.class)
    public ResponseEntity<ApiError> handleResourceAlreadyExists(ResourceAlreadyExistsException ex) {
        // Add field details if available
        ErrorDetail detail = null;
        if (ex.getFieldName() != null && ex.getFieldValue() != null) {
            detail = new ErrorDetail(ex.getFieldName(), 
                String.format("%s '%s' is already taken", ex.getFieldName(), ex.getFieldValue()));
        }
        
        ApiError body = detail != null 
            ? ApiError.of(HttpStatus.CONFLICT, ex.getMessage(), List.of(detail))
            : ApiError.of(HttpStatus.CONFLICT, ex.getMessage());
        
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }
    
    @ExceptionHandler(PasswordHashingException.class)
    public ResponseEntity<ApiError> handlePasswordHashing(PasswordHashingException ex) {
        // Don't expose internal cryptographic details to users
        ApiError body = ApiError.of(
            HttpStatus.INTERNAL_SERVER_ERROR, 
            "Failed to process password. Please try again."
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
    
    @ExceptionHandler(UserCreationException.class)
    public ResponseEntity<ApiError> handleUserCreation(UserCreationException ex) {
        ApiError body = ApiError.of(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "Failed to create user. Please try again."
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
    
    @ExceptionHandler(ConfigurationException.class)
    public ResponseEntity<ApiError> handleConfiguration(ConfigurationException ex) {
        // This is a fatal error - service is misconfigured
        ApiError body = ApiError.of(
            HttpStatus.SERVICE_UNAVAILABLE,
            "Service is temporarily unavailable due to configuration error."
        );
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(body);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGenericException(Exception ex) {
        // Catch-all for unexpected exceptions
        ApiError body = ApiError.of(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred. Please try again."
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }

    private ErrorDetail toErrorDetail(FieldError fieldError) {
        return new ErrorDetail(fieldError.getField(), fieldError.getDefaultMessage());
    }

    private ErrorDetail toErrorDetail(ConstraintViolation<?> violation) {
        String fieldPath = violation.getPropertyPath() == null ? "" : violation.getPropertyPath().toString();
        return new ErrorDetail(fieldPath, violation.getMessage());
    }
}
