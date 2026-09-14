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

Defaults to `pirateparty99/salt`, built by [`docker-build/`](../../docker-build)
in this repo: Salt 3008.2 on UBI 10, multi-arch (amd64/arm64), non-root.

There is no current upstream alternative — `docker.io/saltstack/salt` stops at
**3006.5** (Feb 2024) while Salt is at **3008.x**. Point
`image.repository`/`image.tag` elsewhere if you build your own; the chart makes
no assumption about the tag.

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

## Verified on OpenShift

Deployed to OKD 4.19 and confirmed running: admitted by `restricted-v2` with an
assigned UID from the namespace range, `salt-key` responding, listening on 4505
and 4506, and the root filesystem read-only.

## Web UI

[SaltGUI](https://github.com/erwindon/SaltGUI) is a static site served by
salt-api itself, so the browser talks to one origin and no CORS setup is
needed. It implements no authentication of its own: the login form sends a
username, password and eauth type to salt-api, which authenticates them. That
means the UI logs in against whatever `externalAuth` the master is configured
with — including LDAP.

```yaml
api:
  enabled: true
saltgui:
  enabled: true
route:
  enabled: true
  host: salt.apps.example.com
externalAuth:
  enabled: true
  existingSecret: salt-ldap
  config:
    ldap:
      'CN=salt-admins,OU=Groups,OU=EXAMPLE,DC=example,DC=com%':
        - .*
        - '@runner'
        - '@wheel'
        - '@jobs'
```

The trailing `%` on the group DN is what marks it as a group rather than a
user. Without it the rule matches a user of that name, which does not exist,
and every login is refused.

### The bind password

It does not go in values. `externalAuth.existingSecret` names a Secret with an
`ldap.conf` key, mounted at `/etc/salt/master.d/ldap.conf`:

```yaml
auth.ldap.server: dc01.example.com
auth.ldap.port: 636
auth.ldap.tls: True
auth.ldap.basedn: OU=EXAMPLE,DC=example,DC=com
auth.ldap.binddn: CN=ldap.svc,OU=Service Accounts,OU=EXAMPLE,DC=example,DC=com
auth.ldap.bindpw: <the password>
auth.ldap.accountattributename: sAMAccountName
auth.ldap.groupattribute: memberOf
auth.ldap.activedirectory: True
```

Replacing `/etc/salt/master` drops the packaged `default_include`, so the chart
puts it back — that is the only reason `master.d` is read at all.

## Accepting minions

`auto_accept` is off by default. Accept keys by hand:

```bash
kubectl exec -n salt salt-0 -- salt-key -L
kubectl exec -n salt salt-0 -- salt-key -A
```

Turning `auto_accept` on accepts any minion that connects. Reasonable in a lab,
not outside one.
