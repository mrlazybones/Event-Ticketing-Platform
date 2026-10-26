# Event Ticketing & Booking Platform

A production-oriented backend for selling event tickets: venues and seat layouts, events and
shows, seat inventory, bookings that never sell the same seat twice, payments and an organiser
dashboard. The platform is built milestone by milestone, and every milestone leaves the project
runnable, tested and documented.

| | |
|---|---|
| **Current milestone** | 1 - Project initialization (done) |
| **Next milestone** | 2 - Persistence foundation: PostgreSQL, Docker Compose, Flyway, JPA, Testcontainers |

## Scope of Milestone 1

Milestone 1 sets up the project, not the business features:

- A Maven multi-module build (`booking-domain`, `booking-service`, `booking-api`) driven by the Maven Wrapper.
- A runnable Spring Boot application with a `GET /api/v1/health` endpoint that needs no database.
- A package skeleton for every feature: users, venues, events, shows, inventory, bookings, payments, dashboard.
- Automated tests, build-time architecture checks, developer scripts for Linux/macOS and Windows, and GitHub Actions CI.

Deliberately **not** included yet: database access, Docker Compose, migrations, seed data, seat
inventory, booking logic, concurrency control, payments, Redis and Kafka. They are planned for later
milestones (see [Milestones](#milestones)).

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
| Persistence | Spring Data JPA / Hibernate | Hibernate 6.6.53 | Milestone 2 |
| Database | PostgreSQL and its JDBC driver | driver 42.7.11 | Milestone 2 |
| Migrations | Flyway | 11.7.2 | Milestone 2 |
| Integration tests | Testcontainers | 1.21.4 | Milestone 2 |
| Local infrastructure | Docker, Docker Compose | - | Milestone 2 |

All library and plugin versions except Spring Boot and the Maven Wrapper come from the Spring Boot
BOM, so later milestones add dependencies without writing version numbers.

## Prerequisites

- **JDK 21 or newer**: check with `java -version`. Either `JAVA_HOME` points to the JDK or `java` is
  on the `PATH`. The code is compiled for Java 21 even when you build with a newer JDK.
- **No Maven installation**: `mvnw` / `mvnw.cmd` download Maven 3.9.16 on first use.
- Internet access for the first build (Maven and the dependencies are cached in `~/.m2`).
- `curl` for `scripts/verify.sh` (preinstalled on macOS, most Linux distributions and Git Bash).
- Windows: PowerShell 5.1 or newer (built in). Git Bash or WSL can run the `.sh` scripts as well.
- Docker and PostgreSQL are **not** needed for Milestone 1.

## Directory structure

```text
event-ticketing-platform/
|-- pom.xml                    parent + aggregator POM (inherits spring-boot-starter-parent)
|-- mvnw, mvnw.cmd, .mvn/      Maven Wrapper, pins Maven 3.9.16
|-- booking-domain/            domain model; no Spring or web dependencies
|   `-- src/main/java/com/example/booking/domain/
|       common, users, venues, events, shows, inventory, bookings, payments
|-- booking-service/           application services (use cases); depends on booking-domain
|   `-- src/main/java/com/example/booking/service/
|       common, users, venues, events, shows, inventory, bookings, payments, dashboard
|-- booking-api/               Spring Boot application and REST API; depends on booking-service
|   |-- src/main/java/com/example/booking/
|   |   |-- BookingApiApplication.java
|   |   `-- api/ config, common, health, users, venues, events, shows,
|   |            inventory, bookings, payments, dashboard
|   |-- src/main/resources/    application.yml, application-dev.yml
|   `-- src/test/java/com/example/booking/
|-- scripts/                   dev, build, test, verify (.sh for bash, .ps1 for PowerShell)
|-- .github/workflows/ci.yml   CI on Linux and Windows
`-- .editorconfig, .gitattributes, .gitignore, .env.example
```

## Running the application

| Linux / macOS / Git Bash | Windows PowerShell |
|---|---|
| `./scripts/dev.sh` | `.\scripts\dev.ps1` |

Wait for `Started BookingApiApplication` in the output, then open
<http://localhost:8080/api/v1/health> in a browser or call it from a second terminal:

| Linux / macOS / Git Bash | Windows PowerShell |
|---|---|
| `curl http://localhost:8080/api/v1/health` | `curl.exe http://localhost:8080/api/v1/health` |

```json
{"status":"UP"}
```

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

## Building and testing

| Task | Linux / macOS / Git Bash | Windows PowerShell | Runs |
|---|---|---|---|
| Build | `./scripts/build.sh` | `.\scripts\build.ps1` | `mvnw clean package -DskipTests` |
| Test | `./scripts/test.sh` | `.\scripts\test.ps1` | `mvnw test` |
| Full verification | `./scripts/verify.sh` | `.\scripts\verify.ps1` | `mvnw clean verify`, then a smoke test of the packaged JAR |

- The scripts work from any directory, print the Maven command they run, and exit with a non-zero
  code and an `ERROR:` line when something fails.
- Extra arguments go to Maven, for example
  `./scripts/test.sh -Dtest=HealthControllerTest -Dsurefire.failIfNoSpecifiedTests=false`.
  In PowerShell, quote arguments that contain dots:
  `.\scripts\test.ps1 '-Dtest=HealthControllerTest' '-Dsurefire.failIfNoSpecifiedTests=false'`.
- `verify` starts the packaged JAR on port `18080` (override with `SMOKE_TEST_PORT`) and expects
  `{"status":"UP"}` from the health endpoint.
- Test reports are written to `booking-api/target/surefire-reports/`.

**Windows:** if PowerShell refuses to run the scripts ("running scripts is disabled on this
system"), allow local scripts once with `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or
run a single script with `powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1`.

**Linux/macOS:** if a script reports "Permission denied", the executable bit was lost (common when
files are committed from Windows). Run `chmod +x mvnw scripts/*.sh`, or start the script with
`bash scripts/verify.sh`.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pushes to `main` and on pull
requests. It runs `bash scripts/verify.sh` on `ubuntu-latest` and `.\scripts\verify.ps1` on
`windows-latest`, both with Temurin JDK 25, the same Java version as the development machine. CI
uses the same scripts as local development, so a passing local `verify` predicts a passing CI run.
Test reports are uploaded when a job fails.

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Project initialization | Done |
| 2 | Persistence foundation: PostgreSQL, Docker Compose, Flyway, JPA, Testcontainers | Next |
| 3-12 | API conventions, users and security, venues, events and shows, seat inventory, bookings and concurrency, payments, caching and messaging, dashboard, production readiness | Planned |

## Known limitations

- **Spring Boot 3.5.x no longer receives open-source support.** It ended on 2026-06-30, and 3.5.16 is
  the final 3.x release. This milestone required Spring Boot 3.x; plan the upgrade to Spring Boot
  4.x before any production use.
- No persistence yet: no entities, repositories, migrations or database connection.
- `/api/v1/health` is a liveness check only and does not check dependencies such as a database.
  Spring Boot Actuator probes and metrics are planned for a later milestone.
- No authentication or authorization: every endpoint is public.
- `booking-domain` and `booking-service` contain only package documentation so far.
