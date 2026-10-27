<#
.SYNOPSIS
    Shows the PostgreSQL container and whether its volume exists.
.EXAMPLE
    .\scripts\db-status.ps1
#>
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    Require-Docker
    Invoke-DockerCompose @('ps')
    Write-Step 'Volume'
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & docker volume ls --filter name=event-ticketing-postgres
        if ($LASTEXITCODE -ne 0) {
            throw 'docker volume ls failed.'
        }
    } finally {
        $ErrorActionPreference = $savedPreference
    }
}
