# syntax=docker/dockerfile:1
#
# SaltGUI - a web interface for Salt, served by salt-api.
#
# SaltGUI is a static site that talks to salt-api; it implements no
# authentication of its own. The login form sends a username, password and
# eauth type to salt-api, which does the actual authentication - so with
# `external_auth: ldap` on the master it authenticates against AD.
#
# It is served BY salt-api rather than by a web server of its own: salt-api's
# rest_cherrypy can serve static files (app/static/static_path), and going
# through the same origin avoids CORS entirely.
#
# This image is not run as a service. It carries the files, and the chart uses
# it as an init container that copies them into a volume the salt-api container
# reads. That keeps the hardened salt image free of web assets.
#
# Build:
#   docker build -t <repo>/saltgui:1.34.0 --build-arg SALTGUI_VERSION=1.34.0 .

ARG UBI_VERSION=10.2

# ------------------------------------------------------------------ fetcher
# curl and tar live only here. Uninstalling them from the final image instead
# would be both fragile - removing packages from a minimal base drags
# dependencies with them - and pointless, since a discarded stage leaves
# nothing behind either way.
FROM registry.access.redhat.com/ubi10-minimal:${UBI_VERSION} AS fetch

# Any tag from https://github.com/erwindon/SaltGUI/tags
ARG SALTGUI_VERSION=1.34.0

RUN set -eux; \
    # Installed explicitly rather than assumed: ubi-minimal's contents are not
    # a stable interface. The salt image's fetch stage does the same and builds
    # cleanly, so this is not where the previous failure was.
    microdnf install -y --setopt=install_weak_deps=0 --nodocs curl tar gzip; \
    curl -fsSL -o /tmp/saltgui.tar.gz \
      "https://github.com/erwindon/SaltGUI/archive/refs/tags/${SALTGUI_VERSION}.tar.gz"; \
    mkdir -p /saltgui; \
    # Only the saltgui/ directory is the served site - the rest of the tarball
    # is tests, tooling and docs.
    tar -xzf /tmp/saltgui.tar.gz -C /saltgui --strip-components=2 \
        "SaltGUI-${SALTGUI_VERSION}/saltgui"; \
    test -f /saltgui/index.html; \
    test -d /saltgui/static

# ------------------------------------------------------------------ runtime
FROM registry.access.redhat.com/ubi10-minimal:${UBI_VERSION}

ARG SALTGUI_VERSION=1.34.0

LABEL org.opencontainers.image.title="saltgui" \
      org.opencontainers.image.description="SaltGUI static assets, served by salt-api" \
      org.opencontainers.image.version="${SALTGUI_VERSION}" \
      org.opencontainers.image.source="https://github.com/Pirateparty99/salt-stack-helm" \
      org.opencontainers.image.url="https://github.com/erwindon/SaltGUI" \
      org.opencontainers.image.licenses="MIT"

# Group root with group permissions mirroring user permissions: the init
# container that copies these out runs as an arbitrary UID under OpenShift.
COPY --from=fetch --chown=0:0 --chmod=g=u /saltgui /saltgui

USER 1000:0

# Never run as a service - the chart copies these out in an init container.
CMD ["/bin/false"]
