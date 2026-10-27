<#
.SYNOPSIS
    Starts booking-api locally through the Maven Wrapper (spring-boot:run, default profile "dev").
.DESCRIPTION
    Variables from a .env file at the repository root (see .env.example) are applied while the
    application runs and removed again afterwards. Extra arguments are passed to Maven; quote
    arguments that contain dots, for example '-Dspring-boot.run.arguments=--server.port=9090'.
.EXAMPLE
    .\scripts\dev.ps1
.EXAMPLE
    .\scripts\dev.ps1 '-Dspring-boot.run.arguments=--server.port=9090'
#>
$MavenArgs = @($args)
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    $null = Get-JavaExecutable
    $previousEnvironment = Import-DotEnv
    try {
        $port = if ($env:SERVER_PORT) { $env:SERVER_PORT } else { '8080' }
        Write-Step "Starting booking-api (Ctrl+C stops it)"
        Write-Step "Liveness:  http://localhost:$port/api/v1/health"
        Write-Step "Readiness: http://localhost:$port/api/v1/health/readiness"
        Invoke-Maven -Arguments (@('-pl', 'booking-api', '-am', 'spring-boot:run') + $MavenArgs) `
            -FailureMessage 'booking-api failed to start or stopped with an error. See the output above.'
    } finally {
        Restore-Environment $previousEnvironment
    }
}
