<#
.SYNOPSIS
    Runs the full verification pipeline.
.DESCRIPTION
    1. mvnw.cmd clean verify - Maven Enforcer rules, compilation with warnings treated as errors,
       all tests and packaging.
    2. Smoke test - starts the packaged JAR and checks that /api/v1/health reports UP.
    Environment variables: SMOKE_TEST_PORT (default 18080), SMOKE_TEST_TIMEOUT_SECONDS (default 60).
.EXAMPLE
    .\scripts\verify.ps1
#>
$MavenArgs = @($args)
. (Join-Path $PSScriptRoot 'lib\common.ps1')

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
    $url = "http://localhost:$port/api/v1/health"

    Write-Step "Starting $($jar.Name) on port $port (log: booking-api\target\smoke-test.log)"
    $process = Start-Process -FilePath $Java -ArgumentList @('-jar', "`"$($jar.FullName)`"", "--server.port=$port") `
        -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    # Reading Handle keeps it open, otherwise ExitCode stays empty once the process has exited.
    $null = $process.Handle
    try {
        $ProgressPreference = 'SilentlyContinue'
        $deadline = (Get-Date).AddSeconds($timeoutSeconds)
        $response = $null
        while (-not $response) {
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
            } catch {
                if ($process.HasExited) {
                    Get-Content -LiteralPath $logFile -Tail 40 | Write-Host
                    throw "The application exited with code $($process.ExitCode) before it became healthy. Full log: $logFile"
                }
                if ((Get-Date) -ge $deadline) {
                    Get-Content -LiteralPath $logFile -Tail 40 | Write-Host
                    throw "No response from $url within $timeoutSeconds s. Is port $port free? Override it with SMOKE_TEST_PORT."
                }
                Start-Sleep -Seconds 1
            }
        }
        if ($response.Content -notmatch '"status"\s*:\s*"UP"') {
            throw "Unexpected response from ${url}: $($response.Content)"
        }
        Write-Step "Health endpoint responded: $($response.Content)"
    } finally {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    }
}

Invoke-FromRepositoryRoot {
    $java = Get-JavaExecutable
    Write-Step 'Step 1/2: Maven verify (enforcer rules, compilation, tests, packaging)'
    Invoke-Maven -Arguments (@('clean', 'verify') + $MavenArgs) -FailureMessage 'Maven verification failed. See the output above.'
    Write-Step 'Step 2/2: Smoke test of the packaged application'
    Invoke-SmokeTest -Java $java
    Write-Step 'Verification succeeded.'
}
