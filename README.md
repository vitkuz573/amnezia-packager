# AmneziaVPN Packager

Enterprise-grade build system that downloads [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client) releases from GitHub and packages them into native distribution formats with GPG signing, SBOM, build manifests, and layered configuration.

```
./build.sh -a --profile prod
# → amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst + .sig + sbom + manifest
```

## Features

- **Pipeline architecture** — fetch → extract → verify → package with pre/post hooks at each stage
- **Multi-format** — `.deb` (Debian/Ubuntu), `.pkg.tar.zst` (Arch Linux), `.rpm` (Fedora/RHEL)
- **Layered JSON config** — default → local → profile → env → CLI with JSON Schema validation
- **Template engine** — envsubst-based metadata generation for control files, PKGBUILD, spec
- **SBOM generation** — CycloneDX 1.5 bill of materials with SHA-256 hashes for every binary
- **Build manifest** — JSON manifest per build with artifact metadata, timestamps, config snapshot
- **GPG signing** — sign packages with armor, generate `.sig` files
- **Caching** — API response cache (1h TTL), tarball reuse across rebuilds
- **Parallel builds** — `--all --parallel` spawns simultaneous deb + rpm + arch
- **Health check** — post-install validation tool for binary, service, desktop entry, filesystem
- **Package repo** — APT/YUM repository management with gh-pages deployment
- **Auto-discovery** — drop a new `src/packager/*.sh`, it's found automatically
- **Headless IFW** — uses Qt IFW's built-in CLI (`--accept-licenses --confirm-command`) instead of fragile binary extraction
- **Dev profiles** — `dev.json` (debug + JSON logging), `prod.json` (sign + manifest + cache)
- **Docker** — multi-stage reproducible build with Docker Compose
- **Vagrant** — multi-distro test boxes (Arch, Debian, Fedora)

## Quick Start

```bash
# Grab the latest GitHub release and build an Arch package
./build.sh -a

# Build a specific version
./build.sh -a -v 4.8.19.0

# Build from a local tarball (fastest for development)
./build.sh -d --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar

# Build all formats with production profile, signed
./build.sh -a --all --profile prod --sign --gpg-key 0xDEADBEEF

# Dry-run to preview the pipeline
./build.sh -n --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar
```

## Requirements

- Bash 4.4+, `tar`, `curl`, `sudo`
- Packager-specific: `dpkg-deb` (Debian), `makepkg` (Arch), `rpmbuild` (RPM)
- Optional: `jq` (JSON config), `gpg` (signing), `python3` (SBOM), `bats` (tests)

## Usage

### CLI Reference

| Flag | Description |
|------|-------------|
| `-v, --version` | Release version (default: latest) |
| `-o, --output` | Output directory (default: cwd) |
| `--tar` | Path to local tarball (skips download) |
| `-d, --deb` | Build Debian package |
| `-r, --rpm` | Build RPM package |
| `-a, --arch` | Build Arch package |
| `--all` | Build all available formats |
| `--parallel` | Build targets in parallel (with `--all`) |
| `-n, --dry-run` | Show pipeline plan without executing |
| `--sign` | GPG-sign packages |
| `--gpg-key KEY` | GPG key ID for signing |
| `--profile PROFILE` | Load config profile (`dev`, `prod`) |
| `--manifest` | Generate build manifest |
| `-h, --help` | Show help |

### Makefile

```bash
make arch          # Build Arch package
make deb           # Build Debian package
make rpm           # Build RPM package
make all           # Build all formats
make parallel      # Build all formats in parallel
make release       # Build all + sign + manifest + SBOM
make test          # Run bats tests
make lint          # Shellcheck
make fmt           # shfmt
make docker        # Build via multi-stage Docker
make docker-run-arch  # Build Arch inside Docker
make check-deps    # Verify required tools
make clean         # Remove build artifacts
```

### Docker

```bash
# Build inside Docker (no host tools needed)
make docker-run-arch

# Interactive shell
docker compose run --rm builder
```

### Config Profiles

```bash
# Dev — debug logging, JSON log format, no signing
./build.sh -a --profile dev

# Prod — sign packages, generate manifest, use caches
./build.sh -a --profile prod --sign --gpg-key 0xDEADBEEF
```

## Configuration

See [docs/config.md](docs/config.md) for the full reference.

Configuration is layered (later layers win):

| Layer | File | Source |
|-------|------|--------|
| 1 — Default | `config/default.json` | Repository |
| 2 — Local | `config/local.json` | Gitignored, per-machine |
| 3 — Profile | `config/profiles/{profile}.json` | `--profile` flag |
| 4 — Environment | env vars like `RELEASE_VERSION` | Shell |
| 5 — CLI flags | `--version`, `--output`, etc. | Command line |

All files validated against `config/schema.json` (requires `jq`).

## Project Structure

```
├── build.sh                     # Entry point
├── Makefile                     # Build/test/lint/docker/release targets
├── Dockerfile                   # Multi-stage Docker build
├── docker-compose.yml           # Compose for development
├── Vagrantfile                  # Multi-distro test boxes
├── config/
│   ├── default.json             # Base configuration
│   ├── schema.json              # JSON Schema validation
│   ├── local.json               # Per-machine overrides (gitignored)
│   └── profiles/
│       ├── dev.json             # Development profile
│       └── prod.json            # Production profile
├── templates/
│   ├── arch/
│   │   ├── PKGBUILD             # Arch PKGBUILD template
│   │   ├── PKGINFO              # Arch package metadata
│   │   └── INSTALL              # Arch install scripts
│   ├── debian/
│   │   ├── control              # Debian control template
│   │   ├── postinst             # Post-install script template
│   │   └── prerm                # Pre-remove script template
│   └── rpm/
│       └── spec                 # RPM spec template
├── src/
│   ├── core/
│   │   ├── logger.sh            # Structured logging with correlation ID
│   │   ├── config.sh            # Layered JSON config loader
│   │   ├── template.sh          # envsubst template renderer
│   │   ├── bootstrap.sh         # Workspace, cleanup, distro detection
│   │   ├── pipeline.sh          # Stage orchestration, CLI parsing
│   │   └── sbom.sh              # CycloneDX SBOM generator
│   ├── stage/
│   │   ├── fetch.sh             # GitHub API → download tarball
│   │   ├── extract.sh           # tar → headless IFW → application files
│   │   └── verify.sh            # Validate extracted structure
│   └── packager/
│       ├── 00-interface.sh      # Packager contract
│       ├── deb.sh               # Debian/Ubuntu .deb builder
│       ├── arch.sh              # Arch Linux .pkg.tar.zst builder
│       └── rpm.sh               # RPM .rpm builder
├── tools/
│   ├── healthcheck.sh           # Post-install validation
│   └── repo.sh                  # APT/YUM repo management
├── tests/
│   └── core.bats                # Bats test suite
└── .github/
    └── workflows/
        └── build.yml            # CI/CD pipeline
```

## Install Built Packages

**Arch Linux:**
```bash
sudo pacman -U amneziavpn-*.pkg.tar.zst
```

**Debian/Ubuntu:**
```bash
sudo dpkg -i amneziavpn_*_amd64.deb
sudo apt install -f
```

**Fedora/RHEL:**
```bash
sudo rpm -i amneziavpn-*.rpm
```

After installation:
- systemd service `amneziavpn.service` auto-starts
- CLI at `/usr/local/bin/amneziavpn`
- Desktop entry and icon registered
- Logs at `/var/log/AmneziaVPN/`

## Post-Install Validation

```bash
tools/healthcheck.sh
# ✔ Service is active
# ✔ Binary found
# ✔ CLI symlink works
# ✔ Desktop entry registered
```

## Package Repository Deployment

```bash
# Initialize a repo
tools/repo.sh init apt /tmp/repo

# Add packages
tools/repo.sh add apt /tmp/repo amneziavpn_*.deb

# Deploy to gh-pages
tools/repo.sh deploy apt /tmp/repo
```

## Adding a New Packager

```bash
cp src/packager/deb.sh src/packager/fedora.sh
```

Implement three functions:

```bash
source "src/packager/00-interface.sh"
packager_register_impl

build_package() { … }
get_artifact()  { echo "$ARTIFACT"; }
get_deps()      { echo "rpm-build createrepo"; }
```

Auto-discovered automatically — no central registry.

## Development

```bash
# Pre-commit hooks
pre-commit install

# Run tests
make test

# Lint
make lint

# Format
make fmt

# Dry-run
./build.sh -n --tar ~/Downloads/AmneziaVPN_*.tar

# Debug logging
LOG_LEVEL=debug ./build.sh -a --tar ~/Downloads/AmneziaVPN_*.tar
```

## Vagrant

```bash
vagrant up            # Start all boxes
vagrant up archlinux  # Single box
vagrant ssh archlinux
cd /vagrant && ./build.sh -a
```

## CI/CD

GitHub Actions on push:
- `lint` — shellcheck
- `test` — bats unit tests
- `build-deb` / `build-arch` — parallel builds
- `release` — on `v*` tags, uploads artifacts (deb, pkg.tar.zst, .sig, sbom, manifest)

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
