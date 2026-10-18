# Security Policy

## Supported Versions

Only the latest commit on `main` receives security updates. There are no
maintained release branches.

## Reporting a Vulnerability

**Do not open a public issue for a security vulnerability.**

Send details to the repository maintainer through GitHub's private vulnerability
reporting:

1. Go to <https://github.com/llIIllIID0EIIllIIll/virtual-paradise/security/advisories/new>
2. Describe the issue, the affected component, and reproduction steps
3. Expect an acknowledgement within 7 days

If private reporting is unavailable, contact the maintainer directly via the
email listed on their GitHub profile.

## Scope

Security concerns in this repository include:

- **Installer/uninstaller**: shell scripts that run with optional `sudo`
  privileges — command injection, path traversal, privilege escalation
- **Override layer**: patches applied to third-party plugin files — unintended
  file writes outside the plugin directory
- **Systemd units**: user and system services — sandboxing, file permissions
- **Credentials**: any hardcoded secrets, tokens or passwords in the codebase

Out of scope:

- Vulnerabilities in Omarchy, Hyprland, Quickshell, Arch Linux or any
  third-party plugin (report those upstream)
- Issues that require the user to disable security features (e.g., running the
  installer as root without `SUDO_USER`)

## Response Timeline

| Step | Target |
| :--- | :--- |
| Acknowledgement | 7 days |
| Initial assessment | 14 days |
| Fix or mitigation | 30 days |
| Public disclosure | After fix is released |
