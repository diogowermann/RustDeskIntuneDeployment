# Security Policy

## Reporting a Vulnerability

Do not disclose a suspected vulnerability, exposed credential, private key, production hostname, endpoint identifier, or access-control weakness in a public issue.

Use a private GitHub security advisory when available, or contact the repository owner through a private channel listed on the GitHub profile.

Include:

- affected file or deployment component;
- observed behavior;
- reproduction steps that do not expose real infrastructure;
- expected security impact;
- relevant Windows, Intune, and RustDesk versions;
- suggested mitigation when known.

Do not include production passwords, private keys, complete configuration files, unsanitized logs, or active remote-access identifiers.

## Scope

This policy covers the original PowerShell deployment scripts and documentation in this repository.

RustDesk itself, its MSI installer, Microsoft Intune, the Intune Management Extension, Windows, and the self-hosted RustDesk server components are external dependencies with separate security processes.

## Deployment Security Principles

### Treat the package as privileged code

The installer is expected to run as `SYSTEM`. Anyone who can modify the `.intunewin`, source scripts, Intune application, or assignment can execute high-privilege code on targeted endpoints.

Restrict package modification and application assignment to authorized endpoint administrators.

### Verify the vendor MSI

Before every release:

- obtain the MSI from an approved source;
- verify its Authenticode signature;
- verify the expected publisher;
- calculate and record SHA-256;
- confirm the RustDesk version;
- review vendor release notes and security advisories;
- confirm redistribution rights before storing the MSI publicly.

The MIT license in this repository does not relicense the RustDesk MSI.

### Protect server identity

The client package may contain the RustDesk server public key. It must never contain the corresponding private key.

The following must not be included in the source repository or Intune package:

- server private keys;
- administrator passwords;
- API credentials;
- personal access tokens;
- certificates with private keys;
- VPN credentials;
- support-operator credentials;
- recovery secrets.

### Do not embed a shared permanent password

`install.ps1` contains an optional permanent-password block that is disabled by default.

Do not enable that block with a plaintext shared password. A shared package-level password creates several risks:

- every targeted endpoint receives the same credential;
- package administrators can recover it;
- Git history may retain it permanently;
- compromise of one endpoint can affect the entire fleet;
- rotation requires package replacement;
- attribution and per-device revocation become difficult.

Before publishing or distributing the source, ensure any example value in the disabled block is a non-secret placeholder.

Preferred alternatives include:

- unique credentials per device;
- server-side identity and role enforcement;
- MFA for support operators;
- just-in-time access;
- centrally audited authorization;
- managed secret delivery with rotation and revocation.

### Separate deployment from authorization

Intune assignment authorizes installation, not remote access.

Configure authorization on the RustDesk infrastructure, including:

- individual support accounts;
- least-privilege roles;
- MFA where supported;
- operator lifecycle management;
- session logging and auditing;
- restricted address books or groups;
- approval workflows where required;
- incident response and access revocation.

### Restrict network exposure

Expose only the RustDesk ports required by the chosen architecture.

Use firewall rules, segmentation, reverse proxies, VPNs, and trusted certificates as appropriate. Avoid exposing management APIs over unencrypted or broadly accessible network paths.

The current generated configuration uses an `http://` API URL. Review and harden this for the target environment before production use.

## Intune Security

### Administrative permissions

Restrict:

- Win32 application creation and editing;
- assignment modification;
- supersedence configuration;
- access to packaged source files;
- device-group membership changes;
- script-signing and release credentials.

Use separate administrative roles when possible.

### Assignment scope

Begin with a small pilot group. Avoid broad assignment until installation, detection, server connectivity, support authorization, and removal have been validated.

Remote-support clients should not be installed on devices outside the approved support scope.

### Package confidentiality

`.intunewin` is a packaging format, not a secret vault. Assume authorized administrators and incident responders can inspect the source content.

Do not package secrets.

### Script signing

The current documentation allows signature enforcement to remain disabled while the scripts are unsigned.

For mature production environments:

1. establish a trusted code-signing certificate;
2. sign all production scripts;
3. protect the signing private key;
4. verify signatures during release;
5. enable signature enforcement in Intune;
6. document emergency-signing and revocation procedures.

## Endpoint Security

### Execution context

The installer writes to machine and user-profile locations and manages a Windows service. It therefore requires a machine context.

Validate that endpoint security software permits only the intended actions and does not broadly weaken controls for PowerShell, MSI installation, or service creation.

### Configuration files

`RustDesk2.toml` is copied to service, system, machine, default-user, and existing-user locations.

Review filesystem permissions on these paths. Standard users should not be able to modify machine-level configurations that influence a privileged service.

### Marker and logs

The marker and logs may contain:

- internal server names;
- executable paths;
- installed versions;
- configuration paths;
- timestamps;
- Windows Installer diagnostics.

Protect them from unauthorized modification and sanitize them before sharing.

The marker is not a security token and must not be treated as proof of server identity or endpoint integrity.

### User profiles

Writing configuration into existing user profiles changes per-user application state. Test this against profile-management, roaming-profile, FSLogix, folder-redirection, and privacy requirements where applicable.

## Detection Limitations

The custom detection script verifies only:

- executable presence;
- expected host in one machine-level configuration;
- marker presence.

It does not validate:

- service state;
- server public key;
- port values;
- every user profile;
- end-to-end server reachability;
- successful authenticated remote access;
- current authorization policy.

Do not use Intune detection as the only security or availability control.

## Uninstallation Limitations

The current uninstall script uses `Win32_Product` and does not explicitly remove every local or server-side artifact.

Security and privacy reviews should define whether removal must also include:

- service remnants;
- machine configuration;
- default-user configuration;
- existing-user configuration;
- organization markers and logs;
- server-side endpoint records;
- address-book membership;
- assigned credentials or permissions.

Validate the actual cleanup behavior before offboarding devices or decommissioning the service.

## Logging and Privacy

Remote-support tools can process or expose sensitive user and device information.

Define and document:

- lawful and organizational basis for remote support;
- user notification and consent requirements;
- session-recording policy;
- log retention;
- administrator access to logs;
- incident investigation procedures;
- data-residency requirements;
- employee and third-party support boundaries.

Do not publish unsanitized screenshots of Intune, RustDesk, endpoints, logs, server consoles, or network topology.

## Release Security Checklist

- [ ] MSI source is approved.
- [ ] Authenticode signature is valid.
- [ ] MSI SHA-256 is recorded.
- [ ] Vendor license and redistribution rights are reviewed.
- [ ] Server host and ports are correct.
- [ ] Public key matches the target server.
- [ ] No private key is packaged.
- [ ] No password or token is packaged.
- [ ] Optional password block is disabled and sanitized.
- [ ] Installer and detection configuration match.
- [ ] Only one intended MSI is present.
- [ ] Package was built in a controlled workspace.
- [ ] Pilot assignment is limited.
- [ ] Network paths are restricted and tested.
- [ ] Support accounts and roles are configured.
- [ ] Logs and screenshots are sanitized.
- [ ] Upgrade, rollback, and uninstall are tested.

## Supported Versions

Security fixes are expected to target the latest repository state. Older packages may require replacement rather than in-place patching because configuration and scripts are embedded into the Intune package.

## Disclaimer

This repository is provided as deployment automation and must be adapted to the security, privacy, regulatory, and operational requirements of each environment.
