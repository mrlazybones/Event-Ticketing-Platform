<#
.SYNOPSIS
    Runs the full verification pipeline.
.DESCRIPTION
    1. mvnw.cmd clean verify - enforcer rules, compilation, database-independent tests,
       PostgreSQL integration tests (unless -DskipITs is passed) and packaging.
    2. Smoke test - when PostgreSQL accepts a TCP connection, starts the packaged JAR and checks
       /api/v1/health and /api/v1/health/readiness.
    Set DATABASE_CHECKS=skipped to run only the database-free part and say so. The Windows CI job
    does this because that runner has no Docker; the Linux job runs the database checks.
.EXAMPLE
    .\scripts\verify.ps1
#>
$MavenArgs = @($args)
. (Join-Path $PSScriptRoot 'lib\common.ps1')

function Get-DatabaseEndpoint {
    $url = if ($env:DB_URL) { $env:DB_URL } else { 'jdbc:postgresql://localhost:5432/event_ticketing' }
    if ($url -notmatch '^jdbc:postgresql://([^/:?#]+)(?::(\d+))?/') {
        throw "DB_URL is not a PostgreSQL JDBC URL: $url"
    }
    $port = if ($Matches[2]) { [int] $Matches[2] } else { 5432 }
    return [pscustomobject]@{ HostName = $Matches[1]; Port = $port }
}

function Test-DatabaseReachable([string] $HostName, [int] $Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $attempt = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $attempt.AsyncWaitHandle.WaitOne(2000, $false)) {
            return $false
        }
        $client.EndConnect($attempt)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Show-SmokeLog([string] $LogFile, [string] $ErrorLogFile) {
    if (Test-Path -LiteralPath $LogFile) {
        Get-Content -LiteralPath $LogFile -Tail 40 | Write-Host
    }
    if ((Test-Path -LiteralPath $ErrorLogFile) -and (Get-Item -LiteralPath $ErrorLogFile).Length -gt 0) {
        Write-Host '--- stderr ---'
        Get-Content -LiteralPath $ErrorLogFile -Tail 20 | Write-Host
    }
}

function Invoke-SmokeTest([string] $Java) {
    $port = if ($env:SMOKE_TEST_PORT) { [int] $env:SMOKE_TEST_PORT } else { 18080 }
    $timeoutSeconds = if ($env:SMOKE_TEST_TIMEOUT_SECONDS) { [int] $env:SMOKE_TEST_TIMEOUT_SECONDS } else { 60 }
    $jar = Get-ChildItem -Path 'booking-api\target' -Filter 'booking-api-*.jar' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq '.jar' } | Select-Object -First 1
    if (-not $jar) {
        throw 'No executable JAR found in booking-api\target. Did the package phase run?'
    }
    $logFile = Join-Path $RootDir 'booking-api\target\smoke-test.log'
    $errorLogFile = Join-Path $RootDir 'booking-api\target\smoke-test-stderr.log'
    $liveness = "http://localhost:$port/api/v1/health"
    $readiness = "http://localhost:$port/api/v1/health/readiness"

    Write-Step "Starting $($jar.Name) on port $port (log: booking-api\target\smoke-test.log)"
    $process = Start-Process -FilePath $Java -ArgumentList @('-jar', "`"$($jar.FullName)`"", "--server.port=$port") `
        -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    $null = $process.Handle
    try {
        $ProgressPreference = 'SilentlyContinue'
        $deadline = (Get-Date).AddSeconds($timeoutSeconds)
        $response = $null
        while (-not $response) {
            try {
                $response = Invoke-WebRequest -Uri $liveness -UseBasicParsing -TimeoutSec 2
            } catch {
                if ($process.HasExited) {
                    Show-SmokeLog $logFile $errorLogFile
                    throw "The application exited with code $($process.ExitCode) before it became healthy. Full log: $logFile"
                }
                if ((Get-Date) -ge $deadline) {
                    Show-SmokeLog $logFile $errorLogFile
                    throw "No response from $liveness within $timeoutSeconds s. Is port $port free? Override it with SMOKE_TEST_PORT."
                }
                Start-Sleep -Seconds 1
            }
        }
        if ($response.Content -notmatch '"status"\s*:\s*"UP"') {
            throw "Unexpected response from ${liveness}: $($response.Content)"
        }
        Write-Step "Liveness responded: $($response.Content)"
        $ready = Invoke-WebRequest -Uri $readiness -UseBasicParsing -TimeoutSec 5
        if ($ready.StatusCode -ne 200 -or $ready.Content -notmatch '"status"\s*:\s*"UP"') {
            throw "Database readiness check failed: HTTP $($ready.StatusCode) $($ready.Content)"
        }
        Write-Step "Readiness responded: $($ready.Content)"
    } finally {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    }
}

Invoke-FromRepositoryRoot {
    $java = Get-JavaExecutable
    $previousEnvironment = Import-DotEnv
    try {
        $skipIntegrationTests = @($MavenArgs | Where-Object { $_ -match '(?i)^-DskipITs(?:=true)?$' }).Count -gt 0
        Write-Step 'Step 1/2: Maven verify (enforcer rules, compilation, tests, packaging)'
        Invoke-Maven -Arguments (@('clean', 'verify') + $MavenArgs) -FailureMessage 'Maven verification failed. See the output above.'
        if ($env:DATABASE_CHECKS -eq 'skipped') {
            Write-Step 'PostgreSQL integration tests and the packaged-JAR smoke test were not run (DATABASE_CHECKS=skipped). The Linux CI job runs them against PostgreSQL.'
            return
        }
        $database = Get-DatabaseEndpoint
        Write-Step "Step 2/2: Smoke test when PostgreSQL accepts connections at $($database.HostName):$($database.Port)"
        if (Test-DatabaseReachable $database.HostName $database.Port) {
            Invoke-SmokeTest -Java $java
        } elseif ($skipIntegrationTests) {
            throw "NOT VERIFIED: PostgreSQL is not reachable at $($database.HostName):$($database.Port), and integration tests were skipped."
        } else {
            Write-Step "PostgreSQL is not reachable at $($database.HostName):$($database.Port). The packaged JAR was not started. Connectivity was verified by the Testcontainers integration tests."
        }
        Write-Step 'Verification succeeded.'
    } finally {
        Restore-Environment $previousEnvironment
    }
}
