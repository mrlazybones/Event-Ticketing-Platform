package com.example.booking.api.health;

import com.example.booking.service.common.DatabaseConnectivityChecker;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Readiness endpoint. Unlike {@link HealthController}, it checks PostgreSQL and the Flyway schema
 * history. The response is only {@code UP} or {@code DOWN}: connection strings, passwords and SQL
 * errors stay in the server log.
 */
@RestController
@RequestMapping("/api/v1/health/readiness")
class ReadinessController {

    private final DatabaseConnectivityChecker database;

    ReadinessController(DatabaseConnectivityChecker database) {
        this.database = database;
    }

    @GetMapping
    ResponseEntity<HealthResponse> readiness() {
        if (database.isReady()) {
            return ResponseEntity.ok(HealthResponse.up());
        }
        return ResponseEntity.status(503).body(HealthResponse.down());
    }
}
