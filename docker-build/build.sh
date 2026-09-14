#!/bin/bash
#
# build.sh - build and optionally push the Salt master image locally.
#
# CI does this on every change to docker-build/ (see
# .github/workflows/docker-publish.yml); this is for building by hand.
#
# Usage:
#   docker-build/build.sh                        # build 3008.2 for this arch
#   docker-build/build.sh 3006.27                # build a specific version
#   PUSH=1 docker-build/build.sh                 # build and push
#   PUSH=1 MULTIARCH=1 docker-build/build.sh     # amd64 + arm64, requires buildx
#
# Set REPO to your Docker Hub namespace. Log in first with `docker login`;
# this script never handles credentials.
#
set -euo pipefail

SALT_VERSION="${1:-3008.2}"
REPO="${REPO:-pirateparty99}"
IMAGE="${IMAGE:-salt}"
PUSH="${PUSH:-0}"
MULTIARCH="${MULTIARCH:-0}"

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TAG="${REPO}/${IMAGE}:${SALT_VERSION}"

command -v docker >/dev/null || { echo "docker not found in PATH" >&2; exit 1; }
docker info >/dev/null 2>&1 || {
  echo "cannot reach the docker daemon." >&2
  echo "  If this is a permission error, add yourself to the docker group:" >&2
  echo "    sudo usermod -aG docker \$USER      # then start a new login session" >&2
  exit 1
}

# The repo serves both architectures, so a multi-arch build is possible - but it
# needs buildx and can only push, not load, a multi-platform result.
if (( MULTIARCH )); then
  [[ "$PUSH" == "1" ]] || { echo "MULTIARCH requires PUSH=1: a multi-platform image cannot be loaded into the local daemon" >&2; exit 1; }
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --build-arg "SALT_VERSION=${SALT_VERSION}" \
    --tag "$TAG" --tag "${REPO}/${IMAGE}:latest" \
    --push "$HERE"
  echo "pushed $TAG (amd64, arm64)"
  exit 0
fi

docker build \
  --build-arg "SALT_VERSION=${SALT_VERSION}" \
  --tag "$TAG" --tag "${REPO}/${IMAGE}:latest" \
  "$HERE"
echo "built $TAG"

# Cheap proof the image is not merely well-formed: ask the master its version.
echo "--- salt-master --version ---"
docker run --rm "$TAG" salt-master --version

if [[ "$PUSH" == "1" ]]; then
  docker push "$TAG"
  docker push "${REPO}/${IMAGE}:latest"
  echo "pushed $TAG"
fi
