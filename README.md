# PgBouncer images for CloudNativePG

This repository builds PgBouncer from upstream source for use with
[CloudNativePG](https://cloudnative-pg.io/). The images preserve the runtime
contract of the official CloudNativePG PgBouncer image while adding an
explicit, reproducible source build with c-ares, OpenSSL, and LDAP support.

Published images are available from
[`docker.io/pcm0/pgbouncer`](https://hub.docker.com/r/pcm0/pgbouncer).

## Image matrix

The release workflow currently builds PgBouncer for `linux/amd64` on:

- Fedora 44 (`fedora44`), the default variant;
- Fedora 45 (`fedora45`);
- Fedora 46 (`fedora46`);
- Photon OS 5 (`photon5`);
- Rocky Linux 10 UBI Micro (`rocky10`);
- AlmaLinux Kitten 10 minimal (`alma10`).

`images.json` is the source of truth for the PgBouncer version, source commit,
archive checksum, release channel, distribution base images, and image variants.
Multiple variants can reference the same Dockerfile with different distribution
records; for example, all Fedora releases use `fedora.dockerfile`.

## Build configuration

PgBouncer is built with Meson and the following features:

- c-ares asynchronous DNS support;
- LDAP authentication support;
- OpenSSL TLS support;
- PostgreSQL client tools for connectivity and health checks.

PAM and systemd integration are disabled. LDAP support makes PgBouncer's
global `auth_type = ldap` setting available; LDAP server and bind settings
still belong in the deployed PgBouncer configuration. See the
[upstream PgBouncer documentation](https://github.com/pgbouncer/pgbouncer) for
the available build and authentication options.

The current source is pinned to commit
`13a344f2625381296fc02e29b986a11be9c6b983`, which introduced the upstream
Meson build and reports itself as PgBouncer 1.25.2. The published 1.25.2
release archive predates Meson, so this repository uses that exact post-release
commit and verifies its archive with the SHA-256 value in `images.json`. This
pin should move back to a release tag once upstream publishes a Meson-capable
release.

## Runtime contract

All variants use the same CloudNativePG-compatible layout:

- PgBouncer runs as UID `998` and GID `996`;
- configuration is read from `/etc/pgbouncer/pgbouncer.ini`;
- the Unix socket directory is `/var/run/pgbouncer`;
- logs can be written under `/var/log/pgbouncer`;
- port `6432` is exposed;
- `/entrypoint.sh` starts `/usr/bin/pgbouncer` with the configured INI file.

## Tags

Each OS receives full-version and release-series tags:

```text
1.25.2-fedora44
1.25-fedora44
1.25.2-fedora45
1.25-fedora45
1.25.2-fedora46
1.25-fedora46
1.25.2-photon5
1.25-photon5
1.25.2-rocky10
1.25-rocky10
```

The Fedora variant also receives the unsuffixed `1.25.2`, `1.25`, and `latest`
tags. Releases additionally publish a workflow-revision-qualified tag for each
variant. Moving tags are convenient for testing, but production deployments
should pin an immutable registry digest.

## Using the image with CloudNativePG

Set the image directly on the CloudNativePG `Pooler` resource:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: example-rw
spec:
  cluster:
    name: example
  instances: 3
  type: rw
  pgbouncer:
    image: docker.io/pcm0/pgbouncer:1.25.2-fedora44
    poolMode: session
```

CloudNativePG also supports selecting a PgBouncer image through an image
catalog. Refer to the current
[CloudNativePG connection-pooling documentation](https://cloudnative-pg.io/docs/devel/connection_pooling/)
for image-selection precedence and the complete `Pooler` specification.

## Building locally

For example, build the Fedora image with Podman:

```sh
/opt/homebrew/bin/podman build \
  --platform linux/amd64 \
  -f fedora.dockerfile \
  -t localhost/pgbouncer:fedora44 .
```

Use the relevant distribution-family Dockerfile and change the local tag to
build another variant. The Dockerfiles contain usable defaults for local
builds; the release workflow supplies the pinned values from `images.json`.
To build a non-default Fedora release locally, also pass that distribution's
`base`, `build_base`, and `version` values as `BASE`, `BUILD_BASE`, and
`IMAGE_DISTRIBUTION_VERSION` build arguments.

## Release process

The GitHub Actions workflow expands the PgBouncer version and OS variants from
`images.json`, builds each image, pushes its versioned tags, and publishes
provenance attestations. It runs for changes on `master`, on a weekly schedule,
or by manual dispatch.

To update PgBouncer, change `version`, `series`, `commit`, and `sha256` in
`images.json`, then update the corresponding Dockerfile source defaults so
local and workflow-driven builds remain aligned. To add an OS release, add a
record under `distributions` and a reference under `variants`; no Dockerfile
change is needed when its package contract is compatible. The `commit` is a
Git revision; the `sha256` is the digest of the downloaded source archive.

## Verification status

Fedora 44, Fedora 45, Fedora 46, Photon, and Rocky Linux images have been built
locally with Podman and checked for the expected PgBouncer version, c-ares,
OpenSSL, LDAP linkage, PostgreSQL client, and runtime UID/GID. LDAP
authentication against a live directory is deployment-specific and is not
exercised by the image build.
