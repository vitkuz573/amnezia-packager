# Build Verification & Supply-Chain Transparency

## Overview

Every package built by `amnezia-packager` includes a **provenance attestation** — a signed JSON document that provides a verifiable chain from the official AmneziaVPN release to the built package.

This allows users to independently verify that a `.deb`, `.rpm`, or `.pkg.tar.zst` was built from the official AmneziaVPN source without tampering.

## Trust Chain

```
GitHub Release API (TLS)
  └─ asset digest (SHA256)
      └─ tarball download ──► hash verification──┐
                                                  ▼
                                          Provenance Document
                                          (source hash + build config + artifact hash)
                                                  │
                                          GPG Signed ──► repo-public-key.asc
                                                  │
                                                  ▼
                                          User Verification
                                          (tools/verify.sh)
```

1. **GitHub API** provides the expected SHA256 digest for each release asset (via TLS-protected API)
2. **Fetch stage** downloads the tarball and verifies its SHA256 against the API digest
3. **Provenance document** records: source URL + SHA256, build command and config, output artifact SHA256
4. **GPG signature** signs the provenance document with the project key (`B63E7D50DE313425`)
5. **User verification** independently checks: GPG signature → source hash → artifact hash

## Generated Files

Each build produces:

| File | Description |
|------|-------------|
| `<package>.deb` / `.rpm` / `.pkg.tar.zst` | Built package |
| `<package>.provenance.json` | Provenance attestation (JSON) |
| `<package>.provenance.json.asc` | GPG detached signature |
| `<package>.sig` | GPG package signature |
| `<package>-sbom.json` | CycloneDX SBOM |
| `build-manifest.json` | Build summary |

## Verifying a Package

### Prerequisites

- The package file (e.g., `amneziavpn_4.8.19.0_amd64.deb`)
- The provenance file (`amneziavpn_4.8.19.0-provenance.json` or `<package>.provenance.json`)
- The GPG signature (`<provenance>.asc`)
- The project GPG public key ([repo-public-key.asc](https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc))

### Using the Verify Tool

```bash
# Download the public key
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  -o repo-public-key.asc

# Import the key into a temporary keyring
gpg --no-default-keyring --keyring ./amneziavpn.kbx \
  --import repo-public-key.asc

# Verify the package provenance
tools/verify.sh --key ./amneziavpn.kbx amneziavpn_4.8.19.0_amd64.deb
```

### Expected Output

```
Provenance: amneziavpn_4.8.19.0-provenance.json
Package:    amneziavpn_4.8.19.0_amd64.deb
GPG signature: VALID
OK: amneziavpn_4.8.19.0_amd64.deb (hash matches)
Source: https://github.com/amnezia-vpn/amnezia-client/releases/download/4.8.19.0/AmneziaVPN_4.8.19.0_linux_x64.tar
Source SHA256: 0b3da257ec93b7f1acc9f90913a6354bf583590e01a33791cd7cf7bb3be1c3b8
Built: 2026-06-18T12:00:00Z
Verification: PASS
```

### Manual Verification

Without the verify tool, you can check the provenance manually:

```bash
# 1. Verify GPG signature
gpg --verify amneziavpn_4.8.19.0-provenance.json.asc

# 2. Verify artifact hash
sha256sum amneziavpn_4.8.19.0_amd64.deb
# Compare with sha256 in provenance JSON

# 3. Check source integrity
# The source SHA256 in the provenance should match the GitHub API digest:
# curl -s https://api.github.com/repos/amnezia-vpn/amnezia-client/releases/tags/4.8.19.0 \
#   | jq '.assets[] | select(.name | test("linux_x64.tar")) | .digest'
```

## Rebuilding to Verify

For the most rigorous verification, you can rebuild from scratch:

```bash
# Clone the packager
git clone https://github.com/vitkuz573/amnezia-packager.git
cd amnezia-packager

# Build the package from the same source
./build.sh -d -v 4.8.19.0 --manifest

# Compare the output package hash with the published provenance
sha256sum /tmp/amnezia-pkgs/amneziavpn_4.8.19.0_amd64.deb
# Should match the sha256 in the published provenance
```

If the hashes match, you have independently reproduced the build, confirming that the published package was built from the same source with the same tooling.

## Provenance Format

```json
{
  "provenance": {
    "version": 1,
    "build_tool": "amnezia-packager",
    "build_tool_version": "2.0.0",
    "build_id": "ci-1749000000",
    "build_time": "2026-06-18T12:00:00Z",
    "builder": {
      "type": "ci",
      "uri": "https://ci.appveyor.com/project/vitkuz573/amnezia-packager"
    }
  },
  "source": {
    "type": "github_release",
    "repo": "amnezia-vpn/amnezia-client",
    "version": "4.8.19.0",
    "url": "https://github.com/amnezia-vpn/amnezia-client/releases/download/4.8.19.0/AmneziaVPN_4.8.19.0_linux_x64.tar",
    "sha256": "0b3da257ec93b7f1acc9f90913a6354bf583590e01a33791cd7cf7bb3be1c3b8"
  },
  "build": {
    "command": "./build.sh -d -o /tmp/packages --manifest",
    "config_profile": "default",
    "target": "deb",
    "arch": "amd64"
  },
  "artifacts": [
    {
      "name": "amneziavpn_4.8.19.0_amd64.deb",
      "sha256": "def456789...",
      "size": 92456789
    }
  ]
}
```

## CI Integration

In AppVeyor CI:
- Source hash is extracted from the GitHub API response during fetch
- Tarball hash is verified before extraction
- Provenance is generated after each build
- Provenance is GPG-signed if `REPO_GPG_PRIVATE_KEY` is configured
- Provenance is deployed to gh-pages alongside repo metadata

## Verifying in CI/Release Workflow

When downloading packages from GitHub Releases:

```bash
# 1. Fetch provenance and signature
curl -sL https://github.com/vitkuz573/amnezia-packager/releases/download/packages/amneziavpn_4.8.19.0-provenance.json -O
curl -sL https://github.com/vitkuz573/amnezia-packager/releases/download/packages/amneziavpn_4.8.19.0-provenance.json.asc -O
curl -sL https://github.com/vitkuz573/amnezia-packager/releases/download/packages/amneziavpn_4.8.19.0_amd64.deb -O

# 2. Import public key
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  | gpg --import

# 3. Verify provenance
gpg --verify amneziavpn_4.8.19.0-provenance.json.asc

# 4. Verify package against provenance
jq -r '.artifacts[0].sha256' amneziavpn_4.8.19.0-provenance.json
sha256sum amneziavpn_4.8.19.0_amd64.deb
# The two must match
```
