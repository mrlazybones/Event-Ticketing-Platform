<#
.SYNOPSIS
    Runs the automated tests of every module.
.DESCRIPTION
    Extra arguments are passed to Maven; quote arguments that contain dots.
.EXAMPLE
    .\scripts\test.ps1
.EXAMPLE
    .\scripts\test.ps1 '-Dtest=HealthControllerTest' '-Dsurefire.failIfNoSpecifiedTests=false'
#>
$MavenArgs = @($args)
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    $null = Get-JavaExecutable
    Write-Step 'Running all automated tests'
    Invoke-Maven -Arguments (@('test') + $MavenArgs) `
        -FailureMessage 'Tests failed. See the Maven output above and the reports in *\target\surefire-reports\.'
    Write-Step 'All tests passed.'
}
