package com.huerta.amazonapi.users.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.huerta.amazonapi.users.models.dto.HelloWorld;
import com.huerta.amazonapi.users.models.dto.UserRequest;
import com.huerta.amazonapi.users.models.dto.UserResponse;
import com.huerta.amazonapi.users.service.UserService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("users-api")
@RequiredArgsConstructor
public class UsersController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<HelloWorld> helloWorld(){
        return ResponseEntity.ok(HelloWorld.builder().helloWorldMsg("Hello World!!!").build());
    }

    @GetMapping("/hello")
    public ResponseEntity<String> health(){
        return ResponseEntity.ok("OK");
    }

    @PostMapping
    public ResponseEntity<UserResponse> create(@Valid @RequestBody UserRequest userRequest){
        UserResponse created = this.userService.createUser(userRequest);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }
}
