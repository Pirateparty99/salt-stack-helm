# syntax=docker/dockerfile:1
#
# Salt master image.
#
# Exists because there is no current upstream one: docker.io/saltstack/salt
# stops at 3006.5 (Feb 2024) while Salt is at 3008.x. The official build
# (gitlab.com/saltstack/open/saltdocker, cicd/docker/alpine.Dockerfile) is
# pinned to python:3.7-alpine, and Python 3.7 went end-of-life in June 2023,
# which is why that line stalled.
#
# Differences from the official build, and why:
#
#   Debian slim, not Alpine. Salt ships an sdist only - no wheels - so pip
#   builds it and its dependencies. On musl, pyzmq/cryptography/cffi have no
#   matching wheels and compile from source; on glibc they resolve to manylinux
#   wheels. Same result, far less build.
#
#   Files are group-owned by root (gid 0) and group-writable, not owned by a
#   fixed uid. OpenShift runs containers as an arbitrary UID from the namespace
#   range with gid 0 in the supplementary groups, so a fixed-uid image cannot
#   write its own directories there. This is the documented way to build an
#   image that works under restricted-v2 without an SCC exception.
#
#   One process per container. The official image's saltinit runs salt-master
#   and salt-api together under an asyncio supervisor. Here salt-master is the
#   command and salt-api is the same image with a different command, so the
#   kubelet supervises each and probes mean what they say.
#
# Build:
#   docker build -t ghcr.io/<owner>/salt:3008.2 --build-arg SALT_VERSION=3008.2 .

ARG PYTHON_VERSION=3.12

# ----------------------------------------------------------------- builder
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

ARG SALT_VERSION=3008.2

# Build deps only - they do not reach the runtime image.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# A venv keeps Salt and its dependencies in one directory that can be copied
# wholesale, so the runtime image never sees a compiler.
RUN python -m venv /opt/salt
ENV PATH="/opt/salt/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir "salt==${SALT_VERSION}"

# ----------------------------------------------------------------- runtime
FROM python:${PYTHON_VERSION}-slim-bookworm

ARG SALT_VERSION=3008.2

LABEL org.opencontainers.image.title="salt-master" \
      org.opencontainers.image.description="Salt master, built for Kubernetes and OpenShift" \
      org.opencontainers.image.version="${SALT_VERSION}" \
      org.opencontainers.image.source="https://github.com/Pirateparty99/salt-stack-helm" \
      org.opencontainers.image.licenses="Apache-2.0"

# tini reaps zombies and forwards signals, so salt-master stops promptly instead
# of waiting out the termination grace period. git is here for gitfs backends.
RUN apt-get update && apt-get install -y --no-install-recommends \
        tini \
        git \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/salt /opt/salt
ENV PATH="/opt/salt/bin:$PATH" \
    PYTHONUNBUFFERED=1

# uid 450 matches the official image's salt user, so a volume written by one is
# readable by the other. Group is root (0) with group perms mirroring user
# perms: that is what lets an arbitrary OpenShift UID write these paths.
RUN groupadd -r -g 450 salt \
    && useradd -r -u 450 -g salt -d /srv/salt -s /usr/sbin/nologin salt \
    && mkdir -p /etc/salt/pki /etc/salt/master.d /srv/salt /srv/pillar \
                /var/cache/salt /var/log/salt /var/run/salt \
    && chown -R 450:0 /etc/salt /srv/salt /srv/pillar \
                      /var/cache/salt /var/log/salt /var/run/salt \
    && chmod -R g=u /etc/salt /srv/salt /srv/pillar \
                    /var/cache/salt /var/log/salt /var/run/salt

# 4505 publish, 4506 return, 8000 salt-api.
EXPOSE 4505 4506 8000

# Declared so the image is non-root by default. OpenShift replaces it with a
# UID from the namespace range, which the group permissions above accommodate.
USER 450

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["salt-master", "--log-level=info"]
