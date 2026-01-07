package com.huerta.amazonapi.users.integration;

import com.huerta.amazonapi.users.models.entity.User;
import com.huerta.amazonapi.users.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Simple integration test to prove Testcontainers works with MySQL.
 * This is a plain JUnit 5 test without Cucumber complexity.
 */
@SpringBootTest
@ActiveProfiles("test-simple")
@Testcontainers
public class SimpleIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>(DockerImageName.parse("mysql:8.0"))
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "com.mysql.cj.jdbc.Driver");
        
        // Disable Vault for this test
        registry.add("spring.cloud.vault.enabled", () -> "false");
        registry.add("spring.config.import", () -> "optional:vault://");
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void testDatabaseConnection() {
        // Verify MySQL container is running
        assertThat(mysql.isRunning()).isTrue();
        
        // Test basic database operation
        long count = userRepository.count();
        assertThat(count).isGreaterThanOrEqualTo(0);
    }

    @Test
    void testCreateUser() {
        // Create a test user
        User user = new User();
        user.setUsername("testuser_" + System.currentTimeMillis());
        user.setEmail("test@example.com");
        user.setPasswordHash("$argon2id$v=19$m=16384,t=2,p=1$test");
        user.setEnabled(true);
        user.setEmailVerified(false);
        user.setLocked(false);
        user.setCreatedAt(Instant.now());
        
        // Save user
        User saved = userRepository.save(user);
        
        // Verify
        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getUsername()).isEqualTo(user.getUsername());
        
        // Clean up
        userRepository.delete(saved);
    }
}
