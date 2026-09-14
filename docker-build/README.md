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

**Official packages, not pip.** Salt publishes an sdist only to PyPI, so pip
would rebuild Salt and its dependencies locally. The apt repo at
`packages.broadcom.com/artifactory/saltproject-deb` carries the same onedir
binaries — bundled Python included — that the Salt Project ships to servers, so
the container runs the build they test and support. Both amd64 and arm64 are
served.

**Group-writable, not fixed-uid.** Every path Salt writes is group-owned by root
with group permissions mirroring user permissions. OpenShift runs containers as
an arbitrary UID from the namespace range with gid 0 in the supplementary
groups, so an image only its own uid can write fails under `restricted-v2`.

**One process per container.** The official image's `saltinit` supervises
salt-master and salt-api together. Here salt-master is the command and salt-api
is the same image with a different command, so the kubelet supervises each and a
probe failure names the process that actually failed.

## Not yet built

This has not been built or run — the Docker daemon was not reachable from the
environment it was written in. Expect to iterate on the dependency list the first
time you build it.
