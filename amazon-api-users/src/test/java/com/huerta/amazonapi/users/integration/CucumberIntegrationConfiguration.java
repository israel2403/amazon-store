package com.huerta.amazonapi.users.integration;

import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;

import io.cucumber.spring.CucumberContextConfiguration;

/**
 * Cucumber configuration for integration tests using Testcontainers.
 * Automatically starts MySQL and Vault containers for testing.
 * 
 * No manual infrastructure setup required - containers are managed by Testcontainers.
 */
@CucumberContextConfiguration
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("integration")
public class CucumberIntegrationConfiguration {
    
    static MySQLContainer<?> mysqlContainer;
    static GenericContainer<?> vaultContainer;
    private static volatile boolean initialized = false;
    
    static {
        initializeContainers();
    }
    
    private static synchronized void initializeContainers() {
        if (!initialized) {
            mysqlContainer = new MySQLContainer<>(DockerImageName.parse("mysql:8.0"))
                .withDatabaseName("amazon_users_test")
                .withUsername("test")
                .withPassword("test");
            mysqlContainer.start();
            
            vaultContainer = new GenericContainer<>(DockerImageName.parse("hashicorp/vault:1.15"))
                .withExposedPorts(8200)
                .withEnv("VAULT_DEV_ROOT_TOKEN_ID", "myroot")
                .withEnv("VAULT_DEV_LISTEN_ADDRESS", "0.0.0.0:8200")
                .withEnv("VAULT_ADDR", "http://0.0.0.0:8200")
                .withCommand("server", "-dev")
                .waitingFor(Wait.forHttp("/v1/sys/health").forStatusCode(200));
            vaultContainer.start();
            
            initializeVault();
            initialized = true;
        }
    }
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // MySQL datasource properties
        registry.add("spring.datasource.url", mysqlContainer::getJdbcUrl);
        registry.add("spring.datasource.username", mysqlContainer::getUsername);
        registry.add("spring.datasource.password", mysqlContainer::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "com.mysql.cj.jdbc.Driver");
        
        // Vault properties
        registry.add("spring.cloud.vault.uri", () -> "http://" + vaultContainer.getHost() + ":" + vaultContainer.getMappedPort(8200));
        registry.add("spring.cloud.vault.token", () -> "myroot");
        
        // Initialize Vault after containers start
        initializeVault();
    }
    
    private static void initializeVault() {
        try {
            // Wait for container to be fully ready
            Thread.sleep(3000);
            
            // Enable KV secrets engine v2
            vaultContainer.execInContainer(
                "vault", "secrets", "enable", "-version=2", "-path=kv", "kv"
            );
            
            // Store password pepper
            vaultContainer.execInContainer(
                "vault", "kv", "put", "kv/amazon-api/security",
                "password_pepper=testcontainers-pepper-value-for-integration-tests"
            );
            
            System.out.println("✅ Vault initialized with test secrets");
        } catch (Exception e) {
            throw new RuntimeException("Failed to initialize Vault", e);
        }
    }
}
