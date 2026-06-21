# Changelog

All notable changes to the AmneziaVPN Packager are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-06-21

### Added
- Pipeline architecture: fetch → extract → verify → package with pre/post hooks
- Multi-format support: `.deb` (Debian/Ubuntu), `.pkg.tar.zst` (Arch Linux), `.rpm` (Fedora/RHEL)
- Layered JSON config: default → local → profile → env → CLI with JSON Schema validation
- Template engine via `envsubst` with explicit variable lists
- SBOM generation: CycloneDX 1.5 with SHA-256 for every binary
- Build manifest with artifact metadata, timestamps, config snapshot
- GPG signing for packages and repo metadata
- API response cache (1h TTL), tarball reuse across rebuilds
- Parallel builds: `--all --parallel`
- Health check tool: post-install validation for binary, service, desktop entry, filesystem
- Package repo management: APT, Arch (`repo-add`), YUM
- GitHub Releases upload via `tools/repo.sh upload`
- Auto-discovery: drop `src/packager/*.sh`, it's found automatically
- Headless IFW support for Qt Installer Framework
- Dev/prod config profiles
- Multi-stage Docker build
- Vagrant multi-distro test boxes (Arch, Debian, Fedora)
- AppVeyor CI: lint → test → build → deploy gh-pages + GitHub Releases
- Pre-commit hooks (shellcheck, shfmt, trailing-whitespace)
- Renovate dependency updates
- Structured logging with correlation ID
- `direnv` support (`.envrc`)
- 404.html for GitHub Pages

### Docs
- Architecture guide (`docs/architecture.md`)
- Configuration reference (`docs/config.md`)
- APT/Arch repo usage guide (`docs/repository.md`)
- CI/CD pipeline docs (`docs/ci.md`)
- Contributing guide (`CONTRIBUTING.md`)
- Issue/PR templates, CODE_OF_CONDUCT, SECURITY policy
