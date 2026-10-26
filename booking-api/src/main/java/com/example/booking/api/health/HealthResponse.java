package com.example.booking.api.health;

/**
 * Response body of {@code GET /api/v1/health}, serialized as {@code {"status":"UP"}}.
 */
record HealthResponse(String status) {

    static HealthResponse up() {
        return new HealthResponse("UP");
    }
}
