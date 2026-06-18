# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         build.sh (entry)                                │
├─────────────────────────────────────────────────────────────────────────┤
│  src/core/config.sh    ───  layered JSON config → global vars           │
│  src/core/logger.sh    ───  structured logging (text/JSON)              │
│  src/core/template.sh  ───  envsubst template rendering (DEPS_*_LINES)  │
│  src/core/bootstrap.sh ───  workspace, cleanup, distro detection        │
│  src/core/pipeline.sh  ───  CLI parsing, stage orchestration            │
│  src/core/sbom.sh      ───  CycloneDX SBOM generator                   │
├─────────────────────────────────────────────────────────────────────────┤
│                      Pipeline (pipeline.sh)                             │
│                                                                         │
│   ┌──────┐    ┌─────────┐    ┌──────┐    ┌──────────────────┐          │
│   │fetch │───▶│ extract │───▶│verify│───▶│ package (per fmt) │          │
│   └──────┘    └─────────┘    └──────┘    └──────────────────┘          │
│      │             │              │              │                      │
│   pre/post       pre/post       pre/post       pre/post                │
│                                                                         │
│   Output: sbom.json + build-manifest.json + (.deb|.pkg|.rpm) + .sig    │
└─────────────────────────────────────────────────────────────────────────┘
│                                                                         │
│  tools/repo.sh       ───  init → add → release → upload → deploy        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ gh-pages: apt/ (Packages, Release, pool) + arch/ (db, files)    │    │
│  │ GitHub Releases (tag: packages): large binaries (.pkg.tar.zst)   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pipeline

```
fetch ──→ extract ──→ verify ──→ package
```

| Stage | Script | Input → Output |
|-------|--------|----------------|
| fetch | `src/stage/fetch.sh` | GitHub release or `--tar` → tarball in `BUILD_DIR` |
| extract | `src/stage/extract.sh` | tarball → headless IFW → files in `TARGET_DIR` |
| verify | `src/stage/verify.sh` | `TARGET_DIR` → validated file layout |
| package | `src/packager/<target>.sh` | `TARGET_DIR` → native package in `OUTPUT_DIR` |

Each stage is an independent script with `run_<stage>()`. Sourced on demand.

### Hooks

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

### Parallel Execution

```bash
for target in "${TARGETS[@]}"; do
    ( pipeline_package "$target" ) &
done
wait
```

## Configuration Subsystem

```
config/
├── default.json         # Base defaults
├── schema.json          # JSON Schema
├── local.json           # Per-machine (gitignored)
└── profiles/
    ├── dev.json         # Debug + JSON logs
    └── prod.json        # Sign + manifest + cache
```

### Merging Order

```
default.json ← local.json ← profile.json ← env vars ← CLI flags
```

Each layer overrides keys from the previous one (deep merge).

### Loading Sequence

1. Parse `default.json` via `jq`
2. Merge `local.json`
3. Merge `profiles/<profile>.json` if `--profile` given
4. Override from environment variables
5. Override from CLI flags
6. Validate against `schema.json`
7. Export as global shell variables

Without `jq`: falls back to `config/default.sh` + env vars.

### Key Config Sections

| Section | Purpose |
|---------|---------|
| `app` | APP_NAME, INSTALL_DIR, desktop/icon/service filenames |
| `build` | OUTPUT_DIR, CACHE_DIR, cache toggle |
| `github` | upstream repo, release pattern |
| `dependencies` | DEPS_DEB, DEPS_ARCH, DEPS_RPM |
| `signing` | SIGN_ENABLED, GPG_KEY |
| `logging` | LOG_LEVEL, LOG_FORMAT, file output + rotation |
| `pipeline` | STAGES, TARGETS, PARALLEL |

## Template Engine

`src/core/template.sh` renders metadata files from `templates/` using `envsubst`.

### Variable Scoping

Only config variables are substituted. Shell runtime variables (like `APP_PATH` in postinst scripts) are preserved.

```bash
# Config vars that get substituted — defined in template.sh $vars list:
# APP_NAME, INSTALL_DIR, CLIENT_SCRIPT, SERVICE_SCRIPT, DESKTOP_FILE
# ICON_FILE, SERVICE_FILE, PKGVER, PKGNAME, PKGSIZE_KB, PKGSIZE_BYTES
# DEPS_DEB, DEPS_ARCH, DEPS_RPM, DEPS_ARCH_LINES, DEPS_RPM_LINES
# PACKAGE_VENDOR, PACKAGE_LICENSE, PACKAGE_DESCRIPTION, PACKAGE_URL
```

### Dependency Formatting

Dependencies are formatted for each package manager before substitution:

```
DEPS_ARCH   = "xcb-util-cursor libxcb ..."
  → DEPS_ARCH_LINES = "depend = xcb-util-cursor\ndepend = libxcb\n..."

DEPS_DEB    = "libxcb-cursor0, libxcb-xinerama0, ..."
  → used directly in control (comma-separated)

DEPS_RPM    = "libxcb-cursor libxcb-xinerama ..."
  → DEPS_RPM_LINES = "Requires: libxcb-cursor\nRequires: libxcb-xinerama\n..."
```

### Rendering

```bash
template::render "templates/debian/postinst" "${control_dir}/postinst"
# Exports only vars in the envsubst list, substitutes them in the template
```

## Repository Management

### Three Formats

| Format | Tool | Metadata Location | Package Location |
|--------|------|-------------------|------------------|
| APT (.deb) | `dpkg-scanpackages` + manual Release | gh-pages `apt/` | gh-pages `pool/` (<100MB) |
| Arch (.pkg.tar.zst) | `repo-add` | gh-pages `arch/` | GitHub Releases (>100MB) |
| YUM (.rpm) | `createrepo` | gh-pages `yum/` | gh-pages |

### repo.sh Commands

```bash
tools/repo.sh init /srv/repo          # Create apt/ + arch/ + yum/
tools/repo.sh add file.deb /srv/repo  # Add pkg, update db
tools/repo.sh release /srv/repo --gpg-key K  # Sign APT Release + Arch db
tools/repo.sh upload [tag]            # Upload pkgs to GitHub Releases
tools/repo.sh deploy /srv/repo "msg"  # Push metadata to gh-pages
```

### Dual-Server Resolver (Arch)

Pacman is configured with two `Server` directives:

```
[amneziavpn]
Server = https://github.com/vitkuz573/amnezia-packager/releases/download/packages
Server = https://vitkuz573.github.io/amnezia-packager/arch
```

Pacman tries each server for each file:
- **db** (repo metadata) → found on gh-pages (second server)
- **package** (.pkg.tar.zst) → found on GitHub Releases (first server)

## Package Repository Lifecycle

```
push to main
  │
  ├─ AppVeyor CI
  │   ├─ shellcheck + bats tests
  │   ├─ build .deb + sign
  │   ├─ tools/repo.sh init /tmp/repo
  │   ├─ tools/repo.sh add *.deb /tmp/repo
  │   ├─ tools/repo.sh release /tmp/repo --gpg-key $KEY
  │   ├─ tools/repo.sh deploy /tmp/repo
  │   │   └─ git push metadata → gh-pages
  │   └─ tools/repo.sh upload packages
  │       └─ gh release upload → GitHub Releases
  │
  └─ user actions
      ├─ apt update → gh-pages (InRelease + Packages.gz) → apt install → gh-pages (pool/*.deb)
      └─ pacman -Sy → gh-pages (db) → pacman -S → GitHub Releases (.pkg.tar.zst)
```

## Headless IFW Extraction

```bash
sudo env QT_QPA_PLATFORM=offscreen "$installer" install \
    --root "$target" \
    --accept-licenses \
    --confirm-command
```

This CLI has been stable across multiple IFW versions.

## Cleanup

Two-pass cleanup handles root-owned files:

```bash
cleanup_handler() {
    local rc=$?
    workspace_cleanup  # rm -rf + sudo rm -rf
    exit $rc
}
```

## GPG Signing

Two levels of signing:

1. **Package signing**: `gpg --detach-sign --armor` — produces `.sig` for each artifact
2. **Repo signing**: `gpg --clearsign` (InRelease) + `gpg --detach-sign` (Release.gpg, db.tar.zst.sig)

## Logging

- Levels: ERROR (0), WARN (1), INFO (2), DEBUG (3)
- Correlation ID per build (e.g. `20260618_143042_a7f3`)
- Formats: text (`[time] [level] [cid] message`) or JSON
- File output with rotation (10MB max, 3 files)

## SBOM

CycloneDX 1.5 JSON: scans `TARGET_DIR/client/bin/`, SHA-256 for each binary, purl + license metadata.

## Build Manifest

JSON per build: version, correlation_id, timestamp, artifacts (name, size, sha256), config snapshot.

## Docker Build

Multi-stage: builder (toolchains) → runner (minimal runtime).

```bash
make docker-run-arch   # Build Arch inside Docker
docker compose run --rm builder ./build.sh -a
```

## CI/CD (AppVeyor)

```yaml
image: Ubuntu2204
branches: main

install: apt-get install jq curl shellcheck bats dpkg-dev fakeroot
build_script:
  - shellcheck
  - bats tests/
  - ./build.sh -d -o $OUTPUT_DIR --manifest
after_build:
  - tools/repo.sh init + add + release --gpg-key
  - tools/repo.sh deploy
for tags: deploy GitHub Release with artifacts
```

## Vagrant

```ruby
config.vm.define "archlinux"   { box: "archlinux/archlinux" }
config.vm.define "debian"      { box: "debian/bookworm64" }
config.vm.define "fedora"      { box: "fedora/41-cloud-base" }
```

## Auto-Discovery

```bash
packager_discover()   → sources src/packager/*.sh, each calls packager_register_impl()
pipeline_run()        → iterates STAGES, sources src/stage/<stage>.sh, runs hooks
```
