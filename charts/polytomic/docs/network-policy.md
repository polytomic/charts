# NetworkPolicy

`networkPolicy.enabled: true` renders a policy for the app pods. Always allowed: DNS to
`kube-system`, traffic between pods in the release namespace, and ingress to the app port
from the ingress controller's namespace (`networkPolicy.ingressNamespaceSelector`) and from
`networkPolicy.ingressCidrs` (load balancer subnets). Egress to the bundled PostgreSQL and
Redis is added automatically when those subcharts are enabled.

Everything else the install talks to has to be listed in `networkPolicy.egress`. Polytomic's
egress is open-ended: it connects to whatever sources and destinations you configure, on
whatever ports they use (443 for SaaS APIs, 5432 / 3306 / 1433 for databases, 22 for SFTP,
and so on). There is no "allow HTTPS" shortcut, because it would silently break every
non-443 connector.

## Allow all egress

The policy then restricts ingress only.

```yaml
networkPolicy:
  enabled: true
  ingressCidrs:
    - 10.0.0.0/16
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
```

## Locked down

List each destination. Entries are verbatim NetworkPolicy egress rules.

```yaml
networkPolicy:
  enabled: true
  ingressNamespaceSelector:
    kubernetes.io/metadata.name: ingress-nginx
  egress:
    # Managed PostgreSQL
    - to:
        - ipBlock:
            cidr: 10.20.0.0/24
      ports:
        - protocol: TCP
          port: 5432
    # Managed Redis
    - to:
        - ipBlock:
            cidr: 10.20.1.0/24
      ports:
        - protocol: TCP
          port: 6379
    # Object storage and SaaS APIs
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 443
    # A source database in another VPC
    - to:
        - ipBlock:
            cidr: 10.30.5.0/24
      ports:
        - protocol: TCP
          port: 1433
```

Add a rule whenever a new connection type or network is introduced; a missing rule shows up
as a connection timeout in the sync's logs.

## MCP

`mcp.networkPolicy` is a separate policy for the MCP pod. It reaches the app through the
in-namespace Service, which is always allowed; add an egress rule only when
`mcp.polytomic.baseUrl` points off-cluster.
