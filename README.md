# RustDesk Intune Deployment

This project provides PowerShell scripts to deploy, configure, and manage [RustDesk](https://rustdesk.com/) — an open-source remote desktop application — via Microsoft Intune.

## Overview

The deployment consists of three PowerShell scripts designed to work with Microsoft Intune's Win32 app deployment model:

| Script | Purpose |
|--------|---------|
| `install.ps1` | Installs the RustDesk MSI, writes the `RustDesk2.toml` configuration to all relevant user and system profile locations, installs and starts the RustDesk service, and creates a marker file for detection. |
| `uninstall.ps1` | Uninstalls RustDesk by querying WMI for the product and running `msiexec /x`. |
| `detect.ps1` | Checks whether RustDesk is installed, configured with the expected server, and the marker file exists. Used by Intune to determine compliance. |

## Prerequisites

- A self-hosted RustDesk server (or access to a RustDesk server) with the following information:
  - Server address
  - HBBS port (rendezvous server)
  - HBBR port (relay server)
  - API port
  - Key
- The RustDesk MSI installer file.

> **It is recommended to download the latest MSI file for RustDesk and name it `RustDesk.msi`** before packaging the deployment. This ensures the `install.ps1` script can automatically detect and use it.

## Configuration

Before packaging for Intune, edit the following variables in both `install.ps1` and `detect.ps1`:

### `install.ps1`

```powershell
$RustDeskServer     = ""   # Your RustDesk server address
$RustDeskHbbsPort   = ""   # HBBS (rendezvous) port
$RustDeskHbbrPort   = ""   # HBBR (relay) port
$RustDeskApiPort    = ""   # API port
$RustDeskKey        = ""   # Your RustDesk key
$OrganizationName   = ""   # Used for log and marker directory paths
```

### `detect.ps1`

```powershell
$ExpectedHost       = ""   # Same as $RustDeskServer in install.ps1
$OrganizationName   = ""   # Same as in install.ps1
```

## Packaging for Intune

1. Place the `RustDesk.msi` file in the same directory as the scripts.
2. Use the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) to package the folder into an `.intunewin` file:

   ```powershell
   C:\Path\to\IntuneWinAppUtil.exe -c .\Source -s install.ps1 -o .\Output
   ```

3. Upload the resulting `.intunewin` file to Microsoft Intune as a Win32 app.
4. Configure the install command as:

   ```
   powershell.exe -ExecutionPolicy Bypass -File install.ps1
   ```

5. Configure the uninstall command as:

   ```
   powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1
   ```

6. Set the detection rule to use the custom script `detect.ps1`.

## How It Works

### Installation (`install.ps1`)

1. Locates the `.msi` file in the script directory.
2. Stops any running RustDesk processes and services.
3. Installs the MSI silently (`/qn`).
4. Writes the `RustDesk2.toml` configuration file to all relevant locations:
   - `C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\`
   - `C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config\`
   - `C:\ProgramData\RustDesk\config\`
   - Default user profile (`C:\Users\Default\`)
   - All existing user profiles
5. Installs and starts the RustDesk system service.
6. Creates a marker file for detection purposes.

### Detection (`detect.ps1`)

Verifies three conditions:
- RustDesk executable exists in one of the expected paths.
- At least one `RustDesk2.toml` configuration file contains the expected server address.
- The marker file exists.

Returns exit code `0` if all conditions are met, `1` otherwise.

### Uninstallation (`uninstall.ps1`)

Queries WMI for the RustDesk product and runs a silent uninstall via `msiexec /x`.

## Optional: Permanent Password

The `install.ps1` script includes an optional feature to set a permanent password for RustDesk. This is **disabled by default** for security reasons. If enabled, the password will be applied to all devices and users. To enable it, set `$EnablePasswordConfig` to `$true` in `install.ps1` and update the password value.

## File Structure

```
RustDeskIntune/
├── install.ps1         # Installation and configuration script
├── uninstall.ps1       # Uninstallation script
├── detect.ps1          # Detection script for Intune
├── RustDesk.msi        # RustDesk installer (not included — download separately)
├── Output/
│   └── install.intunewin  # Packaged Intune deployment file
└── README.md           # This file
```

## License

This project is provided as-is for deploying RustDesk via Microsoft Intune. RustDesk itself is licensed separately — refer to the [RustDesk repository](https://github.com/rustdesk/rustdesk) for its licensing terms.