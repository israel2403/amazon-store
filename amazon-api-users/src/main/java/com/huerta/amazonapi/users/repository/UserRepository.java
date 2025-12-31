package com.huerta.amazonapi.users.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.huerta.amazonapi.users.models.entity.User;

public interface UserRepository extends JpaRepository<User, UUID>{
    
}
