<#
.SYNOPSIS
    Deletes the local PostgreSQL container and its volume. This erases the database.
.DESCRIPTION
    Refuses to run unless -Force is passed. Normal stop (db-down.ps1) does not delete data.
.EXAMPLE
    .\scripts\db-reset.ps1 -Force
#>
$Force = @($args) -contains '-Force'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    if (-not $Force) {
        throw 'Refusing to delete the database volume. Re-run with -Force only when you mean to erase local data: .\scripts\db-reset.ps1 -Force'
    }
    Require-Docker
    Invoke-DockerCompose @('down', '-v')
    Write-Step 'PostgreSQL container and volume event-ticketing-postgres were deleted.'
}
