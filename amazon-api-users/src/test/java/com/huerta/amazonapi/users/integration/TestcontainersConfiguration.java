package com.huerta.amazonapi.users.integration;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
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

    public static MySQLContainer<?> mysqlContainer = new MySQLContainer<>(DockerImageName.parse("mysql:8.0"))
        .withDatabaseName("amazon_users_test")
        .withUsername("test")
        .withPassword("test")
        .withReuse(true);

    public static GenericContainer<?> vaultContainer = new GenericContainer<>(DockerImageName.parse("hashicorp/vault:1.15"))
        .withExposedPorts(8200)
        .withEnv("VAULT_DEV_ROOT_TOKEN_ID", "myroot")
        .withEnv("VAULT_DEV_LISTEN_ADDRESS", "0.0.0.0:8200")
        .withEnv("VAULT_ADDR", "http://0.0.0.0:8200")
        .withCommand("server", "-dev")
        .waitingFor(Wait.forHttp("/v1/sys/health").forStatusCode(200))
        .withReuse(true);

    static {
        mysqlContainer.start();
        vaultContainer.start();
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
