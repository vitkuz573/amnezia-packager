# Configuration Reference

## Overview

Configuration is layered (later layers override earlier ones):

1. **`config/default.json`** — base defaults, committed to repo
2. **`config/local.json`** — per-machine overrides, gitignored
3. **`profiles/<profile>.json`** — named profiles via `--profile` flag
4. **Environment variables** — shell exports take precedence
5. **CLI flags** — highest priority

All JSON files are validated against `config/schema.json` when `jq` is available.

## Config File Format

### `config/default.json`

```json
{
  "app": {
    "name": "AmneziaVPN",
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

### `config/schema.json`

Validates the config structure with JSON Schema. Run manually:

```bash
jq -e --argfile data config/default.json --argfile schema config/schema.json \
  'if $data | .. | . == null then error("null value") else . end | $data as $d | $schema as $s | $d' > /dev/null
```

Or just run `build.sh` — validation is automatic.

### `config/profiles/dev.json`

```json
{
  "logging": {
    "level": "debug",
    "format": "json"
  },
  "signing": {
    "sign_enabled": false
  },
  "build": {
    "cache_enabled": false
  }
}
```

### `config/profiles/prod.json`

```json
{
  "logging": {
    "level": "info"
  },
  "signing": {
    "sign_enabled": true
  },
  "build": {
    "cache_enabled": true
  },
  "pipeline": {
    "parallel": false
  }
}
```

## Environment Variables

Every config key can be set as an environment variable using `UPPER_SNAKE_CASE`:

| Config Key | Env Var | Default |
|------------|---------|---------|
| `app.name` | `APP_NAME` | `AmneziaVPN` |
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

These variables are available in template files (`templates/`). They are the only variables that get substituted — shell runtime variables like `APP_PATH` are preserved as-is:

| Variable | Source Config Key | Example Value |
|----------|-------------------|---------------|
| `APP_NAME` | `app.name` | `AmneziaVPN` |
| `INSTALL_DIR` | `app.install_dir` | `/opt/AmneziaVPN` |
| `CLIENT_SCRIPT` | `app.client_script` | `client/AmneziaVPN.sh` |
| `SERVICE_SCRIPT` | `app.service_script` | `service/AmneziaVPN-service.sh` |
| `DESKTOP_FILE` | `app.desktop_file` | `AmneziaVPN.desktop` |
| `ICON_FILE` | `app.icon_file` | `AmneziaVPN.png` |
| `SERVICE_FILE` | `app.service_file` | `AmneziaVPN.service` |
| `VERSION` | — | `4.8.19.0` |
| `ARCH` | — | `x86_64` |

## CLI Flag Overrides

| Flag | Config Key Affected |
|------|---------------------|
| `--version VERSION` | Overrides `RELEASE_VERSION` |
| `--output DIR` | `OUTPUT_DIR` |
| `--deb` / `--rpm` / `--arch` | Appends to `TARGETS` |
| `--all` | Sets `TARGETS` to all available |
| `--parallel` | `PARALLEL=true` |
| `--sign` | `SIGN_ENABLED=true` |
| `--gpg-key KEY` | `GPG_KEY=KEY` |
| `--profile NAME` | `ACTIVE_PROFILE=NAME` |
| `--manifest` | Enables manifest generation |
| `--tar PATH` | `TARBALL_PATH=PATH` |
| `--dry-run` | `DRY_RUN=true` |

## Fallback Without jq

When `jq` is not installed, the config system falls back to sourcing `config/default.sh` (if it exists) and applying environment variable overrides. Profile loading is skipped. All JSON features (schema validation, profile merging) require `jq`.
