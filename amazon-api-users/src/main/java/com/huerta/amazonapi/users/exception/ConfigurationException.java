package com.huerta.amazonapi.users.exception;

/**
 * Thrown when the application is misconfigured (e.g., missing Vault secrets).
 * This is a fatal exception that should prevent the application from starting.
 */
public class ConfigurationException extends RuntimeException {

    private static final long serialVersionUID = 1L;
    
    private final String configurationKey;

    public ConfigurationException(String configurationKey, String message) {
        super(message);
        this.configurationKey = configurationKey;
    }

    public ConfigurationException(String configurationKey, String message, Throwable cause) {
        super(message, cause);
        this.configurationKey = configurationKey;
    }

    public String getConfigurationKey() {
        return configurationKey;
    }
    
    @Override
    public String toString() {
        return String.format("ConfigurationException[key=%s]: %s", configurationKey, getMessage());
    }
}
