package com.huerta.amazonapi.users.exception;

public class MissingSecretException extends RuntimeException{

    private static final long serialVersionUID = 1L;

    public MissingSecretException(){
        super("");
    }

    public MissingSecretException(String message){
        super(message);
    }

    public MissingSecretException(String message, Throwable cause){
super(message, cause);
    }
}