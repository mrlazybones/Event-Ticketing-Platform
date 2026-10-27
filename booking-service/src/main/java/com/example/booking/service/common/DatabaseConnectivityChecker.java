package com.example.booking.service.common;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Checks that the configured database accepts a connection and that Flyway's schema history matches
 * the migrations on the classpath. It returns no SQL text and no credentials to its callers.
 */
@Service
public class DatabaseConnectivityChecker {

    private static final Logger log = LoggerFactory.getLogger(DatabaseConnectivityChecker.class);
    private static final String POSTGRESQL = "PostgreSQL";

    private final JdbcTemplate jdbcTemplate;
    private final Flyway flyway;

    public DatabaseConnectivityChecker(JdbcTemplate jdbcTemplate, Flyway flyway) {
        this.jdbcTemplate = jdbcTemplate;
        this.flyway = flyway;
    }

    /** A connection succeeded and the database identified itself as PostgreSQL. */
    public boolean isConnected() {
        try {
            return POSTGRESQL.equals(inspect().productName());
        } catch (RuntimeException ex) {
            log.warn("Database connection check failed ({})", failureLabel(ex));
            return false;
        }
    }

    /**
     * Flyway has applied every migration it can see, and none of them failed. With no migration
     * files this is true once Flyway has created its own history table.
     */
    public boolean isSchemaValid() {
        try {
            flyway.validate();
            if (flyway.info().pending().length > 0) {
                return false;
            }
            for (MigrationInfo info : flyway.info().all()) {
                if (info.getState().isFailed()) {
                    return false;
                }
            }
            return true;
        } catch (RuntimeException ex) {
            log.warn("Schema validation failed ({})", failureLabel(ex));
            return false;
        }
    }

    /** Connected to PostgreSQL and the schema history agrees with the migrations on the classpath. */
    public boolean isReady() {
        return isConnected() && isSchemaValid();
    }

    /**
     * Opens one pooled connection, runs {@code SELECT 1} and reads the JDBC metadata. Callers that
     * only need a yes or no should use {@link #isConnected()} so a failure stays in the log.
     */
    public DatabaseInspection inspect() {
        DatabaseInspection inspection = jdbcTemplate.execute((ConnectionCallback<DatabaseInspection>) this::inspect);
        if (inspection == null) {
            throw new IllegalStateException("Database inspection returned no result");
        }
        return inspection;
    }

    private DatabaseInspection inspect(Connection connection) throws SQLException {
        try (var statement = connection.createStatement();
                var results = statement.executeQuery("SELECT 1")) {
            if (!results.next() || results.getInt(1) != 1) {
                throw new SQLException("SELECT 1 did not return 1");
            }
        }
        DatabaseMetaData meta = connection.getMetaData();
        return new DatabaseInspection(meta.getDatabaseProductName(), meta.getDriverName(), connection.getCatalog());
    }

    /** SQLState when the failure came from JDBC; otherwise the exception class. Never the message. */
    private static String failureLabel(Throwable failure) {
        Throwable current = failure;
        while (current != null) {
            if (current instanceof SQLException sqlException && sqlException.getSQLState() != null) {
                return "SQLState " + sqlException.getSQLState();
            }
            current = current.getCause();
        }
        return failure.getClass().getName();
    }

    /**
     * What a live connection reported. {@code productName} comes from the server, {@code driverName}
     * from the JDBC driver loaded by the application, and {@code catalog} is the database name.
     */
    public record DatabaseInspection(String productName, String driverName, String catalog) {}

    /** Exposed so configuration reviews can see which pool implementation is wired. Not used for HTTP. */
    public Class<? extends DataSource> dataSourceType() {
        DataSource dataSource = jdbcTemplate.getDataSource();
        if (dataSource == null) {
            throw new IllegalStateException("JdbcTemplate has no DataSource");
        }
        return dataSource.getClass();
    }
}
