# syntax=docker/dockerfile:1
#
# Salt master on Red Hat UBI 10, from the official Salt Project packages.
#
# Why this image exists: there is no current upstream Salt container.
# docker.io/saltstack/salt stops at 3006.5 (Feb 2024) while Salt is at 3008.x.
# The official build (gitlab.com/saltstack/open/saltdocker) is pinned to
# python:3.7-alpine, and Python 3.7 went end-of-life in June 2023.
#
# Packages, not pip: PyPI carries an sdist only, so pip would rebuild Salt and
# its dependencies locally. The Salt RPM repo is flat and distro-agnostic -
# these are onedir builds with their own bundled Python, so they do not depend
# on the base image's Python and install cleanly on UBI.
#
# Hardening, in the order it appears below:
#   - UBI minimal base, no weak dependencies, no documentation
#   - package signatures verified against the Salt Project GPG key (gpgcheck=1)
#   - tini pinned by version and verified by SHA-256 before it is trusted
#   - every setuid/setgid bit cleared: nothing in here needs to escalate
#   - package manager caches and the repo definition removed after install
#   - runs as a non-root uid, group root, with only its own paths writable
#   - no shell entrypoint, no build tools, no curl left in the final image
#
# Build:
#   docker build -t <repo>/salt:3008.2 --build-arg SALT_VERSION=3008.2 .

ARG UBI_VERSION=10.2
ARG SALT_VERSION=3008.2
ARG TINI_VERSION=v0.19.0

# --------------------------------------------------------------- tini fetcher
# Separate stage so curl and the checksum files never reach the final image.
FROM registry.access.redhat.com/ubi10-minimal:${UBI_VERSION} AS tini

ARG TINI_VERSION
# Provided by BuildKit; amd64/arm64 match tini's asset names directly.
ARG TARGETARCH

# Installed explicitly rather than assumed: ubi-minimal's contents are not a
# stable interface, and a missing curl would fail deep in the build.
RUN set -eux; \
    microdnf install -y --setopt=install_weak_deps=0 --nodocs curl coreutils-single; \
    curl -fsSL -o /tini \
      "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH}"; \
    curl -fsSL -o /tini.sha256sum \
      "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH}.sha256sum"; \
    # The published sum names the release asset; point it at the downloaded file.
    echo "$(cut -d' ' -f1 /tini.sha256sum)  /tini" | sha256sum -c -; \
    chmod 0755 /tini

# ----------------------------------------------------------------- pythonldap
# Salt's LDAP eauth needs the python-ldap module, which the onedir packages do
# not bundle - without it every LDAP login fails with "LDAP authentication
# requires python-ldap module" and nothing else. It is published as an sdist
# only, so it compiles against OpenLDAP here and the toolchain stays in this
# stage. salt-pip installs into /opt/saltstack/salt/extras-3.14, a directory
# Salt puts on its own path, so the result is one self-contained tree to copy.
FROM registry.access.redhat.com/ubi10-minimal:${UBI_VERSION} AS pythonldap

ARG SALT_VERSION

RUN set -eux; \
    rpm --import https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public; \
    printf '%s\n' \
      '[salt]' \
      'name=Salt Project' \
      'baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/' \
      'enabled=1' \
      'gpgcheck=1' \
      'gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public' \
      > /etc/yum.repos.d/salt.repo; \
    microdnf install -y --setopt=install_weak_deps=0 --nodocs \
        "salt-master-${SALT_VERSION}" \
        gcc \
        openldap-devel \
        cyrus-sasl-devel \
        openssl-devel; \
    salt-pip install --no-cache-dir python-ldap; \
    # Prove it imports here rather than discovering it at login time.
    /opt/saltstack/salt/bin/python3 -c 'import ldap; print(ldap.__version__)'

# ---------------------------------------------------------------------- salt
FROM registry.access.redhat.com/ubi10-minimal:${UBI_VERSION}

ARG SALT_VERSION

LABEL org.opencontainers.image.title="salt-master" \
      org.opencontainers.image.description="Salt master on UBI 10, from the official Salt packages" \
      org.opencontainers.image.version="${SALT_VERSION}" \
      org.opencontainers.image.source="https://github.com/Pirateparty99/salt-stack-helm" \
      org.opencontainers.image.base.name="registry.access.redhat.com/ubi10-minimal" \
      org.opencontainers.image.licenses="Apache-2.0"

# The Salt RPM repo is flat - one baseurl for every distribution, because the
# onedir packages bundle their own Python. gpgcheck is on and the key is
# imported first, so an unsigned or tampered package fails the build.
RUN set -eux; \
    rpm --import https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public; \
    printf '%s\n' \
      '[salt]' \
      'name=Salt Project' \
      'baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/' \
      'enabled=1' \
      'gpgcheck=1' \
      'gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public' \
      > /etc/yum.repos.d/salt.repo; \
    microdnf install -y --setopt=install_weak_deps=0 --nodocs \
        "salt-master-${SALT_VERSION}" \
        "salt-api-${SALT_VERSION}" \
        git-core \
        openssh-clients \
        openldap; \
    salt-master --version; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /etc/yum.repos.d/salt.repo

COPY --from=tini /tini /usr/bin/tini

# python-ldap, built in the stage above. Salt reads this directory itself, so
# nothing needs to be added to PYTHONPATH.
# Copied by glob rather than by exact name: the directory is named for the
# bundled Python, so pinning extras-3.14 would silently stop matching the day
# Salt moves to 3.15 - and a COPY that matches nothing does not fail.
COPY --from=pythonldap /opt/saltstack/salt/extras-3.*/ /opt/saltstack/salt/extras-python/

# Salt needs none of these to run a master, and a container that cannot
# escalate privileges is one less thing to reason about.
RUN set -eux; \
    find / -xdev -perm /6000 -type f -exec chmod -s {} + 2>/dev/null || true; \
    find / -xdev -perm /6000 -type f -print | grep . && exit 1 || true

# Group-owned by root with group permissions mirroring user permissions:
# OpenShift runs containers as an arbitrary UID from the namespace range with
# gid 0 in the supplementary groups, so an image only its own uid can write
# fails under restricted-v2. Nothing else in the filesystem is made writable.
RUN set -eux; \
    mkdir -p /etc/salt/pki /etc/salt/master.d /srv/salt /srv/pillar \
             /var/cache/salt /var/log/salt /var/run/salt; \
    chown -R 0:0 /etc/salt /srv/salt /srv/pillar \
                 /var/cache/salt /var/log/salt /var/run/salt; \
    chmod -R g=u /etc/salt /srv/salt /srv/pillar \
                 /var/cache/salt /var/log/salt /var/run/salt

# The module is only useful if Salt itself can import it - checked here so a
# broken copy fails the build rather than surfacing as a failed login.
# Put the copied tree where the bundled Python actually looks, then prove Salt
# can import it - a broken copy should fail the build, not a login.
RUN set -eux; \
    extras="$(ls -d /opt/saltstack/salt/extras-3.* | head -1)"; \
    cp -r /opt/saltstack/salt/extras-python/. "$extras/"; \
    rm -rf /opt/saltstack/salt/extras-python; \
    /opt/saltstack/salt/bin/python3 -c 'import ldap; print("python-ldap", ldap.__version__)'

# 4505 publish, 4506 return, 8000 salt-api.
EXPOSE 4505 4506 8000

USER 1000:0

STOPSIGNAL SIGTERM

# tini reaps the workers salt-master forks and forwards signals, so the pod
# stops promptly instead of waiting out its termination grace period.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["salt-master", "--log-level=info"]
