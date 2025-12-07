package com.huerta.amazonapi.users.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.huerta.amazonapi.users.models.dto.HelloWorld;

@RestController
@RequestMapping("users-api")
public class UsersController {

    @GetMapping
    public ResponseEntity<HelloWorld> helloWorld(){
        return ResponseEntity.ok(HelloWorld.builder().helloWorldMsg("Hello World!!!").build());
    }

    @GetMapping("/hello")
    public ResponseEntity<String> health(){
        return ResponseEntity.ok("OK");
    }
}
