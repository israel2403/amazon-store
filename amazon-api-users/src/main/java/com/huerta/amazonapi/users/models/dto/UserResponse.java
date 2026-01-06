package com.huerta.amazonapi.users.models.dto;

import java.time.Instant;
import java.util.Set;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

/**
 * Outbound representation exposing only business-relevant fields.
 * Omits sensitive/internal attributes like password hash and soft-delete marker.
 */
@Value
@Builder
public class UserResponse {
    UUID id;
    String username;
    String firstName;
    String lastName;
    String phone;
    String avatarUrl;
    Set<String> roles;
    boolean enabled;
    boolean emailVerified;
    boolean locked;
    Instant lastLoginAt;
    Instant createdAt;
    Instant updatedAt;
}
