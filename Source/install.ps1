$ErrorActionPreference = "Stop"

# ============================================================
# RustDesk - Install and configure via Intune
# ============================================================

# === ADJUST BASED ON YOUR SETTINGS ===
$RustDeskServer     = ""
$RustDeskHbbsPort   = ""
$RustDeskHbbrPort   = ""
$RustDeskApiPort    = ""
$RustDeskKey        = ""
# ===================

# Also adjust the organization name for log and marker paths. This is optional, but recommended to avoid conflicts with other scripts.
$OrganizationName = ""

$ScriptLogDir   = "C:\ProgramData\$OrganizationName\IntuneLogs"
$ScriptLog      = Join-Path $ScriptLogDir "RustDesk-Intune-Install.log"

$MarkerDir = "C:\ProgramData\$OrganizationName\IntuneMarkers"
$MarkerFile = Join-Path $MarkerDir "RustDesk-Configured.marker"

$MsiLog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\RustDesk-msi-install.log"

New-Item -Path $ScriptLogDir -ItemType Directory -Force | Out-Null
New-Item -Path $MarkerDir -ItemType Directory -Force | Out-Null

Start-Transcript -Path $ScriptLog -Append

try {
    Write-Output "==== Starting RustDesk installation/configuration ===="

    $Msi = Get-ChildItem -Path $PSScriptRoot -Filter "*.msi" | Select-Object -First 1

    if (-not $Msi) {
        throw "RustDesk MSI installation file not found in: $PSScriptRoot"
    }

    Write-Output "MSI found: $($Msi.FullName)"

    # Remove old marker file before installation to ensure a clean state. This prevents false positives in detection scripts.
    Remove-Item $MarkerFile -Force -ErrorAction SilentlyContinue

    # Stop RustDesk before installation/reinstallation
    Write-Output "Stopping RustDesk processes..."
    Get-Process | Where-Object {
        $_.Name -like "RustDesk*" -or $_.Name -like "RuntimeBroker_rustdesk*"
    } | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Output "Stopping RustDesk service, if it exists..."
    Stop-Service -Name "RustDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # Install MSI
    Write-Output "Installing RustDesk MSI..."

    $InstallFolder = "${env:ProgramFiles(x86)}\RustDesk"

    $MsiArgs = @(
        "/i"
        "`"$($Msi.FullName)`""
        "/qn"
        "/norestart"
        "INSTALLFOLDER=`"$InstallFolder`""
        "CREATESTARTMENUSHORTCUTS=`"Y`""
        "CREATEDESKTOPSHORTCUTS=`"N`""
        "INSTALLPRINTER=`"N`""
        "/l*v"
        "`"$MsiLog`""
    )

    $MsiProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArgs -Wait -PassThru
    $MsiExitCode = $MsiProcess.ExitCode

    Write-Output "MSI ExitCode: $MsiExitCode"

    if ($MsiExitCode -eq 1618) {
        Write-Output "Another MSI installation is currently in progress. Returning 1618 so Intune can retry."

        try {
            Stop-Transcript
        } catch {}

        exit 1618
    }

    if ($MsiExitCode -notin @(0, 3010)) {
        throw "Failed to install MSI. ExitCode: $MsiExitCode"
    }

    Start-Sleep -Seconds 8

    # Find executable
    $PossibleExePaths = @(
        "$env:ProgramFiles\RustDesk\rustdesk.exe",
        "$env:ProgramFiles\RustDesk\RustDesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\RustDesk.exe"
    )

    $RustDeskExe = $PossibleExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $RustDeskExe) {
        throw "RustDesk.exe not found after installation."
    }

    Write-Output "RustDesk found at: $RustDeskExe"

    # Stop again before writing config
    Write-Output "Stopping RustDesk before writing configuration..."
    Get-Process | Where-Object {
        $_.Name -like "RustDesk*" -or $_.Name -like "RuntimeBroker_rustdesk*"
    } | Stop-Process -Force -ErrorAction SilentlyContinue

    Stop-Service -Name "RustDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # Creates RustDesk2.toml 
    # Does not inclide local-ip-addr: this is a specific setting for each computer.
    # Does not include trusted_devices: this should be specific to each computer.
    $RustDeskConfig = @"
rendezvous_server = '$RustDeskServer`:$RustDeskHbbsPort'
nat_type = 1
serial = 0
unlock_pin = ''
trusted_devices = ''

[options]
av1-test = 'Y'
relay-server = '$RustDeskServer`:$RustDeskHbbrPort'
custom-rendezvous-server = '$RustDeskServer`:$RustDeskHbbsPort'
api-server = 'http://$RustDeskServer`:$RustDeskApiPort'
key = '$RustDeskKey'
"@

    # Settings locations that RustDesk can use in service/SYSTEM/user context
    $ConfigTargets = New-Object System.Collections.Generic.List[string]

    $ConfigTargets.Add("C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config")
    $ConfigTargets.Add("C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config")
    $ConfigTargets.Add("C:\ProgramData\RustDesk\config")

    # Default profile, for new users who have not logged in yet
    if (Test-Path "C:\Users\Default") {
        $ConfigTargets.Add("C:\Users\Default\AppData\Roaming\RustDesk\config")
    }

    # Existing user profiles
    $ProfileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    if (Test-Path $ProfileListPath) {
        Get-ChildItem $ProfileListPath | ForEach-Object {
            $ProfilePath = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).ProfileImagePath

            if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
                $ProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)

                if (
                    $ProfilePath -like "C:\Users\*" -and
                    $ProfilePath -notlike "*\Public" -and
                    $ProfilePath -notlike "*\Default" -and
                    $ProfilePath -notlike "*\Default User" -and
                    $ProfilePath -notlike "*\All Users"
                ) {
                    $ConfigTargets.Add((Join-Path $ProfilePath "AppData\Roaming\RustDesk\config"))
                }
            }
        }
    }

    $ConfigTargets = $ConfigTargets | Select-Object -Unique

    Write-Output "Writing RustDesk2.toml configuration..."

    foreach ($Target in $ConfigTargets) {
        Write-Output "Writing to: $Target"

        New-Item -Path $Target -ItemType Directory -Force | Out-Null

        $ConfigFile = Join-Path $Target "RustDesk2.toml"

        Set-Content -Path $ConfigFile -Value $RustDeskConfig -Encoding UTF8 -Force
    }

    # Real validation: do not trust the exit code of --config
    Write-Output "Validating written configuration..."

    $ExpectedHost = $RustDeskServer
    $ValidConfigs = New-Object System.Collections.Generic.List[string]

    foreach ($Target in $ConfigTargets) {
        $ConfigFile = Join-Path $Target "RustDesk2.toml"

        if (Test-Path $ConfigFile) {
            if (Select-String -Path $ConfigFile -SimpleMatch $ExpectedHost -Quiet) {
                Write-Output "Config OK: $ConfigFile"
                $ValidConfigs.Add($ConfigFile)
            } else {
                Write-Output "Config without expected server: $ConfigFile"
            }
        }
    }

    if ($ValidConfigs.Count -eq 0) {
        throw "No RustDesk2.toml contains the expected server: $ExpectedHost"
    }

    # Confirm service
    $Service = Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue

    if (-not $Service) {
        Write-Output "Service RustDesk not found. Trying to install service..."

        $SvcProcess = Start-Process `
            -FilePath $RustDeskExe `
            -ArgumentList @("--install-service") `
            -Wait `
            -PassThru `
            -WindowStyle Hidden

        Write-Output "Install service ExitCode: $($SvcProcess.ExitCode)"
        Start-Sleep -Seconds 5
    }

    # Inicia servico
    Write-Output "Starting RustDesk service..."
    Start-Service -Name "RustDesk" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    # This is completely optional and not recommended for security reasons, 
    #   but if you want to set a permanent password for RustDesk, you can do so here. 

    $EnablePasswordConfig = $false # Change to $true if you want to set a permanent password

    # Be aware that this password will be stored in the configuration for ALL DEVICES AND USERS 
    # the application is installed on and could be a security risk if not handled properly.
    if ($EnablePasswordConfig) {
        Write-Output "Setting permanent password for RustDesk..."
        & $RustDeskExe --password "Lq3720*1100"
        Start-Sleep -Seconds 3
    }

    $Service = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue

    if ($Service) {
        Write-Output "RustDesk Service:"
        Write-Output "Name: $($Service.Name)"
        Write-Output "StartName: $($Service.StartName)"
        Write-Output "State: $($Service.State)"
        Write-Output "PathName: $($Service.PathName)"
    } else {
        throw "RustDesk Service not found after installation."
    }

    $Version = (Get-Item $RustDeskExe).VersionInfo.ProductVersion

    @"
RustDesk configured via Intune
DateTime: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Server: $RustDeskServer
Exe: $RustDeskExe
Version: $Version
Validation: RustDesk2.toml has the expected server: $ExpectedHost
Valid configs:
$($ValidConfigs -join "`r`n")
"@ | Set-Content -Path $MarkerFile -Encoding UTF8 -Force

    Write-Output "Marker created at: $MarkerFile"
    Write-Output "==== RustDesk installed/configured successfully ===="

    Stop-Transcript
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"

    try {
        Stop-Transcript
    } catch {}

    exit 1
}