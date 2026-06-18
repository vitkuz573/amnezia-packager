#!/bin/bash
#
# repo.sh — manage APT/YUM package repositories on GitHub Pages
#
# Usage: ./tools/repo.sh <command> [options]
#
# Commands:
#   init <dir>                  Initialize repo structure
#   add <pkg> <dir>             Add a package to the repo
#   release <dir> [--gpg-key K] Generate Release + Release.gpg + InRelease
#   deploy <dir> [msg]          Commit and push to gh-pages
#

set -euo pipefail

REPO_BRANCH="gh-pages"
REPO_URL="${REPO_URL:-https://github.com/vitkuz573/amnezia-packager.git}"

cmd_init() {
    local dir="${1:-repo}"
    mkdir -p "${dir}/apt/dists/stable/main/binary-amd64"
    mkdir -p "${dir}/apt/pool"
    mkdir -p "${dir}/yum/x86_64"
    mkdir -p "${dir}/yum/repodata"
    echo "Repo initialized at ${dir}/"
}

cmd_add_deb() {
    local pkg="$1" dir="${2:-repo}"
    [[ -f "$pkg" && "$pkg" == *.deb ]] || { echo "Usage: repo add <file.deb> [dir]"; exit 1; }
    mkdir -p "${dir}/apt/pool"
    cp "$pkg" "${dir}/apt/pool/"
    cd "${dir}/apt"
    dpkg-scanpackages pool /dev/null > "dists/stable/main/binary-amd64/Packages"
    gzip -9kf "dists/stable/main/binary-amd64/Packages"
    echo "Added $(basename "$pkg") to APT repo"
}

cmd_add_rpm() {
    local pkg="$1" dir="${2:-repo}"
    [[ -f "$pkg" && "$pkg" == *.rpm ]] || { echo "Usage: repo add <file.rpm> [dir]"; exit 1; }
    mkdir -p "${dir}/yum/x86_64"
    cp "$pkg" "${dir}/yum/x86_64/"
    cd "${dir}/yum"
    createrepo --update .
    echo "Added $(basename "$pkg") to YUM repo"
}

cmd_add_arch() {
    local pkg="$1" dir="${2:-repo}"
    [[ -f "$pkg" && "$pkg" == *.pkg.tar.zst ]] || { echo "Usage: repo add <file.pkg.tar.zst> [dir]"; exit 1; }
    mkdir -p "${dir}/yum/x86_64"
    cp "$pkg" "${dir}/yum/x86_64/"
    echo "Added $(basename "$pkg")"
}

cmd_release() {
    local dir="$1"
    local gpg_key=""

    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gpg-key) gpg_key="$2"; shift 2 ;;
            --gpg-key=*) gpg_key="${1#*=}"; shift ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    local apt_dir="${dir}/apt"
    local dist_dir="${apt_dir}/dists/stable"

    if [[ ! -d "$dist_dir" ]]; then
        echo "APT repo not found at $dist_dir. Run 'init' first."
        exit 1
    fi

    cd "$apt_dir"

    if command -v apt-ftparchive &>/dev/null; then
        apt-ftparchive release "$dist_dir" > "$dist_dir/Release"
    else
        # Manual Release file generation
        local date_rfc=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S UTC")
        {
            echo "Origin: AmneziaVPN Repository"
            echo "Label: AmneziaVPN"
            echo "Suite: stable"
            echo "Codename: stable"
            echo "Date: $date_rfc"
            echo "Architectures: amd64"
            echo "Components: main"
            echo "Description: AmneziaVPN native packages"
        } > "$dist_dir/Release"

        # Collect hashes for all package indices
        local sha256_lines="" sha1_lines="" md5_lines=""
        for pkg_file in "main/binary-amd64/Packages" "main/binary-amd64/Packages.gz"; do
            local f="${dist_dir}/${pkg_file}"
            if [[ -f "$f" ]]; then
                local size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
                local sha256=$(sha256sum "$f" | cut -d' ' -f1)
                local sha1=$(sha1sum "$f" | cut -d' ' -f1)
                local md5=$(md5sum "$f" | cut -d' ' -f1)
                sha256_lines+=" $sha256 $size $pkg_file"$'\n'
                sha1_lines+=" $sha1 $size $pkg_file"$'\n'
                md5_lines+=" $md5 $size $pkg_file"$'\n'
            fi
        done
        if [[ -n "$sha256_lines" ]]; then
            {
                echo "SHA256:"
                echo -n "$sha256_lines"
                echo "SHA1:"
                echo -n "$sha1_lines"
                echo "MD5Sum:"
                echo -n "$md5_lines"
            } >> "$dist_dir/Release"
        fi
    fi

    # Sign Release file
    if [[ -n "$gpg_key" ]]; then
        rm -f "$dist_dir/Release.gpg" "$dist_dir/InRelease"
        gpg --detach-sign --armor --default-key "$gpg_key" -o "$dist_dir/Release.gpg" "$dist_dir/Release"
        gpg --clearsign --default-key "$gpg_key" --output "$dist_dir/InRelease" "$dist_dir/Release"
        echo "Signed Release with key $gpg_key"
    else
        echo "No GPG key specified — repo will not be signed (apt will warn)"
    fi

    echo "APT Release ready at ${dist_dir}/Release"
}

cmd_deploy() {
    local dir="${1:-repo}"
    local msg="${2:-repo update $(date -u +%Y-%m-%d)}"

    if [[ -d "${dir}/.git" ]]; then
        cd "$dir"
        git add -A
        git commit -m "$msg" || true
        git push origin "$REPO_BRANCH"
    else
        cd "$dir"
        git init
        git checkout -b "$REPO_BRANCH"
        git add -A
        git commit -m "$msg"
        git remote add origin "$REPO_URL"
        git push -f origin "$REPO_BRANCH"
    fi

    echo "Deployed to ${REPO_BRANCH}"
}

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  init <dir>                  Initialize repo structure
  add <pkg> <dir>             Add package (deb/rpm/pkg.tar.zst)
  release <dir> [--gpg-key K] Generate Release + Release.gpg + InRelease
  deploy <dir> [msg]          Push to gh-pages
EOF
}

case "${1:-help}" in
    init)   shift; cmd_init "$@" ;;
    add)
        shift
        pkg="$1"; shift
        case "$pkg" in
            *.deb)          cmd_add_deb "$pkg" "$@" ;;
            *.rpm)          cmd_add_rpm "$pkg" "$@" ;;
            *.pkg.tar.zst)  cmd_add_arch "$pkg" "$@" ;;
            *)              echo "Unknown package type: $pkg"; exit 1 ;;
        esac
        ;;
    release) shift; cmd_release "$@" ;;
    deploy) shift; cmd_deploy "$@" ;;
    *) usage ;;
esac
