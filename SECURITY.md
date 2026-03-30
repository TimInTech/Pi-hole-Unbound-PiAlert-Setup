# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | ✅ Yes    |
| Older   | ❌ No     |

## Scope

This project is a local Raspberry Pi setup tool. The attack surface is limited to:
- The Raspberry Pi running Pi-hole, Unbound, and (optionally) the Python Suite API
- The `SUITE_API_KEY` protecting the REST API (see `.env.example`)

## Reporting

Report vulnerabilities privately to **TimInTech** via GitHub
[Security Advisories](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/security/advisories).

Please include:
- Description of the issue
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

Do **not** open a public issue for security vulnerabilities.
