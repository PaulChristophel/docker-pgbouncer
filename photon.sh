#!/usr/bin/env bash

set -euo pipefail

pushd "$(cd "$(dirname "$0")" && pwd)"

BASE=docker.io/photon:5.0@sha256:6db86de5ffc11d5c55e59d23790ad526b68e5bca4f030cb6a94e6136280866dd
PG_MAJOR=18
PG_VERSION=18.4
PG_SHA256=81a81ec695fb0c7901407defaa1d2f7973617154cf27ba74e3a7ab8e64436094
POSTGRES_CFLAGS="-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"
POSTGRES_LDFLAGS="-Wl,-z,relro,-z,now -Wl,--as-needed"
PG_CRON_VERSION=1.6.7
PG_CRON_COMMIT=465b38c737f584d520229f5a1d69d1d44649e4e5
PG_CRON_SOURCE_SHA256=ab41d388d845c05ab6f34fa8e12011da2d71f7f562194ee105a6fdecb506a70f
PGVECTOR_VERSION=0.8.5
PGVECTOR_COMMIT=159b79aaad5983fb7459c1e3df2897fbb2d11788
PGVECTOR_SOURCE_SHA256=9a483fad70ae2e0a50b3dccb6c4b4931d9a07375a1d5815e82b57870448a7d52
PGAUDIT_VERSION=18.0
PGAUDIT_COMMIT=f39f8dbb15dc5bd4cbe5f1e5abe0d930ed7593a8
PGAUDIT_SOURCE_SHA256=bbfc57be090c82b4efd8f8ed7f613e2d8537c38c35f25bb2d1c005d5747ef2e4
TAG="${PG_MAJOR}-standard-photon5"
IMAGE_TITLE="CloudNativePG PostgreSQL on Photon"
IMAGE_DESCRIPTION="PostgreSQL built from upstream source on Photon OS for CloudNativePG."
IMAGE_AUTHORS="Paul Christophel <pmartin@gatech.edu>"
IMAGE_VENDOR="Paul Christophel"
IMAGE_SOURCE="https://github.com/PaulChristophel/docker-postgresql"
IMAGE_REPOSITORY="docker.io/pcm0/postgres"
IMAGE_URL="https://hub.docker.com/r/pcm0/postgres"
IMAGE_DOCUMENTATION="https://github.com/PaulChristophel/docker-postgresql#readme"
IMAGE_REVISION="$(git rev-parse HEAD)"
IMAGE_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
IMAGE_LICENSES="PostgreSQL"

podman build \
    --build-arg BASE="${BASE}" \
    --build-arg PG_MAJOR="${PG_MAJOR}" \
    --build-arg PG_VERSION="${PG_VERSION}" \
    --build-arg PG_SHA256="${PG_SHA256}" \
    --build-arg POSTGRES_CFLAGS="${POSTGRES_CFLAGS}" \
    --build-arg POSTGRES_LDFLAGS="${POSTGRES_LDFLAGS}" \
    --build-arg PG_CRON_VERSION="${PG_CRON_VERSION}" \
    --build-arg PG_CRON_COMMIT="${PG_CRON_COMMIT}" \
    --build-arg PG_CRON_SOURCE_SHA256="${PG_CRON_SOURCE_SHA256}" \
    --build-arg PGVECTOR_VERSION="${PGVECTOR_VERSION}" \
    --build-arg PGVECTOR_COMMIT="${PGVECTOR_COMMIT}" \
    --build-arg PGVECTOR_SOURCE_SHA256="${PGVECTOR_SOURCE_SHA256}" \
    --build-arg PGAUDIT_VERSION="${PGAUDIT_VERSION}" \
    --build-arg PGAUDIT_COMMIT="${PGAUDIT_COMMIT}" \
    --build-arg PGAUDIT_SOURCE_SHA256="${PGAUDIT_SOURCE_SHA256}" \
    --build-arg IMAGE_TITLE="${IMAGE_TITLE}" \
    --build-arg IMAGE_DESCRIPTION="${IMAGE_DESCRIPTION}" \
    --build-arg IMAGE_AUTHORS="${IMAGE_AUTHORS}" \
    --build-arg IMAGE_VENDOR="${IMAGE_VENDOR}" \
    --build-arg IMAGE_OWNER="${IMAGE_OWNER}" \
    --build-arg IMAGE_SOURCE="${IMAGE_SOURCE}" \
    --build-arg IMAGE_REPOSITORY="${IMAGE_REPOSITORY}:${TAG}" \
    --build-arg IMAGE_URL="${IMAGE_URL}" \
    --build-arg IMAGE_DOCUMENTATION="${IMAGE_DOCUMENTATION}" \
    --build-arg IMAGE_REVISION="${IMAGE_REVISION}" \
    --build-arg IMAGE_CREATED="${IMAGE_CREATED}" \
    --build-arg IMAGE_LICENSES="${IMAGE_LICENSES}" \
    --annotation "org.opencontainers.image.title=${IMAGE_TITLE}" \
    --annotation "org.opencontainers.image.description=${IMAGE_DESCRIPTION}" \
    --annotation "org.opencontainers.image.authors=${IMAGE_AUTHORS}" \
    --annotation "org.opencontainers.image.vendor=${IMAGE_VENDOR}" \
    --annotation "org.opencontainers.image.source=${IMAGE_SOURCE}" \
    --annotation "org.opencontainers.image.url=${IMAGE_URL}" \
    --annotation "org.opencontainers.image.documentation=${IMAGE_DOCUMENTATION}" \
    --annotation "org.opencontainers.image.revision=${IMAGE_REVISION}" \
    --annotation "org.opencontainers.image.created=${IMAGE_CREATED}" \
    --annotation "org.opencontainers.image.licenses=${IMAGE_LICENSES}" \
    --annotation "org.opencontainers.image.base.name=${BASE}" \
    --annotation "org.opencontainers.image.version=${PG_VERSION}" \
    --annotation "org.opencontainers.image.ref.name=${IMAGE_REPOSITORY}:${TAG}" \
    --annotation "org.opencontainers.image.component.postgresql.version=${PG_VERSION}" \
    --annotation "org.opencontainers.image.component.pg_cron.version=${PG_CRON_VERSION}" \
    --annotation "org.opencontainers.image.component.pg_cron.revision=${PG_CRON_COMMIT}" \
    --annotation "org.opencontainers.image.component.pgvector.version=${PGVECTOR_VERSION}" \
    --annotation "org.opencontainers.image.component.pgvector.revision=${PGVECTOR_COMMIT}" \
    --annotation "org.opencontainers.image.component.pgaudit.version=${PGAUDIT_VERSION}" \
    --annotation "org.opencontainers.image.component.pgaudit.revision=${PGAUDIT_COMMIT}" \
    --platform=linux/amd64 \
    -f photon.dockerfile \
    -t "${IMAGE_REPOSITORY}:${TAG}"

podman push "${IMAGE_REPOSITORY}:${TAG}"
popd
