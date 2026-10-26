# Shared helpers for the PowerShell scripts in this directory. Dot-source this file; do not run it directly.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RootDir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Write-Step([string] $Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# Runs $Body from the repository root and restores the caller's location afterwards.
# Any error is reported on one line and turned into exit code 1.
function Invoke-FromRepositoryRoot([scriptblock] $Body) {
    Push-Location -LiteralPath $RootDir
    try {
        & $Body
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
}

# Returns the java executable that the Maven Wrapper uses as well.
function Get-JavaExecutable {
    if ($env:JAVA_HOME) {
        $java = Join-Path $env:JAVA_HOME 'bin\java.exe'
        if (-not (Test-Path -LiteralPath $java -PathType Leaf)) {
            throw "JAVA_HOME is '$env:JAVA_HOME', but '$java' does not exist. Point JAVA_HOME to a JDK 21+ installation."
        }
        return $java
    }
    $command = Get-Command java.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        throw 'Java was not found. Install JDK 21 or newer, then set JAVA_HOME or add java to PATH.'
    }
    return $command.Source
}

function Invoke-Maven([string[]] $Arguments, [string] $FailureMessage) {
    $wrapper = Join-Path $RootDir 'mvnw.cmd'
    if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
        throw "Maven Wrapper not found at $wrapper."
    }
    Write-Step "mvnw.cmd $($Arguments -join ' ')"
    # Windows PowerShell turns stderr output of native commands into errors under 'Stop'; the exit code decides instead.
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $wrapper @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }
    if ($exitCode -ne 0) {
        throw "$FailureMessage (Maven exit code $exitCode)"
    }
}

# Copies KEY=VALUE lines from .env into this process and returns the previous values for Restore-Environment.
function Import-DotEnv {
    $previous = @{}
    $path = Join-Path $RootDir '.env'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $previous
    }
    Write-Step 'Loading environment variables from .env'
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        $text = $line.Trim()
        if ($text -eq '' -or $text.StartsWith('#')) {
            continue
        }
        if ($text -notmatch '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            throw ".env line $lineNumber is not a KEY=VALUE pair: $line"
        }
        $name = $Matches[1]
        $value = $Matches[2]
        if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
            $value = $Matches[1]
        }
        if (-not $previous.ContainsKey($name)) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
    return $previous
}

function Restore-Environment([hashtable] $Previous) {
    foreach ($name in $Previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $Previous[$name], 'Process')
    }
}
