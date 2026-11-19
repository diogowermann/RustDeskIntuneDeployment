# Regression tests for RustDesk version parsing.
# Run on Windows: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\VersionParsing.Tests.ps1
# Does not execute installation or detection operations.

$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path -Parent $PSScriptRoot

$ValidCases = @(
    @{ Input = '1.5.3+71';      Expected = [version]'1.5.3.0' }
    @{ Input = '1.5.3';         Expected = [version]'1.5.3.0' }
    @{ Input = '1.5.3.0';       Expected = [version]'1.5.3.0' }
    @{ Input = '1.5.4+82';      Expected = [version]'1.5.4.0' }
    @{ Input = '1.5.3+build.71'; Expected = [version]'1.5.3.0' }
    @{ Input = '1.5.3.12+71';   Expected = [version]'1.5.3.12' }
    @{ Input = ' 1.5.3+71 ';    Expected = [version]'1.5.3.0' }
)

$InvalidCases = @(
    '',
    ' ',
    'not-a-version',
    '1.5.3+',
    '1.5.3+build..71',
    '1.5.3-rc.1',
    '1.5.3+71?'
)

foreach ($RelativePath in @('Source\install.ps1', 'Source\detect.ps1')) {
    $Source = Get-Content -LiteralPath (Join-Path $RepositoryRoot $RelativePath) -Raw
    $FunctionMatch = [regex]::Match($Source, '(?ms)^function ConvertTo-RustDeskVersion \{\r?\n.*?^\}')
    if (-not $FunctionMatch.Success) {
        throw "Cannot locate ConvertTo-RustDeskVersion in $RelativePath."
    }

    # Load only the parser function to avoid running deployment code in tests.
    . ([scriptblock]::Create($FunctionMatch.Value))

    foreach ($Case in $ValidCases) {
        $Actual = ConvertTo-RustDeskVersion $Case.Input
        if ($null -eq $Actual -or $Actual -ne $Case.Expected) {
            throw "$RelativePath failed to parse '$($Case.Input)': got '$Actual', expected '$($Case.Expected)'."
        }
    }

    foreach ($InputValue in $InvalidCases) {
        $Actual = ConvertTo-RustDeskVersion $InputValue
        if ($null -ne $Actual) {
            throw "$RelativePath incorrectly accepted '$InputValue': got '$Actual'."
        }
    }

    $Installed = ConvertTo-RustDeskVersion '1.5.3+71'
    $Required = ConvertTo-RustDeskVersion '1.5.3'
    $NewerRequired = ConvertTo-RustDeskVersion '1.5.4'
    if (-not ($Installed -ge $Required) -or -not ($Installed -lt $NewerRequired)) {
        throw "$RelativePath failed minimum-version comparisons."
    }

    Write-Output "PASS: $RelativePath (build metadata, numeric comparison, invalid formats)"
}
