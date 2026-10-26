package com.example.booking.api.health;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Liveness endpoint. It only reports that the application is running and checks no external
 * systems such as a database, so it stays available even when those systems are down.
 */
@RestController
@RequestMapping("/api/v1/health")
class HealthController {

    @GetMapping
    HealthResponse health() {
        return HealthResponse.up();
    }
}
