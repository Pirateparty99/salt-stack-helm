# salt-stack-helm

A Helm chart for a homelab Salt Stack deployment, since there is no current
upstream one.

The chart lives in [`charts/salt`](charts/salt); see its
[README](charts/salt/README.md) for values and usage.

## Why

The Salt Project publishes no official Helm chart. The community charts are
abandoned — the most recently touched is `midokura-community/salt` at v0.0.3
(Salt 3006.3), and the others were last updated in 2021–2022.

This chart started from the Midokura one and fixes what was wrong with it:

| Problem | Effect |
| --- | --- |
| `replicas` read `master.replicaCount`, values defined `replicaCount` | rendered `replicas: null` |
| PVC used `storageClass` instead of `storageClassName` | the setting was silently ignored and every claim landed on the cluster default |
| `podSecurityContext.fsGroup: 450` hardcoded | rejected outright by OpenShift's `restricted-v2` SCC |
| git-sync sidecar read `.Values.securityContext` | that key does not exist; it is `master.securityContext` |
| no liveness or readiness probes | a wedged master looked healthy |
| Ingress offered for 4505/4506 | those are raw TCP; an Ingress cannot carry them |

It also adds an OpenShift Route for salt-api, a headless Service for stable
per-pod DNS, and a config checksum so a config change actually restarts the
master.

## Status

Renders and lints clean, and the rendered objects have been checked. It has not
yet been run against a live cluster.
