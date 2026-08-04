# PostgreSQL images for CloudNativePG

This repository builds PostgreSQL from upstream source for use with
[CloudNativePG](https://cloudnative-pg.io/). The same PostgreSQL release is
built on several maintained Linux distributions, providing a practical range
of compiler and system-library versions without relying on Linux releases that
are already near the end of their support life.

Published images are available from
[`docker.io/pcm0/postgres`](https://hub.docker.com/r/pcm0/postgres).

## Motivation

The primary goal is to build and test PostgreSQL with a diverse set of GCC
toolchains while keeping every resulting image on an operating system that can
reasonably be maintained.

One way to obtain different GCC versions would be to use consecutive Fedora
releases—for example, Fedora 44 and Fedora 43. That creates unnecessary
maintenance churn: the older Fedora release reaches end of service sooner, so
the image must be rebased simply to retain operating-system support. Using
current releases from different distribution families provides compiler,
library, and packaging diversity while giving the longer-lived distributions
useful maintenance horizons.

The current bases are:

- Fedora 44, representing a fast-moving distribution and newer toolchain.
- Rocky Linux 10, representing an enterprise Linux toolchain and lifecycle.
- Photon OS 5, representing VMware's compact, container-oriented distribution.

This is useful both for finding compiler-sensitive PostgreSQL problems and for
offering operators a choice of supported base environments. It is not intended
to make the three images byte-for-byte identical; the common contract is the
PostgreSQL feature set and CloudNativePG compatibility.

## Image matrix

The release workflow builds each configured PostgreSQL version for all three
operating systems:

- PostgreSQL 14 through 18 are published through the stable catalogs.
- PostgreSQL 19 prereleases are published through separate preview catalogs.
- Each OS has a standard variant and a corresponding `-untrusted` variant.
- Images currently target `linux/amd64`.

`images.json` is the source of truth for PostgreSQL versions, source checksums,
extension revisions, image variants, and stable or preview channel assignment.

## Included features

PostgreSQL is compiled from the official upstream source archive rather than
installed from a distribution PostgreSQL package. Every build runs the
PostgreSQL `check-world` test suite and an image-level smoke test.

The images include the capabilities expected from a CloudNativePG standard
image, including:

- ICU, LDAP, GSSAPI, PAM, OpenSSL, XML, XSLT, LLVM, LZ4, Zstandard, and
  `uuid-ossp` support;
- `pg_cron`;
- `pgvector`;
- `pgaudit`;
- the full set of PostgreSQL programs installed by `install-world-bin`.

PostgreSQL 18 and later are additionally built with the supported libcurl
integration. Linux distributions that package it also enable liburing.

The default variants deliberately omit the Perl, Python, and Tcl runtimes and
their untrusted procedural languages. Tags ending in `-untrusted` add
`plperl`, `plpython3u`, and `pltcl` for workloads that require them.

## Tags

Tags combine a PostgreSQL version with the image variant. For example:

```text
18.4-standard-photon5
18-standard-fedora44
18-standard-rocky10-untrusted
```

Full-version tags identify a particular PostgreSQL release. Major-version tags
move when a new minor release is published. The `latest` tag follows the
current PostgreSQL 18 Photon OS standard image.

For production deployments, prefer the immutable digests recorded in the
CloudNativePG catalogs under `image-catalogs/`.

## Using a catalog with CloudNativePG

Apply the catalog for the desired OS and trust profile:

```sh
/opt/homebrew/bin/kubectl apply \
  -f image-catalogs/catalog-standard-photon5.yaml
```

Reference it from a CloudNativePG cluster by catalog name and PostgreSQL major
version:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
spec:
  instances: 3
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    major: 18
    name: postgresql-standard-photon5
```

Preview catalogs have names ending in `-preview` and should be treated as
preproduction images.

## Building locally

The Dockerfiles accept the same build arguments used by the release workflow.
For a quick build using a Dockerfile's current PostgreSQL defaults:

```sh
/opt/homebrew/bin/podman build \
  --platform linux/amd64 \
  -f photon.dockerfile \
  -t localhost/postgres:standard-photon5 .
```

`photon.sh` provides a local Photon build-and-push example with all source
versions, checksums, and OCI metadata supplied explicitly.

## Release process

The GitHub Actions release workflow expands `images.json` into a PostgreSQL ×
image-variant build matrix. It builds and publishes every image, records the
registry digest, creates a provenance attestation, and regenerates the
CloudNativePG catalogs with immutable image references.

Base images and downloaded source archives are digest- or checksum-pinned.
Updating a PostgreSQL release, extension revision, or image variant should
therefore begin in `images.json`; base-image updates belong in the relevant
Dockerfile.
