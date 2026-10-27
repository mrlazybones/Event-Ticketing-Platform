<#
.SYNOPSIS
    Prints the recent PostgreSQL logs. Pass -Follow to keep streaming them.
.EXAMPLE
    .\scripts\db-logs.ps1
.EXAMPLE
    .\scripts\db-logs.ps1 -Follow
#>
$Follow = @($args) -contains '-Follow'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    Require-Docker
    if ($Follow) {
        Invoke-DockerCompose @('logs', '-f', 'postgres')
    } else {
        Invoke-DockerCompose @('logs', '--tail', '100', 'postgres')
    }
}
