package com.example.javaapp;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class GreetingServiceTest {

    private final GreetingService service = new GreetingService();

    @Test
    void greetsByName() {
        assertEquals("Hello, Akilesh!", service.greet("Akilesh"));
    }

    @Test
    void trimsWhitespace() {
        assertEquals("Hello, Bob!", service.greet("  Bob  "));
    }

    @Test
    void fallsBackToWorldWhenBlankOrNull() {
        assertEquals("Hello, World!", service.greet(""));
        assertEquals("Hello, World!", service.greet("   "));
        assertEquals("Hello, World!", service.greet(null));
    }
}
