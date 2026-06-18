# Contributing

## Project Structure

- `src/core/` — framework code (logger, bootstrap, pipeline)
- `src/stage/` — pipeline stages (fetch, extract, verify)
- `src/packager/` — output format implementations (deb, arch, rpm)

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

3. That's it — auto-discovery picks it up.

## Pipeline Stages

Each stage lives in `src/stage/<name>.sh` and exports a single entry point:

```bash
run_<name>() {
    # Your logic here
}
```

Optional hooks (sourced automatically if defined):
- `pre_<name>()` — runs before the stage
- `post_<name>()` — runs after the stage

Available stages: `fetch`, `extract`, `verify`.

## Coding Style

- **Shell**: Bash 4.4+, `set -euo pipefail`
- **Naming**: snake_case for variables, camelCase for functions
- **Logging**: use `debug`, `info`, `succ`, `warn`, `err` (from `logger.sh`)
- **No comments** in code — let the code speak
- **Guard against double-load**: `[[ -n "${__FOO_LOADED:-}" ]] && return; __FOO_LOADED=1`

## Testing

Run a dry-run first:

```bash
./build.sh -n --tar /path/to/test.tar
```

Then a full build on a local tarball:

```bash
./build.sh -a --tar /path/to/test.tar -o /tmp/test-pkg
```

Inspect the artifact and verify installation:

```bash
sudo pacman -U /tmp/test-pkg/*.pkg.tar.zst
pacman -Ql amneziavpn
sudo systemctl status amneziavpn
sudo pacman -R amneziavpn
```

## Commit Messages

Follow conventional commits:

```
feat: add RPM packager
fix: handle missing version in --tar mode
docs: add architecture overview
```
