# Quickstart

A trial install on any cluster with a default StorageClass: bundled PostgreSQL and Redis,
an NFS provisioner for the shared volume, no ingress.

## 1. Create the Secret

The chart never generates passwords. One Secret holds the license key and the passwords the
bundled databases will use:

```
kubectl create namespace polytomic
kubectl -n polytomic create secret generic polytomic-secrets \
  --from-literal=DEPLOYMENT_KEY='<license key from Polytomic>' \
  --from-literal=DATABASE_PASSWORD="$(openssl rand -hex 16)" \
  --from-literal=REDIS_PASSWORD="$(openssl rand -hex 16)"
```

## 2. Write values.yaml

```yaml
image:
  tag: rel2026.09.18          # https://docs.polytomic.com/changelog

polytomicDeploymentId: <deployment id from Polytomic>

auth:
  url: https://polytomic.example.com

config:
  ROOT_USER: you@example.com

operationalBucket:
  provider: s3
  name: my-polytomic-bucket
  region: us-east-1

secrets:
  existing:
    - name: polytomic-secrets

postgresql:
  enabled: true
  auth:
    existingSecret: polytomic-secrets

redis:
  enabled: true
  auth:
    existingSecret: polytomic-secrets

sharedVolume:
  mode: dynamic
  dynamic:
    storageClassName: nfs

nfs-server-provisioner:
  enabled: true
```

Bucket access comes from the environment (an IAM role on the nodes or the ServiceAccount).
For static keys, add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to the Secret above.

## 3. Install

```
helm install polytomic oci://ghcr.io/polytomic/charts/polytomic --version 2.0.0 \
  --namespace polytomic -f values.yaml
```

Then port-forward to the app:

```
kubectl -n polytomic port-forward svc/polytomic-app 8080:5100
open http://127.0.0.1:8080
```

## Moving to production

- Point `database.*` and `externalRedis.*` at managed services and set `postgresql.enabled`
  and `redis.enabled` to `false`.
- Use `sharedVolume.mode: static` with your CSI driver (EFS, Filestore, NFS) and turn off
  the NFS provisioner.
- Enable `ingress` with your controller's class and annotations.
- Manage secrets with the External Secrets Operator: `docs/secrets-aws.md`,
  `docs/secrets-gcp.md`.
- Set `serviceAccount.annotations` for workload identity instead of static bucket keys.
