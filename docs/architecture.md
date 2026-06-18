# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         build.sh (entry)                            │
├─────────────────────────────────────────────────────────────────────┤
│  src/core/config.sh    ───  layered JSON config → global vars       │
│  src/core/logger.sh    ───  structured logging (text/JSON)          │
│  src/core/template.sh  ───  envsubst-based template rendering       │
│  src/core/bootstrap.sh ───  workspace, cleanup, distro detection    │
│  src/core/pipeline.sh  ───  CLI parsing, stage orchestration        │
│  src/core/sbom.sh      ───  CycloneDX SBOM generator               │
├─────────────────────────────────────────────────────────────────────┤
│                      Pipeline (pipeline.sh)                         │
│                                                                    │
│   ┌──────┐    ┌─────────┐    ┌──────┐    ┌──────────────────┐     │
│   │fetch │───▶│ extract │───▶│verify│───▶│ package (per fmt) │     │
│   └──────┘    └─────────┘    └──────┘    └──────────────────┘     │
│      │             │              │              │                  │
│   pre/post       pre/post       pre/post       pre/post            │
│                                                                    │
│   Output: sbom.json + build-manifest.json + (.deb|.pkg|.rpm) + .sig│
└─────────────────────────────────────────────────────────────────────┘
```

## Pipeline

```
fetch ──→ extract ──→ verify ──→ package
```

| Stage | Script | Input → Output |
|-------|--------|----------------|
| fetch | `src/stage/fetch.sh` | GitHub release or local `--tar` → tarball in `BUILD_DIR` |
| extract | `src/stage/extract.sh` | tarball → headless IFW → application files in `TARGET_DIR` |
| verify | `src/stage/verify.sh` | `TARGET_DIR` → validated file layout |
| package | `src/packager/<target>.sh` | `TARGET_DIR` → native package in `OUTPUT_DIR` |

Each stage is an independent script with a single entry point `run_<stage>`. The pipeline sources and executes it on demand, never keeping unused stages in memory.

### Hooks

Any stage file may define `pre_<stage>` or `post_<stage>` functions. The pipeline discovers them automatically:

```bash
pipeline::hook() {
    local stage="$1" hook="$2"
    local script="${PROJECT_ROOT}/src/stage/${stage}.sh"
    local fn="${hook}_${stage}"
    if [[ -f "$script" ]]; then
        source "$script"
        if declare -F "$fn" &>/dev/null; then $fn; fi
    fi
}
```

This allows extending behaviour without modifying pipeline core. For example, a `pre_package` hook could inject license files.

### Parallel Execution

When `--all --parallel` is set, the pipeline spawns one background process per packager:

```bash
for target in "${TARGETS[@]}"; do
    ( pipeline_package "$target" ) &
done
wait
```

Each parallel process uses its own temp workspace to avoid conflicts.

## Configuration Subsystem

```
config/
├── default.json         # Base defaults (committed)
├── schema.json          # JSON Schema validation
├── local.json           # Per-machine overrides (gitignored)
└── profiles/
    ├── dev.json         # Development profile
    └── prod.json        # Production profile
```

### Merging Order

```
default.json  ←  local.json  ←  profiles/<profile>.json  ←  env vars  ←  CLI flags
```

Each layer overrides keys from the previous one. The merge is deep (not shallow).

### Loading Sequence

1. `config.sh::load` sources `config/default.sh` for env var fallback defaults
2. Parses `config/default.json` via `jq` (if available)
3. Merges `config/local.json` over defaults
4. If `--profile` given, merges `config/profiles/<profile>.json`
5. Environment variables override (`RELEASE_VERSION`, `OUTPUT_DIR`, etc.)
6. CLI flags override (`--version`, `--output`, etc.)
7. Validates result against `config/schema.json` (if jq + schema available)
8. Exports all config keys as global shell variables

### Key Configuration Sections

| Section | Variables | Purpose |
|---------|-----------|---------|
| `app` | APP_NAME, INSTALL_DIR, DESKTOP_FILE, ICON_FILE, SERVICE_FILE | Application metadata |
| `build` | OUTPUT_DIR, CACHE_DIR, CACHE_ENABLED, BUILD_DIR | Build paths and caching |
| `github` | GITHUB_REPO, RELEASE_PATTERN, API_URL | GitHub release source |
| `signing` | SIGN_ENABLED, GPG_KEY, GPG_HOMEDIR | GPG signing |
| `logging` | LOG_LEVEL, LOG_FORMAT, LOG_FILE, LOG_MAX_SIZE, LOG_MAX_FILES | Structured logging |
| `pipeline` | STAGES, TARGETS, PARALLEL | Pipeline execution |
| `profiles` | — | Active profile name |

## Template Engine

`src/core/template.sh` renders metadata files from `templates/` using `envsubst`.

### Variable Scoping

Only configuration variables are substituted. Shell runtime variables (like `APP_PATH` in postinst scripts) are preserved.

```bash
# Config vars that get substituted:
TEMPLATE_VARS=(APP_NAME INSTALL_DIR CLIENT_SCRIPT SERVICE_SCRIPT
               DESKTOP_FILE ICON_FILE SERVICE_FILE VERSION ARCH)

# Runtime vars left as-is for shell execution at install time:
# APP_PATH, /usr/local/bin/amneziavpn, systemd paths, etc.
```

### Template Rendering

```bash
render_template "templates/debian/postinst" > "${control_dir}/postinst"
```

The function:
1. Reads the template file
2. Exports only `TEMPLATE_VARS` into the environment
3. Runs `envsubst` with explicit variable list
4. Returns rendered content on stdout

### Template Reuse

To add a new variable:
1. Add it to `_REQUIRED_TEMPLATE_VARS` in `template.sh`
2. Add its value to `config/default.json`
3. Reference it as `${VAR_NAME}` in any template

## Logging Subsystem

`src/core/logger.sh` provides structured logging.

### Log Levels

`ERROR` (0), `WARN` (1), `INFO` (2), `DEBUG` (3). Configurable via `LOG_LEVEL`.

### Correlation ID

Each build gets a `CORRELATION_ID` (datetime + random, e.g. `20260618_143042_a7f3`). Every log line includes it for tracing.

### Output Formats

| LOG_FORMAT | Example |
|------------|---------|
| `text` (default) | `[2026-06-18 14:30:42] [INFO] [a7f3] ✔ extract` |
| `json` | `{"timestamp":"...","level":"INFO","correlation_id":"a7f3","message":"✔ extract"}` |

### File Output

When `LOG_FILE` is set, logs are written to file with automatic rotation:
- Max file size: `LOG_MAX_SIZE` (default 10MB)
- Max rotated files: `LOG_MAX_FILES` (default 3)

## SBOM Generation

`src/core/sbom.sh` produces CycloneDX 1.5 JSON.

### Process

1. Scan `TARGET_DIR/client/bin/` for all binaries
2. Compute SHA-256 for each file
3. Build CycloneDX document with:
   - Component per file (type: library, purl: generic)
   - Metadata with tools list
   - UUIDs for component refs
4. Write to `OUTPUT_DIR/<app>_<version>-sbom.json`

Implemented in python3 for reliable JSON construction (avoiding fragile shell JSON).

## Build Manifest

Generated by `pipeline.sh::generate_manifest` after packaging completes.

```json
{
  "version": "4.8.19.0",
  "correlation_id": "20260618_143042_a7f3",
  "timestamp": "2026-06-18T14:30:42Z",
  "artifacts": [
    {
      "name": "amneziavpn_4.8.19.0_amd64.deb",
      "path": "/pkgs/amneziavpn_4.8.19.0_amd64.deb",
      "size": 91234567,
      "sha256": "abc123..."
    }
  ],
  "config": {
    "app_name": "AmneziaVPN",
    "install_dir": "/opt/AmneziaVPN",
    "profile": "prod"
  }
}
```

Written to `OUTPUT_DIR/build-manifest.json`.

## GPG Signing

When `--sign` is active (`SIGN_ENABLED=true`), each artifact is signed after packaging:

```bash
gpg --detach-sign --armor \
    --default-key "$GPG_KEY" \
    "$artifact"
# → artifact.sig
```

Supports `GPG_HOMEDIR` for non-default keyrings.

## Caching

### API Response Cache

GitHub API responses cached in `CACHE_DIR/api/` for 1 hour. Speeds up repeated builds fetching the same release data.

### Tarball Cache

Downloaded tarballs stored in `CACHE_DIR/tarballs/`. On rebuild with the same version, the cached tarball is reused unless `CACHE_ENABLED=false`.

Clean cache:
```bash
rm -rf ~/.cache/amnezia-packager
```

## Post-Install Health Check

`tools/healthcheck.sh` validates:

1. Binary exists at `$APP_PATH/client/bin/AmneziaVPN` and is executable
2. CLI symlink at `/usr/local/bin/amneziavpn` resolves
3. Desktop entry at `/usr/share/applications/AmneziaVPN.desktop` exists
4. Icon at `/usr/share/pixmaps/AmneziaVPN.png` exists
5. systemd unit exists, is enabled, and active
6. Filesystem under `$APP_PATH` is read-only (excluding bin/ dirs)

Exit code 0 = all checks pass.

## Package Repository Management

`tools/repo.sh` manages APT and YUM repositories.

### APT

```bash
tools/repo.sh init apt /srv/repo/apt
tools/repo.sh add apt /srv/repo/apt amneziavpn_*.deb
# Generates Packages.gz + Release + Release.gpg
```

### YUM

```bash
tools/repo.sh init yum /srv/repo/yum
tools/repo.sh add yum /srv/repo/yum amneziavpn-*.rpm
# Generates repodata/ with createrepo
```

### Deploy

```bash
tools/repo.sh deploy apt /srv/repo
# Pushes to gh-pages branch at https://<user>.github.io/amnezia-packager/
```

## Auto-Discovery

### Packagers

```bash
packager_discover()   → sources src/packager/*.sh
                         each calls packager_register_impl()
                         which stores its path in _PACKAGERS[]
packager_get(target)  → matches basename against target name
```

### Pipeline Stages

```bash
pipeline_run()        → iterates STAGES array, sources src/stage/<stage>.sh
                         runs run_<stage>()
                         runs pre/post hooks if defined
```

## Headless IFW Extraction

Uses Qt IFW's built-in CLI rather than reverse-engineering the installer binary:

```bash
sudo env QT_QPA_PLATFORM=offscreen "$installer" install \
    --root "$target" \
    --accept-licenses \
    --confirm-command
```

This CLI has been stable across multiple IFW versions and is the officially supported headless mode.

## Cleanup

A trap on `EXIT INT TERM` ensures temp directories are removed. Two-pass cleanup handles root-owned files (from IFW extraction):

```bash
cleanup_handler() {
    local rc=$?
    workspace_cleanup  # rm -rf + sudo rm -rf
    exit $rc
}
```

Cleanup runs on success, failure, SIGINT, and SIGTERM.

## Docker Build

```dockerfile
# Multi-stage:
# Stage 1 (builder):   installs build deps, copies source
# Stage 2 (runner):    minimal runtime, runs build
```

```bash
docker compose run --rm builder ./build.sh -a --tar /tmp/AmneziaVPN_*.tar
```

## CI/CD Pipeline (GitHub Actions)

```
on: [push, pull_request, release]
  └─ jobs:
       ├─ lint:     shellcheck on src/ tools/ tests/
       ├─ test:     bats tests
       ├─ build-deb:  ┐
       ├─ build-arch: ┘ parallel on same runner
       └─ release (on v* tags):
            └─ uploads .deb + .pkg.tar.zst + .sig + sbom + manifest
```

## Vagrant Test Boxes

```ruby
config.vm.define "archlinux"   { box: "archlinux/archlinux" }
config.vm.define "debian"      { box: "debian/bookworm64" }
config.vm.define "fedora"      { box: "fedora/41-cloud-base" }
```

All use rsync synced folder for code sync. Each box builds the native format for its distro.
