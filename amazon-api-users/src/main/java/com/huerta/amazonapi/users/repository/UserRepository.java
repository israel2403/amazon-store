package com.huerta.amazonapi.users.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.huerta.amazonapi.users.models.entity.User;
import java.util.Optional;



public interface UserRepository extends JpaRepository<User, UUID>{
    
    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);
    
    /**
     * Check if user exists with given username or email (single query optimization).
     * 
     * @param username The username to check
     * @param email The email to check
     * @return true if user exists with either username or email
     */
    boolean existsByUsernameOrEmail(String username, String email);
}
