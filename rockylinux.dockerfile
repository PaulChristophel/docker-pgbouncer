# Containerfile.cnpg-pgbouncer-source

ARG BASE=docker.io/rockylinux/rockylinux:10-ubi-micro@sha256:23f5d986ef65b6f3c84299a7bd065b51beea2e917bd8f0a11bf0a9a53774735c
ARG BUILD_BASE=docker.io/rockylinux/rockylinux:10@sha256:e372170ca8630f0f03e9b70fdd0bf4a3ce3426b0de7cdba615f06337389de176
ARG IMAGE_TITLE="CloudNativePG PgBouncer on Rocky Linux"
ARG IMAGE_DESCRIPTION="PgBouncer built from upstream source on Rocky Linux for CloudNativePG."
ARG IMAGE_AUTHORS="Paul Christophel <pmartin@gatech.edu>"
ARG IMAGE_VENDOR="Paul Christophel"
ARG IMAGE_OWNER="Paul Christophel <pmartin@gatech.edu>"
ARG IMAGE_SOURCE="https://github.com/PaulChristophel/docker-pgbouncer"
ARG IMAGE_REPOSITORY="docker.io/pcm0/pgbouncer"
ARG IMAGE_URL="https://hub.docker.com/r/pcm0/pgbouncer"
ARG IMAGE_DOCUMENTATION="https://github.com/PaulChristophel/docker-pgbouncer#readme"
ARG IMAGE_REVISION="unknown"
ARG IMAGE_CREATED="1970-01-01T00:00:00Z"
ARG IMAGE_LICENSES="AGPL-3.0-or-later"

FROM $BUILD_BASE AS pgbouncer-builder
ARG PGBOUNCER_VERSION=1.25.2
ARG PGBOUNCER_COMMIT=13a344f2625381296fc02e29b986a11be9c6b983
ARG PGBOUNCER_SOURCE_SHA256=50a59fd102e6dce89cf05ff7b07c5cb2bd8e74b4ea24ca192b27cc508634c780
ARG PGBOUNCER_CFLAGS="-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"
ARG PGBOUNCER_LDFLAGS="-Wl,-z,relro,-z,now -Wl,--as-needed"

USER root
RUN dnf install -y --enablerepo=crb \
      binutils \
      c-ares-devel \
      gcc \
      glibc-devel \
      kernel-headers \
      libevent-devel \
      meson \
      ninja-build \
      openldap-devel \
      openssl-devel \
      pkgconf-pkg-config \
      shadow-utils \
      tar \
      wget \
 && wget -O /tmp/pgbouncer.tar.gz \
      https://github.com/pgbouncer/pgbouncer/archive/${PGBOUNCER_COMMIT}.tar.gz \
 && echo "${PGBOUNCER_SOURCE_SHA256}  /tmp/pgbouncer.tar.gz" | sha256sum -c - \
 && mkdir -p /tmp/pgbouncer-src /tmp/pgbouncer-install \
 && tar -xzf /tmp/pgbouncer.tar.gz -C /tmp/pgbouncer-src --strip-components=1 \
 && groupadd -r pgbouncer-build \
 && useradd -r -g pgbouncer-build -d /tmp/pgbouncer-build pgbouncer-build \
 && mkdir -p /tmp/pgbouncer-build \
 && chown -R pgbouncer-build:pgbouncer-build \
      /tmp/pgbouncer-src \
      /tmp/pgbouncer-build \
      /tmp/pgbouncer-install

USER pgbouncer-build
WORKDIR /tmp/pgbouncer-src
RUN CFLAGS="${PGBOUNCER_CFLAGS}" \
    LDFLAGS="${PGBOUNCER_LDFLAGS}" \
    meson setup build \
      --buildtype=release \
      --prefix=/usr \
      -Dcares=enabled \
      -Dldap=enabled \
      -Dopenssl=enabled \
      -Dpam=disabled \
      -Dsystemd=disabled \
 && meson compile -C build \
 && meson install -C build --destdir=/tmp/pgbouncer-install \
 && /tmp/pgbouncer-install/usr/bin/pgbouncer --version


FROM $BUILD_BASE AS runtime-builder

USER root
RUN mkdir -p /mnt/rootfs \
 && dnf install -y \
      --installroot=/mnt/rootfs \
      --releasever=10 \
      --setopt=install_weak_deps=False \
      bash \
      c-ares \
      ca-certificates \
      coreutils \
      glibc-minimal-langpack \
      libevent \
      openldap \
      openssl-libs \
      postgresql \
      shadow-utils \
 && dnf clean all --installroot=/mnt/rootfs \
 && rm -rf /mnt/rootfs/var/cache/dnf


FROM $BASE
ARG BASE
ARG PGBOUNCER_VERSION=1.25.2
ARG PGBOUNCER_COMMIT=13a344f2625381296fc02e29b986a11be9c6b983
ARG IMAGE_TITLE
ARG IMAGE_DESCRIPTION
ARG IMAGE_AUTHORS
ARG IMAGE_VENDOR
ARG IMAGE_OWNER
ARG IMAGE_SOURCE
ARG IMAGE_REPOSITORY
ARG IMAGE_URL
ARG IMAGE_DOCUMENTATION
ARG IMAGE_REVISION
ARG IMAGE_CREATED
ARG IMAGE_LICENSES

LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.base.name="${BASE}"
LABEL org.opencontainers.image.authors="${IMAGE_AUTHORS}"
LABEL org.opencontainers.image.title="${IMAGE_TITLE}"
LABEL org.opencontainers.image.description="${IMAGE_DESCRIPTION}"
LABEL org.opencontainers.image.vendor="${IMAGE_VENDOR}"
LABEL org.opencontainers.image.source="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.url="${IMAGE_URL}"
LABEL org.opencontainers.image.documentation="${IMAGE_DOCUMENTATION}"
LABEL org.opencontainers.image.version="${PGBOUNCER_VERSION}"
LABEL org.opencontainers.image.revision="${IMAGE_REVISION}"
LABEL org.opencontainers.image.licenses="${IMAGE_LICENSES}"
LABEL org.opencontainers.image.ref.name="${IMAGE_REPOSITORY}"
LABEL org.opencontainers.image.component.pgbouncer.version="${PGBOUNCER_VERSION}"
LABEL org.opencontainers.image.component.pgbouncer.revision="${PGBOUNCER_COMMIT}"
LABEL edu.gatech.image.owner="${IMAGE_OWNER}"
LABEL edu.gatech.image.repository="${IMAGE_REPOSITORY}"

COPY --from=runtime-builder /mnt/rootfs/ /
COPY --from=pgbouncer-builder /tmp/pgbouncer-install/ /

USER root
RUN if getent passwd 998 >/dev/null; then userdel "$(getent passwd 998 | cut -d: -f1)"; fi \
 && groupadd -r -g 996 pgbouncer \
 && useradd -r -u 998 -g 996 pgbouncer \
 && mkdir -p /etc/pgbouncer /var/run/pgbouncer /var/log/pgbouncer \
 && chown -R pgbouncer:pgbouncer \
      /etc/pgbouncer \
      /var/run/pgbouncer \
      /var/log/pgbouncer

EXPOSE 6432
USER pgbouncer

COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
