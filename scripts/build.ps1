<#
.SYNOPSIS
    Compiles and packages all modules. Tests are compiled but not run; use test.ps1 or verify.ps1 for that.
.DESCRIPTION
    Extra arguments are passed to Maven; quote arguments that contain dots.
.EXAMPLE
    .\scripts\build.ps1
#>
$MavenArgs = @($args)
. (Join-Path $PSScriptRoot 'lib\common.ps1')

Invoke-FromRepositoryRoot {
    $null = Get-JavaExecutable
    Write-Step 'Compiling and packaging all modules (tests are compiled but not run)'
    Invoke-Maven -Arguments (@('clean', 'package', '-DskipTests') + $MavenArgs) `
        -FailureMessage 'Build failed. See the Maven output above.'
    Write-Step 'Build succeeded. Executable JAR: booking-api\target\booking-api-*.jar'
}
