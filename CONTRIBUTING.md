# Contributing

## Project Structure

```
src/
├── core/         # Framework: logger, config, template, bootstrap, pipeline, sbom
├── stage/        # Pipeline stages: fetch, extract, verify
└── packager/     # Output formats: deb, arch, rpm
templates/        # envsubst templates (PKGBUILD, PKGINFO, control, postinst, spec)
config/           # JSON config default + schema + profiles
tools/            # repo.sh (APT/Arch/YUM), healthcheck.sh
tests/            # Bats test suite
```

## Development Environment

```bash
pre-commit install
direnv allow                 # Optional: loads PROJECT_ROOT, PATH_add tools
```

## Adding a New Packager

1. Create `src/packager/<name>.sh`
2. Source interface and register:

```bash
source "${PROJECT_ROOT}/src/packager/00-interface.sh"
packager_register_impl

build_package() { … }
get_artifact()  { echo "$ARTIFACT"; }
get_deps()      { echo "dep1 dep2"; }
```

3. Create templates in `templates/<name>/`
4. Auto-discovery picks it up.

## Template Engine

`src/core/template.sh` renders metadata files via `envsubst` with explicit variable lists. Only config vars are substituted — shell runtime vars like `APP_PATH` are preserved.

### Template Variables

| Variable | Source | Used In |
|----------|--------|---------|
| `APP_NAME`, `INSTALL_DIR` | `app.*` | All templates |
| `DESKTOP_FILE`, `ICON_FILE`, `SERVICE_FILE` | `app.*` | postinst, prerm, spec, INSTALL |
| `DEPS_DEB` | `dependencies.deb` | `control` (comma-separated) |
| `DEPS_ARCH` | `dependencies.arch` | `PKGINFO` (via `DEPS_ARCH_LINES`) |
| `DEPS_RPM` | `dependencies.rpm` | `spec` (via `DEPS_RPM_LINES`) |
| `PKGVER`, `PKGNAME`, `PKGSIZE_KB`, `PKGSIZE_BYTES` | computed | All templates |

### Adding a New Variable

1. Add to `_REQUIRED_TEMPLATE_VARS` in `src/core/template.sh`
2. Add default to `config/default.json`
3. Export in `template::render` and add to the envsubst `$vars` list
4. Reference as `${VAR_NAME}` in any template

## Pipeline Stages

| Stage | Script | Creates |
|-------|--------|---------|
| fetch | `src/stage/fetch.sh` | Tarball in `BUILD_DIR` |
| extract | `src/stage/extract.sh` | Application files in `TARGET_DIR` |
| verify | `src/stage/verify.sh` | — |
| package | `src/packager/<target>.sh` | Native package in `OUTPUT_DIR` |

Each stage exports `run_<stage>()`. Optional `pre_<stage>` / `post_<stage>` hooks are auto-discovered.

## Config System

Layered (later wins):

1. `config/default.json` — defaults
2. `config/local.json` — gitignored overrides
3. `config/profiles/<profile>.json` — via `--profile`
4. Environment variables
5. CLI flags

Requires `jq`. Without `jq`, falls back to env var overrides only.

## Package Repository (`tools/repo.sh`)

Manages three repo formats:

| Command | Purpose |
|---------|---------|
| `init <dir>` | Create apt/ + arch/ + yum/ directories |
| `add <pkg> <dir>` | Add deb/pkg.tar.zst/rpm, generate metadata |
| `release <dir> --gpg-key K` | Sign APT Release + Arch db |
| `upload [tag]` | Upload packages to GitHub Releases (tag: `packages`) |
| `deploy <dir> [msg]` | Push metadata to gh-pages |

Key architecture: package binaries on GitHub Releases, repo metadata on gh-pages.

## Testing

```bash
make test           # Bats tests
LOG_LEVEL=debug bats tests/core.bats  # Verbose
```

Test workflow:
1. `./build.sh -n --tar /path/to/AmneziaVPN_*.tar` — dry-run
2. `./build.sh -a --tar /path/to/AmneziaVPN_*.tar -o /tmp/pkg` — build
3. `tools/healthcheck.sh` — post-install validation
4. `docker run --rm -v /tmp/pkg:/pkgs debian:bookworm-slim bash` — test install

### Vagrant Testing

```bash
vagrant up archlinux
vagrant ssh archlinux
cd /vagrant && ./build.sh -a --tar /vagrant/AmneziaVPN_*.tar
```

## Coding Style

- **Shell**: Bash 4.4+, `set -euo pipefail`
- **Naming**: snake_case for variables, camelCase for functions
- **Logging**: `debug`, `info`, `succ`, `warn`, `err` (from `src/core/logger.sh`)
- **No comments** in code
- **Guard against double-load**: `[[ -n "${__FOO_LOADED:-}" ]] && return; __FOO_LOADED=1`
- **Templates**: runtime shell vars (`APP_PATH`) must remain unsubstituted

## Commit Messages

Conventional commits:

```
feat: add RPM packager
fix: handle missing version in --tar mode
docs: add architecture overview
refactor: extract template engine
test: add pipeline bats tests
```
