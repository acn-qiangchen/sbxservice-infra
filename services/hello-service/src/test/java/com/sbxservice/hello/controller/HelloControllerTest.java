package com.sbxservice.hello.controller;

import com.sbxservice.hello.model.GreetingResponse;
import com.sbxservice.hello.service.HelloService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.is;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Web layer tests for the HelloController.
 */
@WebMvcTest(HelloController.class)
class HelloControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private HelloService helloService;

    @Test
    @DisplayName("GET /api/hello should return default greeting when no name is provided")
    void shouldReturnDefaultGreetingWhenNoNameIsProvided() throws Exception {
        // Given
        when(helloService.generateGreeting(isNull())).thenReturn("Hello, World!");

        // When, Then
        mockMvc.perform(get("/api/hello")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("Hello, World!")));
    }

    @Test
    @DisplayName("GET /api/hello with name parameter should return personalized greeting")
    void shouldReturnPersonalizedGreetingWhenNameIsProvided() throws Exception {
        // Given
        String name = "John";
        when(helloService.generateGreeting(name)).thenReturn("Hello, John!");

        // When, Then
        mockMvc.perform(get("/api/hello")
                .param("name", name)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("Hello, John!")));
    }

    @Test
    @DisplayName("GET /api/hello with empty name parameter should return default greeting")
    void shouldReturnDefaultGreetingWhenEmptyNameIsProvided() throws Exception {
        // Given
        when(helloService.generateGreeting("")).thenReturn("Hello, World!");

        // When, Then
        mockMvc.perform(get("/api/hello")
                .param("name", "")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("Hello, World!")));
    }
} 