package com.example.booking;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.booking.service.common.DatabaseConnectivityChecker;
import com.example.booking.service.common.DatabaseConnectivityChecker.DatabaseInspection;
import com.zaxxer.hikari.HikariDataSource;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Starts the real application against PostgreSQL 17 in Docker. Nothing in this test uses H2.
 * {@code mvn test} does not run it; {@code mvn verify} does, through the Failsafe plugin.
 */
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@Testcontainers
class PostgresConnectivityIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine");

    @Autowired
    private Environment environment;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private Flyway flyway;

    @Autowired
    private DatabaseConnectivityChecker database;

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void contextLoadsTheDevProfileAndAPooledDataSource() {
        assertThat(environment.acceptsProfiles(Profiles.of("dev"))).isTrue();
        assertThat(environment.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
        assertThat(environment.getProperty("spring.jpa.open-in-view")).isEqualTo("false");
        assertThat(environment.getProperty("spring.flyway.locations")).contains("classpath:db/migration");
        assertThat(dataSource).isInstanceOf(HikariDataSource.class);
        assertThat(database.dataSourceType().getName()).contains("HikariDataSource");
    }

    @Test
    void connectsWithThePostgresqlJdbcDriver() {
        DatabaseInspection inspection = database.inspect();

        assertThat(inspection.productName()).isEqualTo("PostgreSQL");
        assertThat(inspection.driverName()).contains("PostgreSQL");
        assertThat(inspection.catalog()).isNotBlank();
        assertThat(jdbcTemplate.queryForObject("SELECT 1", Integer.class)).isEqualTo(1);
        assertThat(postgres.getJdbcUrl()).startsWith("jdbc:postgresql:");
    }

    @Test
    void flywayInitializesItsHistoryWithoutBusinessMigrations() {
        Integer historyTables = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'flyway_schema_history'
                """,
                Integer.class);

        assertThat(historyTables).isEqualTo(1);
        assertThat(flyway.info().applied()).isEmpty();
        assertThat(flyway.info().pending()).isEmpty();
        assertThat(database.isSchemaValid()).isTrue();
    }

    @Test
    void livenessDoesNotReportDatabaseState() {
        ResponseEntity<String> response = restTemplate.getForEntity("/api/v1/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getContentType()).isEqualTo(MediaType.APPLICATION_JSON);
        assertThat(response.getBody()).isEqualTo("{\"status\":\"UP\"}");
    }

    @Test
    void readinessReportsUpWhenPostgresAndTheSchemaAreReady() {
        assertThat(database.isConnected()).isTrue();
        assertThat(database.isReady()).isTrue();

        ResponseEntity<String> response = restTemplate.getForEntity("/api/v1/health/readiness", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo("{\"status\":\"UP\"}");
    }
}
