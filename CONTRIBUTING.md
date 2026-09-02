# Contributing

Contributions that improve the PgBouncer builds, supported distributions,
documentation, or release automation are welcome.

## Before making a change

Open an issue for changes that alter the supported PgBouncer versions, image
variants, or release behavior. Bug fixes and focused documentation
improvements can go directly to a pull request.

Keep changes scoped to this repository's purpose: building PgBouncer images
for CloudNativePG from upstream source. The standard variants are intended to
provide the core PgBouncer runtime and should stay aligned with the
repository's supported image contract.

## Repository layout

- `images.json` is the source of truth for PgBouncer releases, source
  checksums, distribution base images, build variants, and release channels.
- `photon.dockerfile`, `fedora.dockerfile`, `rockylinux.dockerfile`,
  `almalinux.dockerfile`, and `tumbleweed.dockerfile` define the
  distribution-family-specific builds.
- `.github/workflows/release.yml` builds and publishes the complete matrix.

When adding or updating downloaded source, pin both its immutable revision and
its SHA-256 checksum. Base images should remain digest-pinned.

## Local validation

Build the affected variant with Podman. The Dockerfiles' defaults are suitable
for a quick validation build:

```sh
/opt/homebrew/bin/podman build \
  --platform linux/amd64 \
  -f photon.dockerfile \
  -t localhost/pgbouncer:standard-photon5 .
```

Use the relevant Dockerfile and tag for Fedora or Rocky Linux changes.

Every Dockerfile builds the PgBouncer binary and runs an image-level smoke
test before producing the final image. A successful complete build is
therefore the primary validation for Dockerfile or dependency changes.

Also check configuration syntax and whitespace before submitting:

```sh
/opt/homebrew/bin/python3.14 -m json.tool images.json >/dev/null
/opt/homebrew/bin/git diff --check
```

Do not hand-edit generated catalogs when changing a build. The release workflow
records the registry digests, regenerates the catalogs, and opens the catalog
update pull request after all matrix builds succeed.

## Pull requests

In the pull request description:

- explain the problem and the intended behavior;
- identify the PgBouncer versions and OS variants affected;
- list the validation commands run and their results; and
- call out anything that could not be tested locally.

Keep unrelated changes in separate pull requests. A pull request that changes
the common image contract should update every affected distribution rather
than leaving variants with different PgBouncer features unintentionally.

By contributing, you agree that your contribution is licensed under the terms
of this repository's [LICENSE](LICENSE).
