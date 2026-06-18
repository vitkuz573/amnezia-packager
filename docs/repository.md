# Package Repository Guide

AmneziaVPN Packager maintains public APT and Arch Linux repositories at `vitkuz573.github.io/amnezia-packager/`.

## Repository URLs

| Format | Base URL |
|--------|----------|
| **APT** (Debian/Ubuntu) | `https://vitkuz573.github.io/amnezia-packager/apt` |
| **Arch** (pacman) | db: `https://vitkuz573.github.io/amnezia-packager/arch`, packages: `https://github.com/vitkuz573/amnezia-packager/releases/download/packages` |
| **YUM** (RHEL/Fedora) | `https://vitkuz573.github.io/amnezia-packager/yum` |
| **Public GPG key** | `https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc` |

## APT (Debian/Ubuntu)

### Add Repository

```bash
# Install required tools
sudo apt update
sudo apt install -y curl gnupg ca-certificates

# Import GPG key
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/amneziavpn.gpg

# Add APT source
echo "deb [signed-by=/usr/share/keyrings/amneziavpn.gpg] https://vitkuz573.github.io/amnezia-packager/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/amneziavpn.list

# Update and install
sudo apt update
sudo apt install amneziavpn
```

### What Happens

1. `apt update` fetches `InRelease` (signed with repo GPG key) and `Packages.gz`
2. GPG signature is verified against the imported key
3. `apt install` downloads `.deb` from `pool/` on gh-pages
4. Dependencies (`libxcb-*`, etc.) are resolved automatically

### Remove

```bash
sudo apt remove amneziavpn
sudo rm /etc/apt/sources.list.d/amneziavpn.list
sudo rm /usr/share/keyrings/amneziavpn.gpg
sudo apt update
```

## Arch Linux (pacman)

### Add Repository

```bash
# Import GPG key
curl -sS https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc \
  | sudo pacman-key --add -
sudo pacman-key --lsign-key repo@amneziavpn.local

# Add to pacman.conf
cat >> /etc/pacman.conf <<"EOF"

[amneziavpn]
SigLevel = Optional TrustAll
Server = https://github.com/vitkuz573/amnezia-packager/releases/download/packages
Server = https://vitkuz573.github.io/amnezia-packager/arch
EOF

# Update and install
sudo pacman -Sy
sudo pacman -S amneziavpn
```

### Dual-Server Architecture

Pacman is configured with two `Server` directives:

1. **GitHub Releases** (`releases/download/packages`) — hosts the actual `.pkg.tar.zst` (>100MB)
2. **GitHub Pages** (`vitkuz573.github.io/.../arch`) — hosts the repo database (`amneziavpn.db.tar.zst`)

Pacman tries each server for each file:
- **Database**: fails on server #1 (404), found on server #2
- **Package**: found on server #1 (GitHub Releases), fallback not needed

This keeps the package metadata (<10KB) on gh-pages and the large binary (>100MB) on GitHub Releases, avoiding GitHub's 100MB git file size limit.

### Signature Verification

The repo database is signed with the project GPG key. After importing the key via `pacman-key`, package authenticity can be verified. With `SigLevel = Optional TrustAll`, unverified packages are still accepted.

### Remove

```bash
sudo pacman -R amneziavpn
# Remove repo entry from /etc/pacman.conf
# Optionally remove key:
sudo pacman-key --delete repo@amneziavpn.local
```

## YUM (RHEL/Fedora)

### Add Repository

```bash
# Import GPG key
sudo rpm --import https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc

# Add repo (at /etc/yum.repos.d/amneziavpn.repo or /etc/dnf/dnf.conf)
cat > /etc/yum.repos.d/amneziavpn.repo <<"EOF"
[amneziavpn]
name=AmneziaVPN Repository
baseurl=https://vitkuz573.github.io/amnezia-packager/yum
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://vitkuz573.github.io/amnezia-packager/repo-public-key.asc
EOF

# Install
sudo dnf install amneziavpn
```

### Remove

```bash
sudo dnf remove amneziavpn
sudo rm /etc/yum.repos.d/amneziavpn.repo
```

## Repository Structure

```
gh-pages branch
├── apt/
│   ├── dists/stable/
│   │   ├── InRelease              # Clearsigned Release
│   │   ├── Release                # Unsigned Release
│   │   ├── Release.gpg            # Detached signature
│   │   └── main/binary-amd64/
│   │       ├── Packages           # Package index
│   │       └── Packages.gz        # Compressed index
│   └── pool/
│       └── amneziavpn_*.deb       # .deb binaries (<100MB)
├── arch/
│   ├── amneziavpn.db -> amneziavpn.db.tar.zst          # Symlink
│   ├── amneziavpn.db.tar.zst                            # Compressed db
│   ├── amneziavpn.db.tar.zst.sig                        # GPG signature
│   ├── amneziavpn.files -> amneziavpn.files.tar.zst     # Symlink
│   ├── amneziavpn.files.tar.zst                         # Files index
│   └── amneziavpn.files.tar.zst.sig                     # GPG signature
├── yum/
│   ├── x86_64/
│   │   └── amneziavpn-*.rpm         # RPM packages
│   └── repodata/
│       ├── repomd.xml               # YUM metadata
│       └── repomd.xml.asc           # GPG signature
└── repo-public-key.asc            # GPG public key

GitHub Releases (tag: packages)
└── amneziavpn-*.pkg.tar.zst       # Arch binaries (>100MB)
```

## Updating the Repository

**Automated via AppVeyor CI** (see [ci.md](ci.md)):
- On each push to `main`: build `.deb`, update APT repo metadata, sign, deploy to gh-pages
- On version tags: also upload artifacts to GitHub Releases

**Manual via repo.sh:**

```bash
# Init repo structure
tools/repo.sh init /tmp/repo

# Add packages
tools/repo.sh add amneziavpn_4.8.19.0_amd64.deb /tmp/repo
tools/repo.sh add amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst /tmp/repo

# Sign metadata
tools/repo.sh release /tmp/repo --gpg-key 0xDEADBEEF

# Upload large binaries to GitHub Releases
tools/repo.sh upload packages

# Deploy metadata to gh-pages
tools/repo.sh deploy /tmp/repo "repo: update 2026-06-18"
```

## GPG Key Management

The repository signing key (`repo@amneziavpn.local`, Ed25519, 3-year expiry) is used for:
- Signing APT `InRelease` and `Release.gpg`
- Signing Arch `amneziavpn.db.tar.zst`

Public key exported to `repo-public-key.asc` at the repo root and on gh-pages.

To rotate the key:
1. Generate a new key: `gpg --batch --passphrase '' --quick-gen-key "Name <email>" ed25519 default 3y`
2. Export: `gpg --armor --export <key-id> > repo-public-key.asc`
3. Re-sign all repo metadata with the new key
4. Update CI secrets with the new key ID
