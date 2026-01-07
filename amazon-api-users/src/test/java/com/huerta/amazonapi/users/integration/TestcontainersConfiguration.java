package com.huerta.amazonapi.users.integration;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;

/**
 * Testcontainers configuration for integration tests.
 * Automatically starts MySQL and Vault containers for testing.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    /**
     * MySQL container for integration tests.
     * @ServiceConnection automatically configures Spring Boot datasource properties.
     */
    @Bean
    @ServiceConnection
    MySQLContainer<?> mysqlContainer() {
        return new MySQLContainer<>(DockerImageName.parse("mysql:8.0"))
            .withDatabaseName("amazon_users_test")
            .withUsername("test")
            .withPassword("test")
            .withReuse(true); // Reuse container across tests for speed
    }

    /**
     * Vault container for integration tests.
     * Configured with dev mode and pre-seeded pepper secret.
     */
    @Bean
    GenericContainer<?> vaultContainer() {
        return new GenericContainer<>(DockerImageName.parse("hashicorp/vault:1.15"))
            .withExposedPorts(8200)
            .withEnv("VAULT_DEV_ROOT_TOKEN_ID", "myroot")
            .withEnv("VAULT_DEV_LISTEN_ADDRESS", "0.0.0.0:8200")
            .withEnv("VAULT_ADDR", "http://0.0.0.0:8200")
            .withCommand("server", "-dev")
            .waitingFor(Wait.forHttp("/v1/sys/health").forStatusCode(200))
            .withReuse(true);
    }

    /**
     * Initialize Vault with test data.
     * This bean depends on vaultContainer being started.
     */
    @Bean
    VaultInitializer vaultInitializer(GenericContainer<?> vaultContainer) {
        return new VaultInitializer(vaultContainer);
    }

    /**
     * Helper class to initialize Vault with test secrets.
     */
    public static class VaultInitializer {
        private final GenericContainer<?> vaultContainer;

        public VaultInitializer(GenericContainer<?> vaultContainer) {
            this.vaultContainer = vaultContainer;
            initializeVault();
        }

        private void initializeVault() {
            try {
                // Wait for container to be fully ready
                Thread.sleep(2000);
                
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

        public String getVaultAddress() {
            return "http://" + vaultContainer.getHost() + ":" + vaultContainer.getMappedPort(8200);
        }

        public String getVaultToken() {
            return "myroot";
        }
    }
}
