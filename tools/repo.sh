#!/bin/bash
#
# repo.sh — manage APT/YUM package repositories on GitHub Pages
#
# Usage: ./tools/repo.sh <command> [options]
#
# Commands:
#   init <dir>       Initialize repo structure
#   add <pkg> <dir>  Add a package to the repo
#   deploy <dir>     Commit and push to gh-pages
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
    cp "$pkg" "${dir}/apt/pool/"
    cd "${dir}/apt"
    dpkg-scanpackages pool /dev/null > "dists/stable/main/binary-amd64/Packages"
    gzip -9kf "dists/stable/main/binary-amd64/Packages"
    echo "Added $(basename "$pkg") to APT repo"
}

cmd_add_rpm() {
    local pkg="$1" dir="${2:-repo}"
    [[ -f "$pkg" && "$pkg" == *.rpm ]] || { echo "Usage: repo add <file.rpm> [dir]"; exit 1; }
    cp "$pkg" "${dir}/yum/x86_64/"
    cd "${dir}/yum"
    createrepo --update .
    echo "Added $(basename "$pkg") to YUM repo"
}

cmd_add_arch() {
    local pkg="$1" dir="${2:-repo}"
    [[ -f "$pkg" && "$pkg" == *.pkg.tar.zst ]] || { echo "Usage: repo add <file.pkg.tar.zst> [dir]"; exit 1; }
    cp "$pkg" "${dir}/yum/x86_64/"  # reuse yum dir for simplicity
    echo "Added $(basename "$pkg")"
}

cmd_deploy() {
    local dir="${1:-repo}"
    local msg="${2:-repo update $(date -u +%Y-%m-%d)}"
    cd "$dir"
    git init
    git checkout -b "$REPO_BRANCH"
    git add -A
    git commit -m "$msg"
    git remote add origin "$REPO_URL"
    git push -f origin "$REPO_BRANCH"
    echo "Deployed to ${REPO_BRANCH}"
}

case "${1:-help}" in
    init)   shift; cmd_init "$@" ;;
    add)
        shift
        local pkg="$1"; shift
        case "$pkg" in
            *.deb)          cmd_add_deb "$pkg" "$@" ;;
            *.rpm)          cmd_add_rpm "$pkg" "$@" ;;
            *.pkg.tar.zst)  cmd_add_arch "$pkg" "$@" ;;
            *)              echo "Unknown package type: $pkg"; exit 1 ;;
        esac
        ;;
    deploy) shift; cmd_deploy "$@" ;;
    *)
        echo "Usage: $0 <init|add|deploy> [args]"
        echo ""
        echo "  init [dir]          Create repo structure"
        echo "  add <pkg> [dir]     Add package (deb/rpm/pkg.tar.zst)"
        echo "  deploy [dir] [msg]  Push to gh-pages"
        ;;
esac
