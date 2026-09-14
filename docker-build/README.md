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

`SALT_VERSION` is any version on PyPI — `3006.27` for the older maintained line,
`3008.2` for current. `PYTHON_VERSION` defaults to 3.12.

## Then point the chart at it

```yaml
image:
  repository: ghcr.io/pirateparty99/salt
  tag: "3008.2"
```

## Choices worth knowing

**Debian, not Alpine.** Salt publishes an sdist only, so pip builds it and its
dependencies. On musl, `pyzmq`/`cryptography`/`cffi` have no matching wheels and
compile from source; on glibc they resolve to manylinux wheels.

**Group-writable, not fixed-uid.** Files are owned `450:0` with group permissions
mirroring user permissions. OpenShift runs containers as an arbitrary UID from
the namespace range with gid 0 in the supplementary groups, so an image that only
its own uid can write fails there. uid 450 matches the official image, so a
volume written by one stays readable by the other.

**One process per container.** The official image's `saltinit` supervises
salt-master and salt-api together. Here salt-master is the command and salt-api
is the same image with a different command, so the kubelet supervises each and a
probe failure names the process that actually failed.

## Not yet built

This has not been built or run — the Docker daemon was not reachable from the
environment it was written in. Expect to iterate on the dependency list the first
time you build it.
