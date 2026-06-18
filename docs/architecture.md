# Architecture

## Overview

```
build.sh
  └─ config/default.sh
  └─ src/core/
       ├─ logger.sh        ← structured logging
       ├─ bootstrap.sh     ← workspace, cleanup, distro detection, packager registry
       └─ pipeline.sh      ← stage orchestration + CLI parsing
            ├─ src/stage/fetch.sh        (download from GitHub)
            ├─ src/stage/extract.sh      (run IFW installer headless)
            ├─ src/stage/verify.sh       (validate file layout)
            └─ src/packager/<target>.sh  (build .deb / .pkg.tar.zst / .rpm)
```

## Pipeline

```
fetch ──→ extract ──→ verify ──→ package
  │          │          │           │
  pre        pre        pre         pre
  post       post       post        post
```

Each stage is an independent script with a single entry point `run_<stage>`. The pipeline sources and executes it on demand, never keeping unused stages in memory.

## Hooks

Any stage file may define `pre_<stage>` or `post_<stage>` functions. The pipeline discovers them automatically:

```bash
pipeline::hook() {
    local stage="$1" hook="$2"
    local script="${PROJECT_ROOT}/src/stage/${stage}.sh"
    local fn="${hook}_${stage}"
    if [[ -f "$script" ]]; then
        source "$script" 2>/dev/null || true
        if declare -F "$fn" &>/dev/null; then
            $fn
        fi
    fi
}
```

This allows extending behaviour without modifying pipeline core. For example, a `pre_verify` hook could inject a license file before validation.

## Packager Auto-Discovery

Packagers register themselves at startup. No central registry to update:

```
packager_discover()   → sources src/packager/*.sh
                         each calls packager_register_impl()
                         which stores its path in _PACKAGERS[]
packager_get(target)  → matches basename against target name
```

## Headless IFW Extraction

The system uses Qt IFW's built-in CLI mode rather than reverse-engineering the installer binary:

```bash
sudo env QT_QPA_PLATFORM=offscreen "$installer" install \
    --root "$target" \
    --accept-licenses \
    --confirm-command
```

This CLI has been stable across multiple IFW versions and is the officially supported headless mode.

## Cleanup

A trap on `EXIT INT TERM` ensures temp directories are removed. Two-pass cleanup handles files owned by root (created during IFW extraction):

```bash
cleanup_handler() {
    local rc=$?
    workspace_cleanup  # rm -rf (normal) + sudo rm -rf (root-owned)
    exit $rc
}
```

## Configuration Model

All knobs are plain variables with defaults in `config/default.sh`. Environment overrides take precedence, making it CI-friendly:

```bash
RELEASE_VERSION=4.8.19.0 \
OUTPUT_DIR=/tmp/artifacts \
PACKAGE_TARGET=deb \
  ./build.sh
```
