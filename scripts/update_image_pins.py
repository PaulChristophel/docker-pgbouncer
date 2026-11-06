#!/usr/bin/env python3
"""Refresh runtime and builder base-image digest pins in images.json."""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

USER_AGENT = "docker-pgbouncer-images-updater/1.0"
MANIFEST_ACCEPT = (
    "application/vnd.oci.image.index.v1+json,"
    "application/vnd.docker.distribution.manifest.list.v2+json,"
    "application/vnd.oci.image.manifest.v1+json,"
    "application/vnd.docker.distribution.manifest.v2+json"
)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments.

    Returns:
        Parsed command-line arguments.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("images.json"))
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit nonzero when an update is available without writing the file.",
    )
    return parser.parse_args()


def fetch_text(url: str, headers: dict[str, str] | None = None) -> str:
    """Fetch UTF-8 text from an official PgBouncer download endpoint.

    Args:
        url: HTTPS URL to retrieve.
        headers: Optional HTTP headers to include in the request.

    Returns:
        Decoded response body.

    Raises:
        RuntimeError: If the endpoint cannot be retrieved or decoded.
    """
    request_headers = {"User-Agent": USER_AGENT, **(headers or {})}
    request = Request(url, headers=request_headers)
    try:
        with urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8")
    except (HTTPError, URLError, UnicodeDecodeError) as error:
        raise RuntimeError(f"Unable to fetch {url}: {error}") from error


def fetch_response(
    url: str, headers: dict[str, str] | None = None
) -> tuple[str, dict[str, str]]:
    """Fetch a response body and normalized headers.

    Args:
        url: HTTPS URL to retrieve.
        headers: Optional HTTP headers to include in the request.

    Returns:
        The decoded response body and lowercase response headers.

    Raises:
        RuntimeError: If the endpoint cannot be retrieved or decoded.
    """
    request_headers = {"User-Agent": USER_AGENT, **(headers or {})}
    request = Request(url, headers=request_headers)
    try:
        with urlopen(request, timeout=30) as response:
            return (
                response.read().decode("utf-8"),
                {key.lower(): value for key, value in response.headers.items()},
            )
    except (HTTPError, URLError, UnicodeDecodeError) as error:
        raise RuntimeError(f"Unable to fetch {url}: {error}") from error


def parse_image_reference(reference: str) -> tuple[str, str, str]:
    """Split a digest-pinned image reference into registry, repository, and tag.

    Args:
        reference: An OCI reference containing a tag and SHA-256 digest.

    Returns:
        Registry host, repository path, and tag.

    Raises:
        RuntimeError: If the reference is not safely digest-pinned.
    """
    name, separator, digest = reference.partition("@sha256:")
    if not separator or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise RuntimeError(f"Base image is not SHA-256 pinned: {reference}")
    registry, _, repository_and_tag = name.partition("/")
    if not repository_and_tag or ":" not in repository_and_tag:
        raise RuntimeError(
            f"Base image is missing a registry, repository, or tag: {reference}"
        )
    repository, tag = repository_and_tag.rsplit(":", 1)
    if registry == "docker.io":
        registry = "registry-1.docker.io"
        if "/" not in repository:
            repository = f"library/{repository}"
    return registry, repository, tag


def bearer_token(challenge: str) -> str:
    """Exchange an OCI bearer-auth challenge for a pull token.

    Args:
        challenge: A ``WWW-Authenticate`` header from an OCI registry.

    Returns:
        Bearer token suitable for the challenged manifest request.

    Raises:
        RuntimeError: If the challenge cannot be parsed or lacks a token.
    """
    match = re.fullmatch(
        r'Bearer\s+realm="([^"]+)"(?:,service="([^"]+)")?(?:,scope="([^"]+)")?',
        challenge,
    )
    if not match:
        raise RuntimeError(f"Unsupported OCI authentication challenge: {challenge}")
    realm, service, scope = match.groups()
    query = []
    if service:
        query.append(f"service={service}")
    if scope:
        query.append(f"scope={scope}")
    payload = json.loads(fetch_text(f"{realm}?{'&'.join(query)}"))
    token = payload.get("token") or payload.get("access_token")
    if not token:
        raise RuntimeError("OCI authentication response did not contain a bearer token")
    return token


def current_base_digest(reference: str) -> str:
    """Resolve an OCI tag to the registry's current manifest SHA-256 digest.

    Args:
        reference: Existing digest-pinned OCI reference in ``images.json``.

    Returns:
        Replacement digest-pinned reference for the same registry, tag, and repository.

    Raises:
        RuntimeError: If the registry does not return a valid manifest digest.
    """
    registry, repository, tag = parse_image_reference(reference)
    url = f"https://{registry}/v2/{repository}/manifests/{tag}"
    headers = {"Accept": MANIFEST_ACCEPT}
    try:
        _, response_headers = fetch_response(url, headers)
    except RuntimeError as error:
        if not isinstance(error.__cause__, HTTPError) or error.__cause__.code != 401:
            raise
        challenge = error.__cause__.headers.get("WWW-Authenticate", "")
        _, response_headers = fetch_response(
            url, {**headers, "Authorization": f"Bearer {bearer_token(challenge)}"}
        )
    digest = response_headers.get("docker-content-digest", "")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise RuntimeError(
            f"Registry did not return a SHA-256 manifest digest for {reference}"
        )
    original_name = reference.partition("@sha256:")[0]
    return f"{original_name}@{digest}"


def update_base_images(config: dict[str, Any]) -> list[str]:
    """Resolve configured runtime and builder tags independently.

    Args:
        config: Parsed images configuration, modified in place.

    Returns:
        Descriptions of changed pins.

    Raises:
        RuntimeError: If a reference cannot be resolved to a valid SHA-256 digest.
    """
    changes = []
    for name, distribution in config["distributions"].items():
        for field in ("base", "build_base"):
            if field not in distribution:
                continue
            old = distribution[field]
            new = current_base_digest(old)
            if old == new:
                continue
            distribution[field] = new
            if name == "tumbleweed" and field == "base":
                distribution["version"] = datetime.now(timezone.utc).strftime("%Y%m%d")
            changes.append(f"{name}.{field}: {old} -> {new}")
    return changes


def main() -> int:
    """Refresh base pins without changing PgBouncer source records.

    Returns:
        Zero on success, or one when check mode detects an available update.

    Raises:
        RuntimeError: If an upstream pin cannot be resolved.
        OSError: If the configuration cannot be read or written.
        ValueError: If the configuration is invalid JSON.
        KeyError: If required configuration fields are missing.
    """
    args = parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    changes = update_base_images(config)
    if not changes:
        print("Base-image pins are already current.")
        return 0
    print("\n".join(changes))
    if args.check:
        return 1
    args.config.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(2)
