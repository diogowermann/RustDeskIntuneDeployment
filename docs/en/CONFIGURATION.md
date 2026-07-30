# Configuration Reference

[English](CONFIGURATION.md) | [Português](../pt-BR/CONFIGURATION.md)

## Scope

The current project stores environment-specific deployment values directly in `Source/install.ps1` and `Source/detect.ps1` before the Intune package is built.

Because those values become part of the `.intunewin`, every configuration change requires a controlled package rebuild and deployment update.

## Required Values

### Installer values

Edit `Source/install.ps1`:

```powershell
$RustDeskServer   = 'rustdesk.example.internal'
$RustDeskHbbsPort = '21116'
$RustDeskHbbrPort = '21117'
$RustDeskApiPort  = '21114'
$RustDeskKey      = 'SERVER-PUBLIC-KEY'
$OrganizationName = 'orgname'
```

### Detection values

Edit `Source/detect.ps1`:

```powershell
$ExpectedHost     = 'rustdesk.example.internal'
$OrganizationName = 'orgname'
```

`$ExpectedHost` must match `$RustDeskServer`, and `$OrganizationName` must match in both scripts.

## Field Definitions

| Field | Used by | Purpose | Data classification |
|---|---|---|---|
| `$RustDeskServer` | Installer | Hostname or IP used for HBBS, HBBR, and API values. | Internal infrastructure metadata. |
| `$RustDeskHbbsPort` | Installer | Rendezvous service port. | Internal network metadata. |
| `$RustDeskHbbrPort` | Installer | Relay service port. | Internal network metadata. |
| `$RustDeskApiPort` | Installer | API endpoint port. | Internal network metadata. |
| `$RustDeskKey` | Installer | RustDesk server public key distributed to clients. | Public authentication material; not a secret, but integrity-sensitive. |
| `$OrganizationName` | Installer and detection | Names organization-specific log and marker directories. | Organization identifier. |
| `$ExpectedHost` | Detection | String expected in a machine-level `RustDesk2.toml`. | Internal infrastructure metadata. |

## Public Key Versus Private Key

`$RustDeskKey` is intended to contain the public key clients use to identify the RustDesk server.

Do not include:

- the server private key;
- API credentials;
- administrator credentials;
- user passwords;
- personal access tokens;
- certificates with private keys.

A public key is distributable, but it remains integrity-sensitive. Replacing it can redirect trust to a different server identity.

## Generated RustDesk Configuration

The installer creates a TOML document equivalent to:

```toml
rendezvous_server = 'rustdesk.example.internal:21116'
nat_type = 1
serial = 0
unlock_pin = ''
trusted_devices = ''

[options]
av1-test = 'Y'
relay-server = 'rustdesk.example.internal:21117'
custom-rendezvous-server = 'rustdesk.example.internal:21116'
api-server = 'http://rustdesk.example.internal:21114'
key = 'SERVER-PUBLIC-KEY'
```

The project currently writes the API URL using `http://`. Review whether the selected RustDesk deployment supports and requires HTTPS or a protected internal network path. Do not expose an unencrypted management API across untrusted networks.

## Configuration Destinations

The same generated content is written to:

```text
C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\ProgramData\RustDesk\config\RustDesk2.toml
C:\Users\Default\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Users\<existing-profile>\AppData\Roaming\RustDesk\config\RustDesk2.toml
```

The exact existing-user list is generated from the Windows profile registry.

## Organization Name

`$OrganizationName` is used to derive:

```text
C:\ProgramData\{OrganizationName}\IntuneLogs\RustDesk-Intune-Install.log
C:\ProgramData\{OrganizationName}\IntuneMarkers\RustDesk-Configured.marker
```

Use a stable, filesystem-safe short name.

Avoid:

- path separators;
- trailing spaces;
- reserved Windows characters;
- values that reveal sensitive customer names in public examples;
- changing the value between installer and detection scripts.

Changing the organization name changes the expected marker path. Intune detection will fail until the new package completes installation and creates the new marker.

## MSI Selection

The installer uses:

```powershell
Get-ChildItem -Path $PSScriptRoot -Filter '*.msi' | Select-Object -First 1
```

Therefore:

- keep only one intended MSI in `Source/`;
- do not retain old MSI versions in the same package directory;
- use an explicit release procedure to record file name, version, signature, and SHA-256;
- rebuild the package whenever the MSI changes.

The file does not technically need to be named `RustDesk.msi`, but that name is recommended for clarity.

## MSI Installation Properties

The installer currently requests:

| Property | Value |
|---|---|
| UI | Quiet (`/qn`) |
| Restart | Suppressed (`/norestart`) |
| Install folder | `%ProgramFiles(x86)%\RustDesk` |
| Start menu shortcuts | Enabled |
| Desktop shortcuts | Disabled |
| Virtual printer | Disabled |
| MSI logging | Verbose |

Test these properties against the exact RustDesk MSI version used. Vendor package properties can change between releases.

## Permanent Password Block

The installer contains an optional block controlled by:

```powershell
$EnablePasswordConfig = $false
```

Keep it disabled unless the credential design has been formally reviewed.

Do not:

- commit a real password to Git;
- embed one shared password in all endpoint packages;
- place a secret in the README, marker, or logs;
- assume `.intunewin` is a secret vault;
- reuse support-team credentials as endpoint credentials.

Preferred approaches include unique device credentials, server-governed authorization, identity-integrated access, just-in-time access, and audited credential rotation.

## Synchronization Between Scripts

Before every build, compare:

| Installer | Detection | Required relationship |
|---|---|---|
| `$RustDeskServer` | `$ExpectedHost` | Same value. |
| `$OrganizationName` | `$OrganizationName` | Same value. |

A mismatch can produce these outcomes:

- installation succeeds but detection fails;
- marker exists under a different organization path;
- Intune repeatedly retries installation;
- reporting indicates failure even when RustDesk runs.

## Validation Checklist

Before packaging:

- [ ] Server hostname or address is correct.
- [ ] HBBS port is correct.
- [ ] HBBR port is correct.
- [ ] API port and transport are approved.
- [ ] Public key matches the target server.
- [ ] No private key or credential is present.
- [ ] Organization name is safe and consistent.
- [ ] Detection host matches installer host.
- [ ] Only one MSI exists in `Source/`.
- [ ] MSI signature and hash were verified.
- [ ] Password block is disabled.
- [ ] Public repository examples are sanitized.

## Configuration Change Procedure

1. document the requested infrastructure change;
2. update installer values;
3. update matching detection values;
4. verify the MSI and source directory;
5. review the generated TOML manually;
6. build a new `.intunewin`;
7. update the application version and detection script in Intune;
8. deploy to the pilot ring;
9. validate logs, marker, service, and server connectivity;
10. expand only after the pilot is stable.

## Known Configuration Limitations

- Values are duplicated across scripts instead of read from one shared configuration file.
- Detection validates only the host, not all generated TOML fields.
- The installer writes the same configuration to every discovered user profile.
- Configuration is not continuously reconciled after installation.
- The API URL is generated with `http://` in the current script.
- The optional password block is script-based rather than secret-store based.

These limitations should be considered when planning future hardening.

## Related Documentation

- [Architecture](ARCHITECTURE.md)
- [Microsoft Intune Deployment](INTUNE.md)
- [Security Policy](../../SECURITY.md)
