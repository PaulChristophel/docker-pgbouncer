# Containerfile.cnpg-pgbouncer-source

ARG BASE=docker.io/opensuse/tumbleweed:latest@sha256:8f6397b7b7ebc78e111d9a13fb2b157664ad5524e1f3b908deb45938b3095045
ARG BUILD_BASE=docker.io/opensuse/tumbleweed:latest@sha256:8f6397b7b7ebc78e111d9a13fb2b157664ad5524e1f3b908deb45938b3095045
ARG IMAGE_TITLE="CloudNativePG PgBouncer on openSUSE Tumbleweed"
ARG IMAGE_DESCRIPTION="PgBouncer built from upstream source on openSUSE Tumbleweed for CloudNativePG."
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
RUN zypper --non-interactive --gpg-auto-import-keys install --no-recommends \
      bsdtar \
      c-ares-devel \
      gcc \
      glibc-devel \
      libevent-devel \
      libopenssl-devel \
      meson \
      ninja \
      openldap2-devel \
      pkg-config \
      python3 \
      shadow \
      wget \
 && wget -O /tmp/pgbouncer.tar.gz \
      https://github.com/pgbouncer/pgbouncer/archive/${PGBOUNCER_COMMIT}.tar.gz \
 && echo "${PGBOUNCER_SOURCE_SHA256}  /tmp/pgbouncer.tar.gz" | sha256sum -c - \
 && mkdir -p /tmp/pgbouncer-src /tmp/pgbouncer-install \
 && bsdtar -xzf /tmp/pgbouncer.tar.gz -C /tmp/pgbouncer-src --strip-components=1 \
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
 && /tmp/pgbouncer-install/usr/bin/pgbouncer --version \
 && ! ldd /tmp/pgbouncer-install/usr/bin/pgbouncer | grep -q "not found"


FROM $BASE AS runtime-builder

USER root
RUN mkdir -p /mnt/rootfs \
 && zypper --installroot /mnt/rootfs \
      --non-interactive \
      --gpg-auto-import-keys \
      install --no-recommends \
      bash \
      ca-certificates \
      coreutils \
      libcares2 \
      libevent-2_1-7 \
      libldap2 \
      libopenssl3 \
      openSUSE-release \
      postgresql18 \
      shadow \
      timezone \
 && touch /mnt/rootfs/etc/sysconfig/postgresql \
 && zypper --installroot /mnt/rootfs --non-interactive update -y \
 && zypper --installroot /mnt/rootfs --non-interactive clean --all \
 && rm -rf /mnt/rootfs/var/cache/zypp


FROM scratch
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
ARG IMAGE_DISTRIBUTION=tumbleweed
ARG IMAGE_DISTRIBUTION_VERSION=unknown

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
LABEL edu.gatech.image.os.distribution="${IMAGE_DISTRIBUTION}"
LABEL edu.gatech.image.os.version="${IMAGE_DISTRIBUTION_VERSION}"

USER root
COPY --from=runtime-builder /mnt/rootfs/ /
RUN groupadd -r --gid 996 pgbouncer \
 && useradd -r --uid 998 --gid 996 pgbouncer \
 && mkdir -p /etc/pgbouncer /var/run/pgbouncer /var/log/pgbouncer \
 && chown -R pgbouncer:pgbouncer \
      /etc/pgbouncer \
      /var/run/pgbouncer \
      /var/log/pgbouncer

COPY --from=pgbouncer-builder /tmp/pgbouncer-install/ /

EXPOSE 6432
USER pgbouncer

COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
