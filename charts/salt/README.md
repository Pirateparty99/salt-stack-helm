# salt

A Helm chart for running a Salt master on Kubernetes, with OpenShift/OKD in mind.

## Install

```bash
helm install salt ./charts/salt --namespace salt --create-namespace
```

## What this chart assumes

A Salt master's identity is the key material on its volume. Minions trust a
master by its key, so the volume matters more than the pod: `replicaCount` is 1
by default, and running more needs shared storage and an external key store that
this chart does not set up for you.

## Reaching the master

Minions connect to **4505** (publish) and **4506** (return). Both are raw TCP.
An Ingress or an OpenShift Route terminates HTTP, so neither can carry them:

| Where the minions are | What to use |
| --- | --- |
| In the same cluster | `service.type: ClusterIP` (default) |
| Outside the cluster | `service.type: LoadBalancer`, or `NodePort` |

`route.enabled` exposes **salt-api only**, and the chart fails the render if you
enable it without `api.enabled` rather than producing a Route to nothing.

## Images

There is no current upstream Salt container. `docker.io/saltstack/salt` stops at
**3006.5** (Feb 2024) while Salt itself is at **3008.x**, so the chart's default
tag is old. Point `image.repository`/`image.tag` at your own build to run a
current Salt — the chart makes no assumption about which tag you use.

## OpenShift

`podSecurityContext` is empty by default, on purpose. OpenShift's `restricted-v2`
SCC gives each namespace its own UID range and rejects a pod asking for a fixed
`runAsUser` or `fsGroup` — the pod is never admitted. Leaving it empty lets the
platform assign one. Set it explicitly only where the cluster requires it.

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `replicaCount` | `1` | See above before raising it. |
| `image.repository` / `image.tag` | `saltstack/salt` / chart appVersion | See Images. |
| `config` | file/pillar roots, `auto_accept: false` | Rendered into `/etc/salt/master.d/master.conf`. |
| `service.type` | `ClusterIP` | `LoadBalancer`/`NodePort` for external minions. |
| `api.enabled` | `false` | salt-api needs an auth backend in `config`. |
| `route.enabled` | `false` | OpenShift Route for salt-api; requires `api.enabled`. |
| `persistence.enabled` | `true` | Holds `/etc/salt/pki` — losing it re-keys every minion. |
| `persistence.storageClass` | `""` | Cluster default when empty. |
| `gitsync.enabled` | `false` | Sidecar syncing `/srv/salt` from git; needs `gitsync.repo`. |

## Accepting minions

`auto_accept` is off by default. Accept keys by hand:

```bash
kubectl exec -n salt salt-0 -- salt-key -L
kubectl exec -n salt salt-0 -- salt-key -A
```

Turning `auto_accept` on accepts any minion that connects. Reasonable in a lab,
not outside one.
