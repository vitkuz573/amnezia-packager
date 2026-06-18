#!/bin/bash
#
# repo.sh — manage APT/Arch/YUM package repositories on GitHub Pages
#
# Usage: ./tools/repo.sh <command> [options]
#
# Commands:
#   init <dir>                  Initialize repo structure
#   add <pkg> <dir>             Add a package (deb/pkg.tar.zst/rpm)
#   release <dir> [--gpg-key K] Generate Release + sign APT & Arch
#   upload [tag]                Upload packages to GitHub Release
#   deploy <dir> [msg]          Commit and push to gh-pages
#

set -euo pipefail

REPO_BRANCH="gh-pages"
REPO_URL="${REPO_URL:-https://github.com/vitkuz573/amnezia-packager.git}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

cmd_init() {
    local dir="${1:-repo}"
    mkdir -p "${dir}/apt/dists/stable/main/binary-amd64"
    mkdir -p "${dir}/apt/pool"
    mkdir -p "${dir}/arch"
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
    mkdir -p "${dir}/arch"
    cp "$pkg" "${dir}/arch/"

    # Find the db name from existing db or use the first package name
    local db_path=""
    for f in "${dir}/arch"/*.db.tar.zst; do
        [[ -f "$f" ]] && { db_path="$f"; break; }
    done
    if [[ -z "$db_path" ]]; then
        # Derive db name from package name (strip version+arch)
        local pkg_name
        pkg_name=$(basename "$pkg" | sed 's/-[0-9].*//')
        db_path="${dir}/arch/${pkg_name}.db.tar.zst"
    fi

    if command -v repo-add &>/dev/null; then
        (cd "${dir}/arch" && repo-add "${db_path}" "$(basename "$pkg")")
        echo "Added $(basename "$pkg") to Arch repo (db: $(basename "$db_path"))"
        # Remove the package binary — it's hosted on GitHub Releases
        rm -f "${dir}/arch/$(basename "$pkg")"
    else
        echo "WARNING: repo-add not found — package copied but no db generated"
    fi
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
        echo "Signed APT Release with key $gpg_key"
    else
        echo "No GPG key specified — APT repo will not be signed (apt will warn)"
    fi

    echo "APT Release ready at ${dist_dir}/Release"

    # Sign YUM repomd.xml
    local yum_dir="${dir}/yum"
    if [[ -f "${yum_dir}/repodata/repomd.xml" ]]; then
        if [[ -n "$gpg_key" ]]; then
            gpg --detach-sign --armor --default-key "$gpg_key" \
                -o "${yum_dir}/repodata/repomd.xml.asc" "${yum_dir}/repodata/repomd.xml"
            echo "Signed YUM repomd.xml with key $gpg_key"
        fi
    fi

    # Sign Arch repo database
    local arch_dir="${dir}/arch"
    if [[ -d "$arch_dir" ]]; then
        for db in "$arch_dir"/*.db.tar.zst; do
            [[ -f "$db" ]] || continue
            if [[ -n "$gpg_key" ]]; then
                rm -f "${db}.sig"
                gpg --detach-sign --default-key "$gpg_key" "$db"
                echo "Signed Arch db: $(basename "$db")"
            fi
            # Ensure symlinks exist (repo-add creates .db -> .db.tar.zst)
            local db_nozst="${db%.tar.zst}"
            if [[ ! -f "$db_nozst" ]]; then
                ln -sf "$(basename "$db")" "$db_nozst" && echo "Symlink: $(basename "$db_nozst")"
            fi
            local files_db="${db%.db.tar.zst}.files.tar.zst"
            if [[ -f "$files_db" ]]; then
                local files_nozst="${files_db%.tar.zst}"
                if [[ ! -f "$files_nozst" ]]; then
                    ln -sf "$(basename "$files_db")" "$files_nozst" && echo "Symlink: $(basename "$files_nozst")"
                fi
                if [[ -n "$gpg_key" ]]; then
                    rm -f "${files_db}.sig"
                    gpg --detach-sign --default-key "$gpg_key" "$files_db"
                fi
            fi
        done
    fi
}

cmd_deploy() {
    local dir="${1:-repo}"
    local msg="${2:-repo update $(date -u +%Y-%m-%d)}"

    # Use token auth if available (CI)
    local push_url="$REPO_URL"
    if [[ -n "$GITHUB_TOKEN" ]]; then
        local repo_path="${REPO_URL#https://github.com/}"
        push_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${repo_path}"
    fi

    if [[ -d "${dir}/.git" ]]; then
        cd "$dir"
        git add -A
        git commit -m "$msg" || true
        git push "$push_url" "$REPO_BRANCH"
    else
        cd "$dir"
        git init
        git checkout -b "$REPO_BRANCH"
        git add -A
        git commit -m "$msg"
        git remote add origin "$push_url"
        git push -f origin "$REPO_BRANCH"
    fi

    echo "Deployed to ${REPO_BRANCH}"
}

cmd_upload() {
    local tag="${1:-packages}"
    shift 2>/dev/null || true

    # Switch to project root for gh commands
    cd "$(dirname "$0")/.."

    # Ensure the tag and release exist
    if ! git rev-parse "$tag" &>/dev/null; then
        git tag "$tag"
        git push origin "$tag"
        gh release create "$tag" --title "AmneziaVPN Packages" \
            --notes "Rolling release of AmneziaVPN native packages" || true
    fi

    # Force-update the tag to current HEAD
    git tag -f "$tag"
    git push -f origin "$tag"

    # Upload all packages from OUTPUT_DIR
    local output_dir="${OUTPUT_DIR:-/tmp/amnezia-pkgs}"
    if [[ -d "$output_dir" ]]; then
        local assets=()
        for f in "$output_dir"/*.deb "$output_dir"/*.pkg.tar.zst "$output_dir"/*.rpm \
                 "$output_dir"/*.sig "$output_dir"/*-sbom.json "$output_dir"/build-manifest.json; do
            [[ -f "$f" ]] && assets+=("$f")
        done
        if [[ ${#assets[@]} -gt 0 ]]; then
            gh release upload "$tag" "${assets[@]}" --clobber
            echo "Uploaded ${#assets[@]} assets to release $tag"
        else
            echo "No assets found in $output_dir"
        fi
    fi
}

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  init <dir>                  Initialize repo structure (APT + Arch + YUM)
  add <pkg> <dir>             Add package (deb/rpm/pkg.tar.zst)
  release <dir> [--gpg-key K] Generate APT Release + sign Arch db
  upload [tag]                Upload packages to GitHub Release (default: packages)
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
    upload)
        shift
        cmd_upload "$@"
        ;;
    *) usage ;;
esac
