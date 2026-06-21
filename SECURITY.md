# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | ✅ |
| older   | ❌ |

This project follows continuous delivery — only the latest release receives security updates.

## Reporting a Vulnerability

**Do not open a public issue.** Send details to **vitkuz573@gmail.com**.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to respond within 72 hours and will coordinate disclosure once a fix is released.

## Scope

- Build system (`build.sh`, `src/core/`, `src/stage/`, `src/packager/`)
- Repository management (`tools/repo.sh`, `tools/healthcheck.sh`)
- CI pipeline (`.appveyor.yml`)
- Docker setup (`Dockerfile`, `docker-compose.yml`)
- Config and templates (`config/`, `templates/`)
- Dependencies (system packages used at build time)

## Out of Scope

- Upstream AmneziaVPN application vulnerabilities — report to [amnezia-client](https://github.com/amnezia-vpn/amnezia-client)
- General shell scripting best practices
