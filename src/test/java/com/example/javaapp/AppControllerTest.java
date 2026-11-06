package com.example.javaapp;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(AppController.class)
@Import(GreetingService.class)
@TestPropertySource(properties = {"app.message=test-message", "app.version=1.2.3"})
class AppControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void versionEndpointReturnsMessageAndVersion() throws Exception {
        mvc.perform(get("/api/version"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.message").value("test-message"))
           .andExpect(jsonPath("$.version").value("1.2.3"));
    }

    @Test
    void greetEndpointUsesName() throws Exception {
        mvc.perform(get("/api/greet").param("name", "Akilesh"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.greeting").value("Hello, Akilesh!"));
    }

    @Test
    void greetEndpointDefaultsToWorld() throws Exception {
        mvc.perform(get("/api/greet"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.greeting").value("Hello, World!"));
    }
}
