# syntax=docker/dockerfile:1
#
# Multi-stage Docker image for reproducible AmneziaVPN packaging
#

# ── Stage 1: builder — install all toolchains ────────────────────────
FROM archlinux:latest AS builder

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel \
        jq \
        curl \
        zstd \
        dpkg \
        rpm-tools \
        fakeroot \
        python3 \
    && rm -rf /var/cache/pacman/pkg/

WORKDIR /build
COPY . .

# ── Stage 2: runner — minimal image with just the runtime deps ───────
FROM archlinux:latest AS runner

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        jq \
        curl \
        zstd \
        dpkg \
        fakeroot \
        sudo \
    && rm -rf /var/cache/pacman/pkg/

WORKDIR /build
COPY --from=builder /build ./

ENTRYPOINT ["./build.sh"]
CMD ["--help"]
