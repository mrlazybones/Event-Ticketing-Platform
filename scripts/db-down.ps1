<#
.SYNOPSIS
    Stops PostgreSQL. The named volume is kept, so the data remains.
.EXAMPLE
    .\scripts\db-down.ps1
#>
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    Require-Docker
    Invoke-DockerCompose @('stop')
    Write-Step 'PostgreSQL is stopped. The volume event-ticketing-postgres was kept.'
}
