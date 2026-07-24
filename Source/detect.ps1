$ExpectedHost       = "" # Same as in install.ps1
$OrganizationName   = "" # Same as in install.ps1
$MarkerFile         = "C:\ProgramData\$OrganizationName\IntuneMarkers\RustDesk-Configured.marker"

$ExePaths = @(
    "$env:ProgramFiles\RustDesk\rustdesk.exe",
    "$env:ProgramFiles\RustDesk\RustDesk.exe",
    "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe",
    "${env:ProgramFiles(x86)}\RustDesk\RustDesk.exe"
)

$ConfigPaths = @(
    "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml",
    "C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config\RustDesk2.toml",
    "C:\ProgramData\RustDesk\config\RustDesk2.toml"
)

$ExeExists = $false
foreach ($Path in $ExePaths) {
    if (Test-Path $Path) {
        $ExeExists = $true
        break
    }
}

$ConfigOk = $false
foreach ($Path in $ConfigPaths) {
    if (Test-Path $Path) {
        if (Select-String -Path $Path -SimpleMatch $ExpectedHost -Quiet) {
            $ConfigOk = $true
            break
        }
    }
}

if ($ExeExists -and $ConfigOk -and (Test-Path $MarkerFile)) {
    Write-Output "RustDesk installed and configured correctly."
    exit 0
}

Write-Output "RustDesk not installed/configured correctly."
exit 1