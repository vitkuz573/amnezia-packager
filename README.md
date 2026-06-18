# AmneziaVPN Packager

Enterprise-grade build system that downloads [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client) releases from GitHub and packages them into native distribution formats with GPG signing, SBOM, build manifests, and layered configuration.

```
./build.sh -a --profile prod
# → amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst + .sig + sbom + manifest
```

Public APT and Arch repos available at `vitkuz573.github.io/amnezia-packager/` — see [docs/repository.md](docs/repository.md).

## Features

- **Pipeline architecture** — fetch → extract → verify → package with pre/post hooks at each stage
- **Multi-format** — `.deb` (Debian/Ubuntu), `.pkg.tar.zst` (Arch Linux), `.rpm` (Fedora/RHEL)
- **Layered JSON config** — default → local → profile → env → CLI with JSON Schema validation
- **Template engine** — envsubst-based metadata generation for control files, PKGINFO, spec
- **SBOM generation** — CycloneDX 1.5 bill of materials with SHA-256 for every binary
- **Build manifest** — JSON manifest per build with artifact metadata, timestamps, config snapshot
- **GPG signing** — sign packages and repo metadata (APT Release, Arch db)
- **Caching** — API response cache (1h TTL), tarball reuse across rebuilds
- **Parallel builds** — `--all --parallel` spawns simultaneous deb + rpm + arch
- **Health check** — post-install validation tool for binary, service, desktop entry, filesystem
- **Package repo** — APT (`tools/repo.sh`) + Arch (`repo-add`) + YUM + GitHub Releases upload
- **Auto-discovery** — drop `src/packager/*.sh`, it's found automatically
- **Headless IFW** — Qt IFW's built-in CLI (`--accept-licenses --confirm-command`)
- **Dev/prod profiles** — `dev.json` (debug), `prod.json` (sign + manifest + cache)
- **Docker** — multi-stage reproducible build
- **Vagrant** — multi-distro test boxes (Arch, Debian, Fedora)
- **CI** — AppVeyor: lint → test → build → deploy gh-pages + GitHub Releases

## Quick Start

```bash
# Grab the latest GitHub release and build an Arch package
./build.sh -a

# Build a specific version
./build.sh -a -v 4.8.19.0

# Build from a local tarball (fastest for development)
./build.sh -d --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar

# Build all formats with production profile, signed
./build.sh --all --profile prod --sign --gpg-key 0xDEADBEEF

# Dry-run to preview the pipeline
./build.sh -n --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar
```

## Requirements

- Bash 4.4+, `tar`, `curl`, `sudo`
- Packager-specific: `dpkg-deb` (Debian), `makepkg` (Arch), `rpmbuild` (RPM)
- Optional: `jq` (JSON config), `gpg` (signing), `python3` (SBOM), `bats` (tests), `gh` (Release upload)

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

Layered (later wins): `default.json` ← `local.json` ← `profile` ← env vars ← CLI flags. Validated against JSON Schema via `jq`.

## Project Structure

```
├── build.sh                     # Entry point
├── Makefile                     # Build/test/lint/docker/release targets
├── Dockerfile                   # Multi-stage Docker build
├── docker-compose.yml           # Compose for development
├── Vagrantfile                  # Multi-distro test boxes
├── .appveyor.yml                # AppVeyor CI pipeline
├── renovate.json                # Renovate dependency updates
├── repo-public-key.asc          # GPG public key for repos
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
│   │   ├── PKGINFO              # Arch .PKGINFO metadata
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
│   └── repo.sh                  # APT/Arch/YUM repo management + Release upload
├── tests/
│   └── core.bats                # Bats test suite
└── docs/
    ├── architecture.md          # Full architecture guide
    ├── config.md                # Configuration reference
    ├── repository.md            # APT/Arch repo usage guide
    └── ci.md                    # AppVeyor CI pipeline docs
```

## Install from Repos

**APT (Debian/Ubuntu):**
```bash
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/amneziavpn.gpg
echo "deb [signed-by=/usr/share/keyrings/amneziavpn.gpg] https://vitkuz573.github.io/amnezia-packager/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/amneziavpn.list
sudo apt update && sudo apt install amneziavpn
```

**Arch Linux (pacman):**
```bash
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  | sudo pacman-key --add -
sudo pacman-key --lsign-key repo@amneziavpn.local

cat >> /etc/pacman.conf <<"EOF"
[amneziavpn]
SigLevel = Optional TrustAll
Server = https://github.com/vitkuz573/amnezia-packager/releases/download/packages
Server = https://vitkuz573.github.io/amnezia-packager/arch
EOF

sudo pacman -Sy && sudo pacman -S amneziavpn
```

**Manual install:**
```bash
sudo dpkg -i amneziavpn_*_amd64.deb && sudo apt install -f   # Debian
sudo pacman -U amneziavpn-*.pkg.tar.zst                       # Arch
sudo rpm -i amneziavpn-*.rpm                                  # Fedora
```

After installation: systemd service `amneziavpn.service` auto-starts, CLI at `/usr/local/bin/amneziavpn`.

## Package Repository Management

```bash
# Initialize repo structure (APT + Arch + YUM)
tools/repo.sh init /srv/repo

# Add packages (generates db for apt/arch/yum)
tools/repo.sh add amneziavpn_4.8.19.0_amd64.deb /srv/repo
tools/repo.sh add amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst /srv/repo

# Sign Release + Arch db
tools/repo.sh release /srv/repo --gpg-key 0xDEADBEEF

# Upload packages to GitHub Releases (tag: packages)
tools/repo.sh upload packages

# Deploy metadata to gh-pages
tools/repo.sh deploy /srv/repo "repo: update $(date -u +%Y-%m-%d)"
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
pre-commit install              # Pre-commit hooks
make test                       # Bats tests
make lint                       # Shellcheck
make fmt                        # shfmt
./build.sh -n --tar ~/Downloads/AmneziaVPN_*.tar  # Dry-run
LOG_LEVEL=debug ./build.sh -a --tar ~/Downloads/AmneziaVPN_*.tar  # Debug
```

## Vagrant

```bash
vagrant up archlinux   # Arch box
vagrant ssh archlinux
cd /vagrant && ./build.sh -a
```

## CI/CD (AppVeyor)

See [docs/ci.md](docs/ci.md) for the full pipeline reference.

On push to `main`:
- `lint` — shellcheck
- `test` — bats unit tests
- `build-deb` — build .deb, init repo, sign, deploy to gh-pages
- On tags `v*`: upload artifacts to GitHub Releases

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
