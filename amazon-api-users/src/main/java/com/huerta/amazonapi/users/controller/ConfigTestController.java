package com.huerta.amazonapi.users.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("users-api/config")
public class ConfigTestController {

    @Value("${password_pepper:NOT_SET}")
    private String passwordPepper;

    @GetMapping("/test-vault")
    public ResponseEntity<Map<String, String>> testVaultConnection() {
        Map<String, String> response = new HashMap<>();
        
        boolean pepperLoaded = passwordPepper != null && 
                              !passwordPepper.isEmpty() && 
                              !passwordPepper.equals("NOT_SET");
        
        response.put("vault_connection", pepperLoaded ? "SUCCESS" : "FAILED");
        response.put("pepper_loaded", String.valueOf(pepperLoaded));
        response.put("pepper_length", passwordPepper != null ? String.valueOf(passwordPepper.length()) : "0");
        response.put("pepper_preview", passwordPepper != null && passwordPepper.length() > 4 
            ? passwordPepper.substring(0, 4) + "..." 
            : "NOT_LOADED");
        
        return ResponseEntity.ok(response);
    }
}
