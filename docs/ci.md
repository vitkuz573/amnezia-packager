# CI/CD Pipeline (AppVeyor)

## Overview

The project uses [AppVeyor](https://www.appveyor.com) for continuous integration and deployment. The pipeline runs on Linux (Ubuntu 22.04) and executes:

1. **Lint** — shellcheck on all shell scripts
2. **Test** — bats unit tests
3. **Build** — .deb (native) + .rpm (native) + .pkg.tar.zst (via Docker)
4. **Repo deploy** — init APT/YUM/Arch repos, add packages, sign, push to gh-pages
5. **Release** — on version tags, upload all artifacts to GitHub Releases

## Pipeline Steps

### 1. Lint

```bash
shellcheck -x build.sh src/**/*.sh tools/*.sh
```

### 2. Test

```bash
bats tests/ || true
```

Runs 33+ tests covering: logger, bootstrap, config, pipeline, packagers, manifest, SBOM, templates.

### 3. Build

```bash
./build.sh -d -o "$OUTPUT_DIR" --manifest   # .deb
./build.sh -r -o "$OUTPUT_DIR" --manifest   # .rpm
docker build -t amnezia-packager .           # Docker image
docker run ... amnezia-packager -a ...       # .pkg.tar.zst in Arch container
```

Three package formats are built:
- **.deb** — native on Ubuntu
- **.rpm** — native on Ubuntu (install `rpm` package)
- **.pkg.tar.zst** — inside an Arch Linux Docker container (skipped if Docker unavailable)

### 4. Repository Deploy

All built packages are added to the appropriate repos in `gh-pages`:
- `.deb` → `apt/pool/` + `dpkg-scanpackages`
- `.rpm` → `yum/x86_64/` + `createrepo --update`
- `.pkg.tar.zst` → `arch/` + `repo-add`

If a GPG signing key is configured, repo metadata (APT Release + db + repomd.xml) is signed.

### 5. Release (Tagged Versions Only)

On tags matching `v*`:
- Build all three package types with `--sign --gpg-key`
- Upload to GitHub Releases
- Deploy signed repo metadata to gh-pages

### Weekly Schedule

The pipeline runs automatically every Monday at 06:00 UTC to keep packages current.

## Required AppVeyor Secrets

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub PAT for Release upload and gh-pages push (`repo` scope) |
| `REPO_GPG_PRIVATE_KEY` | ASCII-armored GPG private key for repo signing (optional) |

## GPG Key Setup for CI

To enable repo signing in CI:

```bash
# Export the private key
gpg --export-secret-keys --armor B63E7D50DE313425 > repo-private-key.asc

# Encrypt and add to AppVeyor:
#   1. Install AppVeyor CLI: https://www.appveyor.com/docs/cli/
#   2. appveyor encrypt -f repo-private-key.asc
#   3. Add the encrypted value as REPO_GPG_PRIVATE_KEY in project settings
#   4. Also set GPG_KEY_ID = B63E7D50DE313425

# Verify:
#   appveyor secrets list
```

The CI imports the key on startup and uses it for signing both packages and repo metadata.

## Local CI Simulation

```bash
# Run the same checks locally
shellcheck -x build.sh src/**/*.sh tools/*.sh
bats tests/
./build.sh -d -o /tmp/packages --manifest
./build.sh -r -o /tmp/packages --manifest
tools/repo.sh init /tmp/repo
for f in /tmp/packages/*.deb; do tools/repo.sh add "$f" /tmp/repo; done
for f in /tmp/packages/*.rpm; do tools/repo.sh add "$f" /tmp/repo; done
tools/repo.sh release /tmp/repo
tools/repo.sh deploy /tmp/repo "repo: test"
```
