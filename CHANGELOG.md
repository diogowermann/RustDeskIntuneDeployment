# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project intends to use semantic versioning for deployment-script releases.

## [Unreleased]

### Fixed

- Prefer the configured MSI installation directory when locating an executable without an existing RustDesk service, avoiding stale installations in alternative paths.
- Replace the disabled sample's literal permanent password with a process-scoped value and explicit validation; never commit real credentials.

- Prevent indefinite waits while re-registering the RustDesk service after MSI maintenance; verify registration (60s), Running/Automatic state (40s), and the registered service executable version before creating the marker.
- Require a running, automatically started RustDesk service in Intune detection to avoid false installed states.

- Accept RustDesk `ProductVersion` build metadata such as `1.5.3+71` when checking the minimum installed version in both scripts. Reject malformed versions and cover version parsing with regression tests.

### Added

- Minimum RustDesk version (`$RustDeskVersion`) enforced in detection and verified after MSI installation.
- Service-executable-first version discovery to avoid accepting stale binaries in alternate install directories.
- Normalized three- and four-part version comparison; upgraded Intune package and detection-script guidance.

- English and Portuguese portfolio-oriented READMEs.
- English and Portuguese architecture documentation.
- English and Portuguese configuration reference.
- English and Portuguese Microsoft Intune deployment guide.
- Mermaid diagrams for system context, installation sequence, detection, trust boundaries, topology, and rollout rings.
- MIT license for original deployment scripts and documentation.
- Security policy covering package integrity, server identity, credentials, Intune administration, endpoint configuration, logging, privacy, and removal.
- Explicit placeholders for future sanitized screenshots.

### Documented

- Exact responsibilities of installation, detection, and uninstallation scripts.
- Multi-profile `RustDesk2.toml` distribution.
- Difference between the RustDesk server public key and private key.
- Current detection scope and its limitations.
- Current use of `http://` for the configured API URL.
- Security risks of embedding a shared permanent password.
- Vendor MSI provenance, signature, hash, license, and redistribution requirements.
- Pilot deployment, upgrade, supersedence, rollback, and troubleshooting procedures.
- Current `Win32_Product` uninstallation behavior and recommended future hardening.

### Security

- Clarified that `.intunewin` packages must not be treated as secret storage.
- Clarified that Intune assignment controls software deployment but does not authorize remote-support operators.
- Clarified that the repository MIT license does not apply to RustDesk or bundled vendor binaries.

## Initial implementation

### Added

- `Source/install.ps1` for silent MSI installation, configuration distribution, service provisioning, logging, and marker creation.
- `Source/detect.ps1` for custom Microsoft Intune detection.
- `Source/uninstall.ps1` for silent MSI removal.
- Microsoft Intune Win32 packaging workflow.
