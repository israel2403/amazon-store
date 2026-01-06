package com.huerta.amazonapi.users.mappers;

import java.util.function.Function;

import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.models.entity.User;

public interface UserMapper {
    public Function<UserRequest, User> fromUserRequestToUser = (userRequest) -> {
        return User.builder()
        .username(userRequest.getUsername())
        .email(userRequest.getEmail())
        .firstName(userRequest.getFirstName())
        .lastName(userRequest.getLastName())
        .phone(userRequest.getPhone())
        .avatarUrl(userRequest.getAvatarUrl())
        .roles(userRequest.getRoles())
        .build();
    };

    public Function<User, UserResponse> fromUserToUserResponse = (user) -> {
        return UserResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .phone(user.getPhone())
                .avatarUrl(user.getAvatarUrl())
                .roles(user.getRoles())
                .enabled(user.isEnabled())
                .emailVerified(user.isEmailVerified())
                .locked(user.isLocked())
                .lastLoginAt(user.getLastLoginAt())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    };
}
