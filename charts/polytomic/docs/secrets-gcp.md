# Secrets from Google Secret Manager

The chart can ask the External Secrets Operator (ESO) to materialise Kubernetes Secrets from
Google Secret Manager. Values then hold only names and key mappings.

## 1. Install ESO

ESO is a cluster-wide operator and is not bundled with this chart.

```
helm install external-secrets oci://ghcr.io/external-secrets/charts/external-secrets \
  --namespace external-secrets --create-namespace
```

Current ESO serves `external-secrets.io/v1`, the chart default. An older ESO that serves only
`v1beta1` needs `secrets.external.apiVersion: external-secrets.io/v1beta1`.

## 2. Grant ESO access

Bind a Google service account with `roles/secretmanager.secretAccessor` to ESO's Kubernetes
ServiceAccount through Workload Identity:

```
gcloud iam service-accounts add-iam-policy-binding eso@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[external-secrets/external-secrets]"
kubectl -n external-secrets annotate serviceaccount external-secrets \
  iam.gke.io/gcp-service-account=eso@PROJECT.iam.gserviceaccount.com
```

## 3. Create a ClusterSecretStore

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
    gcpsm:
      projectID: PROJECT
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: my-cluster
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

`gcp-secret-manager` is the chart's default store name; change
`secrets.external.defaults.gcpsm.storeName` to use another.

## 4. Store the secrets

One Secret Manager secret holds a JSON object of key/value pairs:

```
echo '{"DEPLOYMENT_KEY":"...","DATABASE_PASSWORD":"...","REDIS_PASSWORD":"..."}' \
  | gcloud secrets create polytomic-app --data-file=-
```

## 5. Map them in values

```yaml
secrets:
  external:
    entries:
      - name: polytomic-secrets        # the Kubernetes Secret ESO will write
        source:
          type: gcpsm
          path: polytomic-app          # the Secret Manager secret name
        data:
          - DEPLOYMENT_KEY
          - DATABASE_PASSWORD
          - REDIS_PASSWORD
          - k8sKey: GOOGLE_CLIENT_SECRET
            remoteKey: google_oauth_secret
```

The MCP server has the same shape under `mcp.secrets.external`. With the bundled databases,
`postgresql.auth.existingSecret` and `redis.auth.existingSecret` name the same Secret.

## Bucket access

Use `operationalBucket.provider: gcs`. Bind the app's ServiceAccount to a Google service
account with access to the bucket through `serviceAccount.annotations`
(`iam.gke.io/gcp-service-account`), and do the same for
`vector.daemonset.serviceAccount.annotations` when the Vector DaemonSet is on.
