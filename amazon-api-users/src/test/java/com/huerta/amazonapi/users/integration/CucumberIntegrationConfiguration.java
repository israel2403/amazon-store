package com.huerta.amazonapi.users.integration;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

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
@Import(TestcontainersConfiguration.class)
public class CucumberIntegrationConfiguration {
    
    private static TestcontainersConfiguration.VaultInitializer vaultInitializer;
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // Vault properties are dynamically configured from Testcontainers
        if (vaultInitializer != null) {
            registry.add("spring.cloud.vault.uri", vaultInitializer::getVaultAddress);
            registry.add("spring.cloud.vault.token", vaultInitializer::getVaultToken);
        }
    }
    
    // Inject VaultInitializer to get dynamic properties
    @Autowired
    public void setVaultInitializer(TestcontainersConfiguration.VaultInitializer initializer) {
        vaultInitializer = initializer;
    }
}
