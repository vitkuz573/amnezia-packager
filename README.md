# AmneziaVPN Packager

Enterprise-grade build system that downloads [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client) releases from GitHub and packages them into native distribution formats.

```
./build.sh -a
# → amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst
```

## Features

- **Pipeline architecture** — fetch → extract → verify → package with pre/post hooks at each stage
- **Multi-format** — `.deb` (Debian/Ubuntu), `.pkg.tar.zst` (Arch Linux), `.rpm` (Fedora/RHEL — placeholder)
- **Auto-detection** — picks the right packager based on the host distro
- **Packager registry** — drop a new `src/packager/*.sh` and it's auto-discovered
- **Headless IFW** — uses Qt IFW's built-in CLI (`--accept-licenses --confirm-command`) instead of fragile binary extraction
- **Dry-run** — preview the pipeline plan without executing
- **Cleanup** — temp workspaces are removed on exit, even after crashes

## Requirements

- Bash 4.4+
- `tar`, `curl` (for download), `sudo` (for IFW installer)
- Packager-specific: `dpkg-deb` (Debian), `makepkg` (Arch), `rpmbuild` (RPM)

## Quick Start

```bash
# Build Arch package from the latest GitHub release
./build.sh -a

# Build a specific version
./build.sh -a -v 4.8.19.0

# Build from a local tarball (fastest for development)
./build.sh -a --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar

# Build Debian package
./build.sh -d --tar ~/Downloads/AmneziaVPN_4.8.19.0_linux_x64.tar
```

## CLI Reference

| Flag | Description |
|------|-------------|
| `-v, --version` | Release version (default: latest) |
| `-o, --output` | Output directory (default: cwd) |
| `--tar` | Path to a local tarball (skips download) |
| `-d, --deb` | Build Debian package |
| `-r, --rpm` | Build RPM package |
| `-a, --arch` | Build Arch package |
| `-n, --dry-run` | Show pipeline plan without executing |
| `-h, --help` | Show help |

## Configuration

All settings live in `config/default.sh` and can be overridden via environment variables:

```bash
RELEASE_VERSION=4.8.19.0 \
PACKAGE_TARGET=arch \
OUTPUT_DIR=/tmp/pkgs \
  ./build.sh
```

## Project Structure

```
├── build.sh                  # Entry point
├── config/
│   └── default.sh            # Default configuration
├── src/
│   ├── core/
│   │   ├── logger.sh         # Structured logging (text/json)
│   │   ├── bootstrap.sh      # Workspace, cleanup, distro detection, packager registry
│   │   └── pipeline.sh       # Stage orchestration, CLI parsing
│   ├── stage/
│   │   ├── fetch.sh          # GitHub API → download tarball
│   │   ├── extract.sh        # tar → headless IFW → application files
│   │   └── verify.sh         # Validate extracted structure
│   └── packager/
│       ├── 00-interface.sh   # Packager contract (register, helpers)
│       ├── deb.sh            # Debian/Ubuntu .deb builder
│       ├── arch.sh           # Arch Linux .pkg.tar.zst builder
│       └── rpm.sh            # RPM placeholder (contributions welcome)
└── docs/
    └── architecture.md       # Full architecture guide
```

## Adding a New Packager

```bash
cp src/packager/deb.sh src/packager/fedora.sh
```

Edit the file and implement three functions:

```bash
source "src/packager/00-interface.sh"
packager_register_impl

build_package() {
    # produce artifact in OUTPUT_DIR
}

get_artifact() { echo "$ARTIFACT"; }
get_deps()    { echo "dependency1 dependency2"; }
```

The file is auto-discovered — no central registry to update.

## Install Built Package

**Arch Linux:**
```bash
sudo pacman -U amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst
```

**Debian/Ubuntu:**
```bash
sudo dpkg -i amneziavpn_4.8.19.0_amd64.deb
sudo apt install -f  # install missing dependencies
```

After installation:
- Service auto-starts via systemd (`amneziavpn.service`)
- CLI launcher at `/usr/local/bin/amneziavpn`
- Desktop entry and icon registered

## Development

```bash
# Dry-run to verify the pipeline plan
./build.sh -n --tar ~/Downloads/test.tar

# Debug logging
LOG_LEVEL=debug ./build.sh -a --tar ~/Downloads/test.tar

# Clean all temp dirs after a failed build
./build.sh  # fresh start — cleanup is automatic
```

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
