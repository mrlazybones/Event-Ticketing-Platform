# Event Ticketing & Booking Platform

A production-oriented backend for selling event tickets: venues and seat layouts, events and
shows, seat inventory, bookings that never sell the same seat twice, payments and an organiser
dashboard. The platform is built milestone by milestone, and every milestone leaves the project
runnable, tested and documented.

| | |
|---|---|
| **Current milestone** | 3 - Dockerized PostgreSQL (done locally) |
| **Next milestone** | 4 - Schema migrations and seed data |

## Scope of Milestone 1

Milestone 1 sets up the project, not the business features:

- A Maven multi-module build (`booking-domain`, `booking-service`, `booking-api`) driven by the Maven Wrapper.
- A runnable Spring Boot application with a `GET /api/v1/health` endpoint that needs no database.
- A package skeleton for every feature: users, venues, events, shows, inventory, bookings, payments, dashboard.
- Automated tests, build-time architecture checks, developer scripts for Linux/macOS and Windows, and GitHub Actions CI.

Milestone 2 connects that application to PostgreSQL. It does not add tables for users, venues,
events, shows, seats, bookings or payments, and it does not add Docker Compose.

Still **not** included: Docker Compose, seed data, the business schema, booking logic, concurrency
control, payments, Redis and Kafka. They are planned for later milestones (see [Milestones](#milestones)).

## Technology stack

| Area | Choice | Version | Status |
|---|---|---|---|
| Language | Java | 21 (bytecode level; builds on JDK 21 or newer) | in use |
| Framework | Spring Boot with Spring MVC | 3.5.16 (Spring Framework 6.2.19) | in use |
| Embedded server | Tomcat | 10.1.55 | in use |
| Build | Maven through the Maven Wrapper | Maven 3.9.16, wrapper 3.3.4 | in use |
| Testing | JUnit 5, Mockito, AssertJ, Spring Boot Test | 5.12.2, 5.17.0, 3.27.7 | in use |
| Build checks | Maven Enforcer Plugin | 3.5.0 | in use |
| CI | GitHub Actions | checkout v7, setup-java v6, upload-artifact v7 | in use |
| Persistence | Spring Data JPA / Hibernate | Hibernate 6.6.53, Spring Data JPA 3.5.13 | in use |
| Connection pool | HikariCP (inside the JDBC starter) | 6.3.3 | in use |
| Database | PostgreSQL and its JDBC driver | server 17, driver 42.7.11 | in use |
| Migrations | Flyway | 11.7.2 | configured; no business migrations yet |
| Integration tests | Testcontainers | 1.21.4 | in use |
| Local infrastructure | Docker Compose | Compose v2 (`docker compose`) | in use, PostgreSQL only |

All library and plugin versions except Spring Boot and the Maven Wrapper come from the Spring Boot
BOM, so later milestones add dependencies without writing version numbers.

## Prerequisites

- **JDK 21 or newer**: check with `java -version`. Either `JAVA_HOME` points to the JDK or `java` is
  on the `PATH`. The code is compiled for Java 21 even when you build with a newer JDK.
- **No Maven installation**: `mvnw` / `mvnw.cmd` download Maven 3.9.16 on first use.
- Internet access for the first build (Maven and the dependencies are cached in `~/.m2`).
- `curl` for `scripts/verify.sh` (preinstalled on macOS, most Linux distributions and Git Bash).
- Windows: PowerShell 5.1 or newer (built in). Git Bash or WSL can run the `.sh` scripts as well.
- **Docker Desktop** (or another engine with the `docker compose` plugin) for the local database.
  Database-independent tests do not need it. `scripts/verify.*` runs integration tests with
  Testcontainers, which is a separate PostgreSQL from the Compose one.

## Directory structure

```text
event-ticketing-platform/
|-- pom.xml                    parent + aggregator POM (inherits spring-boot-starter-parent)
|-- mvnw, mvnw.cmd, .mvn/      Maven Wrapper, pins Maven 3.9.16
|-- booking-domain/            domain model; no Spring or web dependencies
|   `-- src/main/java/com/example/booking/domain/
|       common, users, venues, events, shows, inventory, bookings, payments
|-- booking-service/           application services and persistence; depends on booking-domain
|   |-- src/main/java/com/example/booking/service/
|   |   `-- common/DatabaseConnectivityChecker.java
|   `-- src/main/resources/db/migration/   Flyway location (no business migrations yet)
|-- booking-api/               Spring Boot application and REST API; depends on booking-service
|   |-- src/main/java/com/example/booking/
|   |   |-- BookingApiApplication.java
|   |   `-- api/health/   liveness and database readiness endpoints
|   |-- src/main/resources/    application.yml, application-dev.yml
|   `-- src/test/java/com/example/booking/
|-- compose.yaml               local PostgreSQL only
|-- scripts/                   dev, build, test, verify, db-up, db-down, db-reset, db-status, db-logs
|-- .github/workflows/ci.yml   CI on Linux and Windows
`-- .editorconfig, .gitattributes, .gitignore, .env.example
```

## PostgreSQL

Start Docker Desktop, then start the database. The application stays on the host. It connects to
`127.0.0.1` and the published port, which defaults to `5432`.

| | Windows PowerShell | Linux / macOS / Git Bash / WSL |
|---|---|---|
| Start and wait until healthy | `.\scripts\db-up.ps1` | `./scripts/db-up.sh` |
| Status | `.\scripts\db-status.ps1` | `./scripts/db-status.sh` |
| Recent logs | `.\scripts\db-logs.ps1` | `./scripts/db-logs.sh` |
| Follow logs | `.\scripts\db-logs.ps1 -Follow` | `./scripts/db-logs.sh --follow` |
| Stop, keep the data | `.\scripts\db-down.ps1` | `./scripts/db-down.sh` |
| Erase the data | `.\scripts\db-reset.ps1 -Force` | `./scripts/db-reset.sh --yes` |

`db-up` returns only after `pg_isready` reports healthy, or it fails within 60 seconds
(`DB_READY_TIMEOUT_SECONDS` changes that). `db-down` stops the container and keeps the volume
`event-ticketing-postgres`. `db-reset` without `-Force` or `--yes` refuses to run.

The database name, user and password are the local placeholders `event_ticketing`. They are not
production credentials. Copy `.env.example` to `.env` to change them. `DB_NAME` and `DB_HOST_PORT`
are for Compose. `DB_URL` is for Spring Boot, and its port and database name must match those two.
Compose reads `.env` by itself. Spring Boot does not: `scripts/dev.ps1` and `scripts/dev.sh` export
it, and an IDE launch does not.

Inside another container, `localhost` is that container, not your machine. A future app container
would use hostname `postgres` and port `5432` (the container port). This milestone does not run the
application in Docker.

The port is published only on `127.0.0.1`, so other machines on the network cannot open it.

## Running the application

| Linux / macOS / Git Bash | Windows PowerShell |
|---|---|
| `./scripts/dev.sh` | `.\scripts\dev.ps1` |

The process does not start when PostgreSQL is down: Flyway tries to connect during startup and the
JVM exits. Wait for `Started BookingApiApplication`, then check the two endpoints from a second
terminal. Liveness only means the web server is up. Readiness means PostgreSQL accepted a
connection and Flyway's schema history matches the migrations on the classpath.

| Linux / macOS / Git Bash / WSL | Windows PowerShell |
|---|---|
| `curl http://localhost:8080/api/v1/health` | `curl.exe http://localhost:8080/api/v1/health` |
| `curl http://localhost:8080/api/v1/health/readiness` | `curl.exe http://localhost:8080/api/v1/health/readiness` |

```json
{"status":"UP"}
```

Readiness returns HTTP 503 and `{"status":"DOWN"}` when the database is unreachable after startup.
The body never contains the password, the JDBC URL or the SQL error; those stay in the server log.

In Windows PowerShell, `curl` without `.exe` is an alias for `Invoke-WebRequest`; use `curl.exe`
or `Invoke-RestMethod http://localhost:8080/api/v1/health` instead.

Stop the application with `Ctrl+C` (on Windows, answer `Y` if asked "Terminate batch job (Y/N)?").
Alternatives:

- IDE: run `com.example.booking.BookingApiApplication` in the `booking-api` module.
- Maven Wrapper directly: `./mvnw -pl booking-api -am spring-boot:run`
  (Windows: `.\mvnw.cmd -pl booking-api -am spring-boot:run`).
- Packaged JAR: build first, then `java -jar booking-api/target/booking-api-0.1.0-SNAPSHOT.jar`.

### Configuration

The application uses the `dev` profile unless `SPRING_PROFILES_ACTIVE` is set. To change settings
for local runs, copy `.env.example` to `.env`; the dev scripts load it automatically.

| Variable | Default | Purpose |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | none, so `spring.profiles.default` (`dev`) applies | Spring profile(s) to activate |
| `SERVER_PORT` | `8080` | HTTP port |
| `DB_URL` | `jdbc:postgresql://localhost:5432/event_ticketing` | JDBC URL, dev profile only |
| `DB_USERNAME` | `event_ticketing` | database user, dev profile only |
| `DB_PASSWORD` | `event_ticketing` | database password, dev profile only |

`DB_URL` is not turned into `spring.datasource.url` by Spring on its own. The dev profile contains
`url: ${DB_URL:...}`, which is what reads the variable. There is no production profile yet; starting
with `SPRING_PROFILES_ACTIVE=prod` fails on purpose because that profile has no database settings.

## Building and testing

| Task | Linux / macOS / Git Bash | Windows PowerShell | Runs |
|---|---|---|---|
| Build | `./scripts/build.sh` | `.\scripts\build.ps1` | `mvnw clean package -DskipTests` |
| Test | `./scripts/test.sh` | `.\scripts\test.ps1` | `mvnw test` (no database) |
| Full verification | `./scripts/verify.sh` | `.\scripts\verify.ps1` | `mvnw clean verify`, including PostgreSQL integration tests, then a JAR smoke test when port 5432 accepts connections |

- The scripts work from any directory, print the Maven command they run, and exit with a non-zero
  code and an `ERROR:` line when something fails.
- Extra arguments go to Maven, for example
  `./scripts/test.sh -Dtest=HealthControllerTest -Dsurefire.failIfNoSpecifiedTests=false`.
  In PowerShell, quote arguments that contain dots:
  `.\scripts\test.ps1 '-Dtest=HealthControllerTest' '-Dsurefire.failIfNoSpecifiedTests=false'`.
- `test` never starts PostgreSQL. `verify` runs `PostgresConnectivityIT` through the Failsafe plugin,
  which needs a running Docker daemon. Pass `-DskipITs` to skip those tests; the script then says
  they were not verified instead of pretending they passed.
- When something is already listening on the database port, `verify` starts the packaged JAR on port
  `18080` (override with `SMOKE_TEST_PORT`) and requires both health endpoints to report `UP`.
- Reports: `booking-api/target/surefire-reports/` for the database-free tests and
  `booking-api/target/failsafe-reports/` for the PostgreSQL tests.

**Windows:** if PowerShell refuses to run the scripts ("running scripts is disabled on this
system"), allow local scripts once with `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or
run a single script with `powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1`.

**Linux/macOS:** if a script reports "Permission denied", the executable bit was lost (common when
files are committed from Windows). Run `chmod +x mvnw scripts/*.sh`, or start the script with
`bash scripts/verify.sh`.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pushes to `main` and on pull
requests, on Temurin JDK 25. The Linux job starts PostgreSQL 17 as a service container and runs
`bash scripts/verify.sh`, so the integration tests and the packaged JAR are both checked. The
Windows job has no Docker; it runs `.\scripts\verify.ps1 -DskipITs` with `DATABASE_CHECKS=skipped`
and prints that the database was not checked there. Test reports are uploaded when a job fails.

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Project initialization | Done |
| 2 | PostgreSQL connectivity, JPA, Flyway and Testcontainers | Done |
| 3 | Dockerized PostgreSQL for everyday development | Done locally |
| 4 | Schema migrations and seed data | Next |
| 5-14 | API conventions, users and security, venues, events and shows, seat inventory, bookings and concurrency, payments, caching and messaging, dashboard, production readiness | Planned |

## Known limitations

- **Spring Boot 3.5.x no longer receives open-source support.** It ended on 2026-06-30, and 3.5.16 is
  the final 3.x release. This milestone required Spring Boot 3.x; plan the upgrade to Spring Boot
  4.x before any production use.
- No business schema yet. The only table Flyway creates is its own `flyway_schema_history`.
  Startup logs `No migrations found. Are your locations set up correctly?` until the first
  `V1__description.sql` file exists. That warning means the migration directory was scanned and was empty.
- The application does not start while PostgreSQL is down, so the liveness endpoint cannot be called
  until the database used at startup is reachable. Readiness is the check that talks to the database.
- No authentication or authorization: every endpoint is public.
- `booking-domain` still has no business types. `booking-service` has the connectivity check and no
  repositories yet.
- No business schema and no seed data yet. Milestone 4 adds them.
- The application is not built into an image. Only PostgreSQL runs in Docker.

## Connection failures

| What you see | What it means |
|---|---|
| `Connection to 127.0.0.1:5432 refused` while Flyway starts | Nothing is listening. Start PostgreSQL, or correct `DB_URL`. The process then exits; this is not a readiness response. |
| `password authentication failed for user "event_ticketing"` | The server is up and the user or password does not match. The log does not print the password. |
| `database "event_ticketing" does not exist` | Create the database, or point `DB_URL` at one that exists. |
| `No migrations found` at WARN | Expected in this milestone. The directory `db/migration` is on the classpath and contains no versioned SQL yet. |
| `Port 8080 was already in use` | Another copy is still running. Stop it, or set `SERVER_PORT`. |
| Integration tests cannot find Docker | Start Docker Desktop, then run `.\scripts\verify.ps1` again. `.\scripts\test.ps1` does not need Docker. |
| `port is already allocated` from `db-up` | Something else is using 5432. Stop it, or set `DB_HOST_PORT` and the same port inside `DB_URL`. |
| `Docker is installed but the engine is not running` | Start Docker Desktop and run `.\scripts\db-up.ps1` again. |
| Readiness is `DOWN` after `db-down` | Expected. The process was already up and the database then stopped. A fresh start with the database down exits instead, during Flyway. |
| Readiness returns `{"status":"DOWN"}` | The process is up but a later connection or schema check failed. Read the server log for the SQLState. The HTTP body stays generic on purpose. |
