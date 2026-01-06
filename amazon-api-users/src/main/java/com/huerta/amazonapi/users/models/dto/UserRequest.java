package com.huerta.amazonapi.users.models.dto;

import java.util.Set;

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
public class UserRequest {

    @NotBlank
    @Size(max = 128)
    private String username;

    @NotBlank
    @Size(min = 8, max = 255)
    private String password;

    @Size(max = 255)
    private String firstName;

    @Size(max = 255)
    private String lastName;

    @Size(max = 50)
    private String phone;

    @Size(max = 512)
    private String avatarUrl;

    @Email(message = "Email is required")
    private String email;

    private Set<String> roles;
}
