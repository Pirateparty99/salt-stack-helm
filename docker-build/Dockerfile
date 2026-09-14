# syntax=docker/dockerfile:1
#
# Salt master image, built from the official Salt Project packages.
#
# Exists because there is no current upstream container: docker.io/saltstack/salt
# stops at 3006.5 (Feb 2024) while Salt is at 3008.x. The official image build
# (gitlab.com/saltstack/open/saltdocker, cicd/docker/alpine.Dockerfile) is pinned
# to python:3.7-alpine, and Python 3.7 went end-of-life in June 2023, which is
# why that line stalled.
#
# Packages, not pip: Salt publishes an sdist only, so pip would rebuild Salt and
# its dependencies locally. The apt repo carries the same binaries the Salt
# Project ships to servers - onedir packages with their own bundled Python - so
# the container runs the build Salt actually tests and supports.
#
# Build:
#   docker build -t ghcr.io/<owner>/salt:3008.2 --build-arg SALT_VERSION=3008.2 .

FROM debian:bookworm-slim

# Any version in the repo. 3008.2 is current; 3006.x is the older maintained
# line. Check what is available:
#   curl -s https://packages.broadcom.com/artifactory/saltproject-deb/dists/stable/main/binary-amd64/Packages.gz \
#     | gunzip | awk '/^Package: salt-master$/{p=1} p&&/^Version:/{print $2;p=0}'
ARG SALT_VERSION=3008.2

LABEL org.opencontainers.image.title="salt-master" \
      org.opencontainers.image.description="Salt master from the official packages, built for Kubernetes and OpenShift" \
      org.opencontainers.image.version="${SALT_VERSION}" \
      org.opencontainers.image.source="https://github.com/Pirateparty99/salt-stack-helm" \
      org.opencontainers.image.licenses="Apache-2.0"

# tini reaps zombies and forwards signals, so the master stops promptly rather
# than waiting out the termination grace period. git is for gitfs backends, and
# openssh-client so those can be ssh remotes. salt-ssh is a separate package and
# is deliberately not installed.
#
# curl and gnupg are only needed to add the repo, so they are removed in the
# same layer - leaving them would keep them in the image regardless of a later
# uninstall.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        tini \
        git \
        openssh-client; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public \
        -o /etc/apt/keyrings/salt-archive-keyring.pgp; \
    curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources \
        -o /etc/apt/sources.list.d/salt.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "salt-master=${SALT_VERSION}" \
        "salt-api=${SALT_VERSION}"; \
    salt-master --version; \
    apt-get purge -y --auto-remove curl gnupg; \
    rm -rf /var/lib/apt/lists/*

# The packages create their own salt user, whose uid is not guaranteed. What
# matters for OpenShift is the group: it runs containers as an arbitrary UID
# from the namespace range with gid 0 in the supplementary groups, so every path
# Salt writes is group-owned by root with group permissions mirroring user
# permissions. An image only its own uid can write fails under restricted-v2.
RUN set -eux; \
    mkdir -p /etc/salt/pki /etc/salt/master.d /srv/salt /srv/pillar \
             /var/cache/salt /var/log/salt /var/run/salt; \
    chown -R 0:0 /etc/salt /srv/salt /srv/pillar \
                 /var/cache/salt /var/log/salt /var/run/salt; \
    chmod -R g=u /etc/salt /srv/salt /srv/pillar \
                 /var/cache/salt /var/log/salt /var/run/salt

# 4505 publish, 4506 return, 8000 salt-api.
EXPOSE 4505 4506 8000

# Non-root by default. OpenShift replaces this with a UID from the namespace
# range, which the group permissions above accommodate. On plain Kubernetes the
# uid is arbitrary but stable, and gid 0 keeps the same paths writable.
USER 1000:0

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["salt-master", "--log-level=info"]
