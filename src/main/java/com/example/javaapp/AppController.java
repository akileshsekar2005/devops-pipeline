package com.example.javaapp;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class AppController {

    private final GreetingService greetingService;
    private final String message;
    private final String version;

    public AppController(GreetingService greetingService,
                         @Value("${app.message}") String message,
                         @Value("${app.version:dev}") String version) {
        this.greetingService = greetingService;
        this.message = message;
        this.version = version;
    }

    /** Used by the pipeline's verify step: version == git short SHA baked into the image. */
    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("message", message, "version", version);
    }

    @GetMapping("/greet")
    public Map<String, String> greet(@RequestParam(required = false) String name) {
        return Map.of("greeting", greetingService.greet(name));
    }
}
