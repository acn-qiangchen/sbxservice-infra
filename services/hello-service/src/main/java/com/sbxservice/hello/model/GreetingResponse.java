package com.sbxservice.hello.model;

import lombok.Data;

/**
 * Model class representing a greeting response.
 */
@Data
public class GreetingResponse {
    
    /**
     * The greeting message to be returned to the client.
     */
    private String message;
    
    /**
     * Default constructor.
     */
    public GreetingResponse() {
    }
    
    /**
     * Constructor with message parameter.
     *
     * @param message the greeting message
     */
    public GreetingResponse(String message) {
        this.message = message;
    }
} 