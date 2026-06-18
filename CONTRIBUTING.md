# Contributing

## Project Structure

```
src/
├── core/         # Framework: logger, config, template, bootstrap, pipeline, sbom
├── stage/        # Pipeline stages: fetch, extract, verify
└── packager/     # Output formats: deb, arch, rpm
templates/        # envsubst templates for package metadata
config/           # JSON config defaults, schema, profiles
tools/            # Health check, repo management
tests/            # Bats test suite
```

## Development Environment

```bash
# Install pre-commit hooks
pre-commit install

# Enable direnv (optional)
direnv allow
```

## Adding a New Packager

1. Create `src/packager/<name>.sh`
2. Source the interface and register:

```bash
source "${PROJECT_ROOT}/src/packager/00-interface.sh"
packager_register_impl

build_package() { … }
get_artifact()  { echo "$ARTIFACT"; }
get_deps()      { echo "dep1 dep2"; }
```

3. Create templates in `templates/<name>/`
4. Auto-discovery picks it up — no central registry.

## Template Engine

Templates use `envsubst` with explicit variable lists to prevent accidental substitution of shell runtime variables:

```bash
# In template.sh — only these vars are substituted:
TEMPLATE_VARS=(APP_NAME INSTALL_DIR CLIENT_SCRIPT SERVICE_SCRIPT DESKTOP_FILE ICON_FILE SERVICE_FILE)

# Shell runtime vars like APP_PATH are preserved as-is in postinst/prerm scripts
```

See `src/core/template.sh` for details. Add new vars to `_REQUIRED_TEMPLATE_VARS`.

## Pipeline Stages

Each stage lives in `src/stage/<name>.sh` with a single entry point `run_<name>()`.

Optional hooks (sourced automatically if defined):
- `pre_<name>()` — runs before the stage
- `post_<name>()` — runs after the stage

Current stages and output directories:

| Stage | Creates | Description |
|-------|---------|-------------|
| fetch | `BUILD_DIR/` | Downloads or links tarball |
| extract | `TARGET_DIR/` | IFW installer → application files |
| verify | — | Validates file layout |
| package | `OUTPUT_DIR/` | Builds native package |

## Config System

Configuration is layered (later wins):

1. `config/default.json` — defaults
2. `config/local.json` — gitignored, per-machine overrides
3. `config/profiles/<profile>.json` — via `--profile` flag
4. Environment variables
5. CLI flags

All config files validated against `config/schema.json` (requires `jq`). Without `jq`, falls back to env var overrides.

Key config sections:

| Section | Purpose |
|---------|---------|
| `app` | APP_NAME, INSTALL_DIR, file names |
| `build` | OUTPUT_DIR, CACHE_DIR, profiles |
| `github` | repo, API, release patterns |
| `signing` | GPG key, sign_enabled |
| `logging` | LOG_LEVEL, log format, log file |
| `pipeline` | stages, packagers, parallel |

## SBOM Module

`src/core/sbom.sh` generates CycloneDX 1.5 SBOM:

```bash
sbom_generate "$target_dir" "$output_dir" "$app_name" "$version"
# → amneziavpn_4.8.19.0-sbom.json
```

- Hashes all files in `client/bin/` using SHA-256
- Encodes as `urn:uuid:<uuid>` for component refs
- Uses python3 for JSON construction (no jq dependency)

## Testing

```bash
make test           # Run bats tests
LOG_LEVEL=debug bats tests/core.bats  # Verbose output
```

Test workflow:

1. **Dry-run first**: `./build.sh -n --tar /path/to/AmneziaVPN_*.tar`
2. **Build with local tarball**: `./build.sh -a --tar /path/to/AmneziaVPN_*.tar -o /tmp/test-pkg`
3. **Verify artifact**: `ls -la /tmp/test-pkg/`
4. **Test install**: `sudo dpkg -i /tmp/test-pkg/*.deb` (or `sudo pacman -U` for Arch)
5. **Run health check**: `tools/healthcheck.sh`
6. **Test uninstall**: `sudo dpkg -r amneziavpn` (or `sudo pacman -R amneziavpn`)

### Docker-based Testing

```bash
# Test .deb in a clean Debian container
sudo dpkg -i amneziavpn_*.deb
sudo apt install -f
```

### Vagrant Testing

Use Vagrant for multi-distro testing:

```bash
vagrant up archlinux
vagrant ssh archlinux
cd /vagrant && ./build.sh -a --tar /vagrant/AmneziaVPN_*.tar
```

## Coding Style

- **Shell**: Bash 4.4+, `set -euo pipefail`
- **Naming**: snake_case for variables, camelCase for functions
- **Logging**: use `debug`, `info`, `succ`, `warn`, `err` (from `src/core/logger.sh`)
- **No comments** in code — let the code speak
- **Guard against double-load**: `[[ -n "${__FOO_LOADED:-}" ]] && return; __FOO_LOADED=1`
- **Templates**: all shell runtime vars (APP_PATH) must remain unsubstituted — only config vars in `TEMPLATE_VARS` get substituted

## Commit Messages

Conventional commits:

```
feat: add RPM packager
fix: handle missing version in --tar mode
docs: add architecture overview
refactor: extract template engine from deb packager
test: add pipeline bats tests
```
