$ExpectedHost       = "" # Same as in install.ps1
$OrganizationName   = "" # Same as in install.ps1
$RustDeskVersion    = "" # Minimum RustDesk version; match install.ps1 and the packaged MSI.
$MarkerFile         = "C:\ProgramData\$OrganizationName\IntuneMarkers\RustDesk-Configured.marker"

function ConvertTo-RustDeskVersion {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    # RustDesk can report ProductVersion with build metadata (e.g., 1.5.3+71).
    # Validate the full value, then compare only the numeric version components.
    $NormalizedValue = $Value.Trim()
    if ($NormalizedValue -notmatch '^([0-9]+\.[0-9]+(?:\.[0-9]+){0,2})(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') {
        return $null
    }

    $NumericVersion = $Matches[1]
    $ParsedVersion = $null
    if (-not [version]::TryParse($NumericVersion, [ref]$ParsedVersion)) {
        return $null
    }

    # Treat missing build/revision components as zero (e.g., 1.5.3 == 1.5.3.0).
    return [version]::new(
        $ParsedVersion.Major,
        $ParsedVersion.Minor,
        [Math]::Max(0, $ParsedVersion.Build),
        [Math]::Max(0, $ParsedVersion.Revision)
    )
}

$RequiredVersion = ConvertTo-RustDeskVersion $RustDeskVersion
if (-not $RequiredVersion) {
    Write-Output "Invalid RustDeskVersion. Set a numeric version (for example, 1.4.4) in detect.ps1."
    exit 1
}

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

$ServiceExecutable = $null
$RustDeskService = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue
if ($RustDeskService -and $RustDeskService.PathName -match '^\s*"?(.+?\\rustdesk\.exe)"?(?:\s|$)') {
    $ServiceExecutable = $Matches[1]
}

# Do not declare an installed RustDesk client healthy when its service is unavailable.
$ServiceOk = [bool]($RustDeskService -and
    $RustDeskService.State -eq "Running" -and
    $RustDeskService.StartMode -eq "Auto" -and
    $ServiceExecutable -and
    (Test-Path -LiteralPath $ServiceExecutable))

# Prefer the executable used by the service instead of an old copy in another folder.
$RustDeskExe = $null
if ($ServiceExecutable -and (Test-Path -LiteralPath $ServiceExecutable)) {
    $RustDeskExe = $ServiceExecutable
} else {
    $RustDeskExe = $ExePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

$VersionOk = $false
if ($RustDeskExe) {
    $InstalledVersionText = (Get-Item -LiteralPath $RustDeskExe).VersionInfo.ProductVersion
    $InstalledVersion = ConvertTo-RustDeskVersion $InstalledVersionText
    if ($InstalledVersion) {
        $VersionOk = $InstalledVersion -ge $RequiredVersion
        if (-not $VersionOk) {
            Write-Output "RustDesk version $InstalledVersionText is below required $RustDeskVersion."
        }
    } else {
        Write-Output "Cannot parse RustDesk ProductVersion: $InstalledVersionText"
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

if ($RustDeskExe -and $VersionOk -and $ConfigOk -and $ServiceOk -and (Test-Path $MarkerFile)) {
    Write-Output "RustDesk $InstalledVersionText installed and configured correctly (required: $RustDeskVersion)."
    exit 0
}

Write-Output "RustDesk missing, outdated, service not running/automatic, or not configured correctly."
exit 1