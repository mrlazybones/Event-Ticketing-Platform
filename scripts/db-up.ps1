<#
.SYNOPSIS
    Starts PostgreSQL with Docker Compose and waits until its health check passes.
.EXAMPLE
    .\scripts\db-up.ps1
#>
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    Require-Docker
    Invoke-DockerCompose @('up', '-d')
    Wait-PostgresHealthy
    Write-Step 'PostgreSQL is healthy. From the host, the app uses jdbc:postgresql://localhost:<DB_HOST_PORT>/<DB_NAME> (defaults: localhost:5432/event_ticketing).'
}
