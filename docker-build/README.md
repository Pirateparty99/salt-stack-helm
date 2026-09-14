# salt-master image

There is no current upstream Salt container. `docker.io/saltstack/salt` stops at
**3006.5** (Feb 2024) while Salt is at **3008.x**. The official build lives at
[saltdocker](https://gitlab.com/saltstack/open/saltdocker) in
`cicd/docker/alpine.Dockerfile` and is pinned to `python:3.7-alpine` — Python 3.7
went end-of-life in June 2023, which is why that line stopped.

This builds a current Salt master that also runs under OpenShift.

## Build

```bash
docker build -t ghcr.io/pirateparty99/salt:3008.2 --build-arg SALT_VERSION=3008.2 docker-build
```

`SALT_VERSION` is any version the repo carries. List them:

```bash
curl -s https://packages.broadcom.com/artifactory/saltproject-deb/dists/stable/main/binary-amd64/Packages.gz \
  | gunzip | awk '/^Package: salt-master$/{p=1} p&&/^Version:/{print $2;p=0}' | sort -Vr | head
```

## Then point the chart at it

```yaml
image:
  repository: ghcr.io/pirateparty99/salt
  tag: "3008.2"
```

## Choices worth knowing

**UBI 10 minimal base.** `registry.access.redhat.com/ubi10-minimal`, which is
redistributable without a Red Hat subscription and is what OpenShift is built on.

**Official packages, not pip.** PyPI carries an sdist only, so pip would rebuild
Salt and its dependencies locally. The Salt RPM repo is flat and
distro-agnostic — onedir builds with their own bundled Python — so it installs
on UBI without depending on the base image's Python. Verified present for
x86_64 and aarch64 at 3008.2.

**Hardening, out of the box:**

| Measure | Why |
| --- | --- |
| `gpgcheck=1`, key imported first | an unsigned or tampered package fails the build |
| tini pinned and SHA-256 verified | the one binary not from a signed repo |
| all setuid/setgid bits cleared, then asserted | nothing here needs to escalate |
| no weak deps, no docs, caches and repo file removed | less to audit, less to patch |
| curl and checksums confined to a builder stage | absent from the final image |
| runs as uid 1000, group 0 | non-root, and writable under OpenShift's arbitrary UID |
| `salt-master --version` during build | a broken install fails the build, not the first deploy |

The chart matches: `readOnlyRootFilesystem`, `runAsNonRoot`, all capabilities
dropped, and `seccompProfile: RuntimeDefault`, with the paths Salt writes to
mounted as `emptyDir`.

**Group-writable, not fixed-uid.** OpenShift runs containers as an arbitrary UID
from the namespace range with gid 0 in the supplementary groups, so an image only
its own uid can write fails under `restricted-v2`.

**One process per container.** The official image's `saltinit` supervises
salt-master and salt-api together. Here salt-master is the command and salt-api
is the same image with a different command, so the kubelet supervises each and a
probe failure names the process that actually failed.

## Not yet run

The image builds in CI and pushed to Docker Hub, but it has not been started
anywhere. The read-only root filesystem in particular is untested — if the master
fails to start, that is the first thing to relax.
