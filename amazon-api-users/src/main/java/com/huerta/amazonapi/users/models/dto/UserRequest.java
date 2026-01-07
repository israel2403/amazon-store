package com.huerta.amazonapi.users.models.dto;

import java.util.Set;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Payload for creating or updating a user. Excludes server-managed fields
 * such as ids, audit timestamps, and account status flags.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class UserRequest {

    @NotBlank
    @Size(max = 128)
    private String username;

    @NotBlank(message = "Password is required")
    @Size(min = 8, max = 255, message = "Password must be at least 8 characters")
    @jakarta.validation.constraints.Pattern(
        regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).*$",
        message = "Password must contain at least one uppercase letter, one lowercase letter, and one digit"
    )
    private String password;

    @Size(max = 255)
    private String firstName;

    @Size(max = 255)
    private String lastName;

    @Size(max = 50)
    private String phone;

    @Size(max = 512)
    private String avatarUrl;

    @NotBlank(message = "Email is required")
    @Email(message = "Email must be valid")
    private String email;

    private Set<String> roles;
}
