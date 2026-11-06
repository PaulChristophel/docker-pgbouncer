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
- AlmaLinux Kitten 10 minimal (`alma10`);
- openSUSE Tumbleweed (`tumbleweed`).

`images.json` is the source of truth for the PgBouncer version, source commit,
archive checksum, release channel, distribution base images, and image variants.
Multiple variants can reference the same Dockerfile with different distribution
records; for example, all Fedora releases use `fedora.dockerfile`.

## Build configuration

PgBouncer is built with Meson and the following features:

- c-ares asynchronous DNS support;
- LDAP authentication support;
- OpenSSL TLS support.

Installed PgBouncer binaries are stripped to reduce runtime size.

PAM and systemd integration are disabled. LDAP support makes PgBouncer's
global `auth_type = ldap` setting available; LDAP server and bind settings
still belong in the deployed PgBouncer configuration. See the
[upstream PgBouncer documentation](https://github.com/pgbouncer/pgbouncer) for
the available build and authentication options.

The current source is pinned to the PgBouncer 1.26.1 release-tag commit
`f03e9bf263d7ccd5d1d152a61811bf3258dd6b87` (`pgbouncer_1_26_1`). This release
includes the Meson build. The repository downloads the exact commit archive
and verifies it with the SHA-256 value in `images.json`.

## Runtime contract

All variants use the same CloudNativePG-compatible layout:

- PgBouncer runs as UID `998` and GID `996`;
- configuration is read from `/etc/pgbouncer/pgbouncer.ini`;
- the Unix socket directory is `/var/run/pgbouncer`;
- logs can be written under `/var/log/pgbouncer`;
- port `6432` is exposed;
- `/entrypoint.sh` starts `/usr/bin/pgbouncer` with the configured INI file.

PostgreSQL packages and client tools (`psql` and `pg_isready`) are deliberately
omitted. The entrypoint does not use them. CloudNativePG starts
`/usr/bin/pgbouncer` through its injected manager and uses a TCP readiness
probe; its pooler does not require a local PostgreSQL client. Use a separate
PostgreSQL client container for interactive SQL and connectivity diagnostics.
Custom exec probes or operational scripts that invoke these tools must be
adapted before adopting these images.

The reviewed operator code defines the
[manager command and TCP probe](https://github.com/cloudnative-pg/cloudnative-pg/blob/99e9645df04425d3e6c3c34ea58c53ff022b02ec/pkg/specs/pgbouncer/deployments.go),
[PgBouncer process startup](https://github.com/cloudnative-pg/cloudnative-pg/blob/99e9645df04425d3e6c3c34ea58c53ff022b02ec/internal/cmd/manager/pgbouncer/run/cmd.go),
and [in-process SQL monitoring](https://github.com/cloudnative-pg/cloudnative-pg/blob/99e9645df04425d3e6c3c34ea58c53ff022b02ec/pkg/management/pgbouncer/metricsserver/pgbouncer_collector.go).

Runtime packages retain CA certificates, c-ares, libevent, LDAP and OpenSSL
libraries, timezone data, and the shell/account utilities used to assemble
the image. Weak dependencies/recommended packages are already disabled where
supported by the existing package installation commands. Further pruning of
libraries, timezone data, or account utilities requires additional testing.

## Tags

Each OS receives full-version and release-series tags:

```text
1.26.1-fedora44
1.26-fedora44
1.26.1-fedora45
1.26-fedora45
1.26.1-fedora46
1.26-fedora46
1.26.1-photon5
1.26-photon5
1.26.1-rocky10
1.26-rocky10
1.26.1-alma10
1.26-alma10
1.26.1-tumbleweed
1.26-tumbleweed
```

The Fedora variant also receives the unsuffixed `1.26.1`, `1.26`, and `latest`
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
    image: docker.io/pcm0/pgbouncer:1.26.1-fedora44
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

The daily **Update base-image pins** workflow (07:03 UTC) opens or refreshes a
pull request when a configured runtime or builder base-image tag moves. It
updates only `images.json`; PgBouncer versions, commits, and source checksums
stay unchanged. Tumbleweed's date changes only when its base digest changes.
The updater validates full SHA-256 digests and writes the manifest only after
all registry lookups succeed.

PR creation uses `github-actions[bot]`. Approval and squash auto-merge use the
`PR_APPROVER_TOKEN` Actions secret, matching docker-postgresql. Configure a
fine-grained token from an account allowed to approve and merge, scoped to this
repository with Contents and Pull requests read/write permissions. Allow Actions
to create PRs and enable auto-merge in the repository settings. Repository-required
checks and reviews still apply; where GitHub rejects deferred auto-merge because
no branch rules exist, the workflow falls back to a normal squash merge with
an expected-head check. A token-authenticated merge triggers publishing.

For a read-only check, run `python3 scripts/update_image_pins.py --check`.
Exit codes are 0 for current pins, 1 for available updates, and 2 for errors.
Omit `--check` to write updates. Docker Buildx is not required by this updater.

To add an OS release, add a record under `distributions` and a reference under
`variants`; no Dockerfile change is needed when its package contract is
compatible. The `commit` is a Git revision; the `sha256` is the digest of the
downloaded source archive.

## Verification status

Prior to the 1.26.1 update, Fedora 44, Fedora 45, Fedora 46, Photon, Rocky Linux,
and openSUSE Tumbleweed images were built locally with Podman and checked for the expected
PgBouncer version, c-ares, OpenSSL, LDAP linkage, PostgreSQL client, and runtime
UID/GID. LDAP authentication against a live directory is deployment-specific
and is not exercised by the image build.

Every current Dockerfile also runs `pgbouncer --version` as the final runtime
user after copying into the scratch image, and checks that `psql` and
`pg_isready` are absent. This catches missing loader/shared-library dependencies
in the final filesystem; it does not establish live CloudNativePG integration.
