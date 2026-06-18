# Configuration Reference

## Overview

Layered (later layers override earlier ones):

1. **`config/default.json`** — base defaults, committed
2. **`config/local.json`** — per-machine, gitignored
3. **`config/profiles/<profile>.json`** — via `--profile`
4. **Environment variables** — shell exports
5. **CLI flags** — highest priority

Validation against `config/schema.json` when `jq` is available.

## Config File Format

### `config/default.json`

```json
{
  "app": {
    "name": "AmneziaVPN",
    "user": "amneziavpn",
    "install_dir": "/opt/AmneziaVPN",
    "desktop_file": "AmneziaVPN.desktop",
    "icon_file": "AmneziaVPN.png",
    "service_file": "AmneziaVPN.service",
    "client_script": "client/AmneziaVPN.sh",
    "service_script": "service/AmneziaVPN-service.sh"
  },
  "build": {
    "output_dir": ".",
    "cache_dir": "~/.cache/amnezia-packager",
    "cache_enabled": true,
    "parallel": false
  },
  "github": {
    "repo": "amnezia-vpn/amnezia-client",
    "api_url": "https://api.github.com",
    "release_pattern": "AmneziaVPN_${version}_linux_x64.tar"
  },
  "dependencies": {
    "deb": "libxcb-cursor0, libxcb-xinerama0, libxcb-icccm4, libxcb-keysyms1, libopengl0, libxkbcommon-x11-0",
    "arch": "xcb-util-cursor libxcb xcb-util-wm xcb-util-keysyms libglvnd libxkbcommon-x11",
    "rpm": "libxcb-cursor libxcb-xinerama libxcb-icccm4 libxcb-keysyms1 libopengl0 libxkbcommon-x11"
  },
  "signing": {
    "sign_enabled": false,
    "gpg_key": "",
    "gpg_homedir": ""
  },
  "logging": {
    "level": "info",
    "format": "text",
    "file": "",
    "max_size": 10485760,
    "max_files": 3
  },
  "pipeline": {
    "stages": ["fetch", "extract", "verify", "package"],
    "targets": [],
    "parallel": false
  }
}
```

### `config/profiles/dev.json`

```json
{
  "logging": { "level": "debug", "format": "json" },
  "signing": { "sign_enabled": false },
  "build":   { "cache_enabled": false }
}
```

### `config/profiles/prod.json`

```json
{
  "logging": { "level": "info" },
  "signing": { "sign_enabled": true },
  "build":   { "cache_enabled": true },
  "pipeline": { "parallel": false }
}
```

## Environment Variables

| Config Key | Env Var | Default |
|------------|---------|---------|
| `app.name` | `APP_NAME` | `AmneziaVPN` |
| `app.user` | `APP_USER` | `amneziavpn` |
| `app.install_dir` | `INSTALL_DIR` | `/opt/AmneziaVPN` |
| `app.desktop_file` | `DESKTOP_FILE` | `AmneziaVPN.desktop` |
| `app.icon_file` | `ICON_FILE` | `AmneziaVPN.png` |
| `app.service_file` | `SERVICE_FILE` | `AmneziaVPN.service` |
| `app.client_script` | `CLIENT_SCRIPT` | `client/AmneziaVPN.sh` |
| `app.service_script` | `SERVICE_SCRIPT` | `service/AmneziaVPN-service.sh` |
| `build.output_dir` | `OUTPUT_DIR` | `.` |
| `build.cache_dir` | `CACHE_DIR` | `~/.cache/amnezia-packager` |
| `build.cache_enabled` | `CACHE_ENABLED` | `true` |
| `build.parallel` | `PARALLEL` | `false` |
| `github.repo` | `GITHUB_REPO` | `amnezia-vpn/amnezia-client` |
| `github.api_url` | `GITHUB_API_URL` | `https://api.github.com` |
| `github.release_pattern` | `RELEASE_PATTERN` | `AmneziaVPN_\${version}_linux_x64.tar` |
| `dependencies.deb` | `DEPS_DEB` | (comma+space separated) |
| `dependencies.arch` | `DEPS_ARCH` | (space separated) |
| `dependencies.rpm` | `DEPS_RPM` | (space separated) |
| `signing.sign_enabled` | `SIGN_ENABLED` | `false` |
| `signing.gpg_key` | `GPG_KEY` | `""` |
| `signing.gpg_homedir` | `GPG_HOMEDIR` | `""` |
| `logging.level` | `LOG_LEVEL` | `info` |
| `logging.format` | `LOG_FORMAT` | `text` |
| `logging.file` | `LOG_FILE` | `""` |
| `logging.max_size` | `LOG_MAX_SIZE` | `10485760` |
| `logging.max_files` | `LOG_MAX_FILES` | `3` |
| `pipeline.stages` | `STAGES` | `fetch,extract,verify,package` |
| `pipeline.targets` | `TARGETS` | `""` |
| `pipeline.parallel` | `PARALLEL` | `false` |

## Template Variables (envsubst)

These are the only variables that get substituted. Shell runtime variables (like `APP_PATH`) are preserved:

| Variable | Source | Format | Example |
|----------|--------|--------|---------|
| `APP_NAME` | `app.name` | plain | `AmneziaVPN` |
| `APP_USER` | `app.user` | plain | `amneziavpn` |
| `INSTALL_DIR` | `app.install_dir` | path | `/opt/AmneziaVPN` |
| `CLIENT_SCRIPT` | `app.client_script` | path | `client/AmneziaVPN.sh` |
| `SERVICE_SCRIPT` | `app.service_script` | path | `service/AmneziaVPN-service.sh` |
| `DESKTOP_FILE` | `app.desktop_file` | filename | `AmneziaVPN.desktop` |
| `ICON_FILE` | `app.icon_file` | filename | `AmneziaVPN.png` |
| `SERVICE_FILE` | `app.service_file` | filename | `AmneziaVPN.service` |
| `DEPS_DEB` | `dependencies.deb` | comma+space | `libxcb-cursor0, libxcb-xinerama0` |
| `DEPS_ARCH` | `dependencies.arch` | space | `xcb-util-cursor libxcb` |
| `DEPS_RPM` | `dependencies.rpm` | space | `libxcb-cursor libxcb-xinerama` |
| `DEPS_ARCH_LINES` | computed | multiline | `depend = xcb-util-cursor\ndepend = libxcb` |
| `DEPS_RPM_LINES` | computed | multiline | `Requires: libxcb-cursor\nRequires: libxcb-xinerama` |
| `PKGVER` | computed | `version-release` | `4.8.19.0` |
| `PKGNAME` | `app.user` | plain | `amneziavpn` |
| `PKGSIZE_KB` | computed | number | `373656` |
| `PKGSIZE_BYTES` | computed | number | `382654123` |
| `PACKAGE_VENDOR` | `PACKAGE_VENDOR` | plain | `AmneziaVPN` |
| `PACKAGE_LICENSE` | `PACKAGE_LICENSE` | plain | `GPL3` |
| `PACKAGE_DESCRIPTION` | `PACKAGE_DESCRIPTION` | plain | `AmneziaVPN — Client...` |
| `PACKAGE_URL` | `PACKAGE_URL` | url | `https://github.com/vitkuz573/amnezia-packager` |
| `PACKAGE_MAINTAINER` | `PACKAGE_MAINTAINER` | plain | `AmneziaVPN <support@...>` |

## CLI Flag Overrides

| Flag | Config Key |
|------|------------|
| `-v, --version VERSION` | Overrides `RELEASE_VERSION` |
| `-o, --output DIR` | `OUTPUT_DIR` |
| `-d, --deb` | Appends `deb` to `TARGETS` |
| `-r, --rpm` | Appends `rpm` to `TARGETS` |
| `-a, --arch` | Appends `arch` to `TARGETS` |
| `--all` | Sets `TARGETS` to all available |
| `--parallel` | `PARALLEL=true` |
| `--sign` | `SIGN_ENABLED=true` |
| `--gpg-key KEY` | `GPG_KEY=KEY` |
| `--profile NAME` | `ACTIVE_PROFILE=NAME` |
| `--manifest` | Enables manifest generation |
| `--tar PATH` | `TARBALL_PATH=PATH` |
| `-n, --dry-run` | `DRY_RUN=true` |
| `-h, --help` | Show help and exit |

## Fallback Without jq

When `jq` is not installed, the config system sources `config/default.sh` and applies environment variable overrides. Profile loading and JSON Schema validation are skipped.
