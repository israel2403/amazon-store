package com.huerta.amazonapi.users.integration;

import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import io.cucumber.spring.CucumberContextConfiguration;

/**
 * Cucumber configuration for integration tests that connect to real external services
 * (Vault, MySQL). This tests the complete integration chain.
 * 
 * Prerequisites:
 * - Vault must be running and unsealed
 * - MySQL must be available
 * - Password pepper must exist in Vault at kv/amazon-api/security
 */
@CucumberContextConfiguration
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("integration")
public class CucumberIntegrationConfiguration {
}
