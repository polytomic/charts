# Secrets from AWS Secrets Manager

The chart can ask the External Secrets Operator (ESO) to materialise Kubernetes Secrets from
AWS Secrets Manager. Values then hold only names and key mappings.

## 1. Install ESO

ESO is a cluster-wide operator and is not bundled with this chart.

```
helm install external-secrets oci://ghcr.io/external-secrets/charts/external-secrets \
  --namespace external-secrets --create-namespace
```

Current ESO serves `external-secrets.io/v1`, the chart default. An older ESO that serves only
`v1beta1` needs `secrets.external.apiVersion: external-secrets.io/v1beta1`.

## 2. Grant ESO access

Give ESO an IAM role that can read the secrets, through IRSA on EKS:

```
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
  "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:polytomic/*"
}
```

Annotate ESO's ServiceAccount with the role, or create a dedicated ServiceAccount the store
references.

## 3. Create a ClusterSecretStore

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

`aws-secrets-manager` is the chart's default store name; change
`secrets.external.defaults.asm.storeName` to use another.

## 4. Store the secrets

One Secrets Manager secret holds a JSON object of key/value pairs:

```
aws secretsmanager create-secret --name polytomic/app --secret-string '{
  "DEPLOYMENT_KEY": "...",
  "DATABASE_PASSWORD": "...",
  "REDIS_PASSWORD": "...",
  "GOOGLE_CLIENT_SECRET": "..."
}'
```

## 5. Map them in values

```yaml
secrets:
  external:
    entries:
      - name: polytomic-secrets        # the Kubernetes Secret ESO will write
        source:
          type: asm
          path: polytomic/app          # the Secrets Manager secret name
        data:
          - DEPLOYMENT_KEY             # same key on both sides
          - DATABASE_PASSWORD
          - REDIS_PASSWORD
          - k8sKey: GOOGLE_CLIENT_SECRET
            remoteKey: google_oauth_secret   # when the names differ
```

Several entries can map several remote secrets; the first is the primary Secret handed to
spawned Jobs. The MCP server has the same shape under `mcp.secrets.external`, and the
Vector and Datadog DaemonSets read `secrets.existing` lists of their own.

With the bundled databases, `postgresql.auth.existingSecret` and `redis.auth.existingSecret`
name the same Secret (`polytomic-secrets` above).

## Bucket access

Prefer IRSA for the app's own bucket access: put the role ARN in
`serviceAccount.annotations["eks.amazonaws.com/role-arn"]` and, for the Vector DaemonSet,
in `vector.daemonset.serviceAccount.annotations`. Static keys, if you must, go in the mapped
secret as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
