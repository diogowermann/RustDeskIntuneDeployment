# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project intends to use semantic versioning for deployment-script releases.

## [Unreleased]

### Added

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
