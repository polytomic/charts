# charts

Polytomic's Helm charts, published to GHCR as OCI artifacts.

| path | chart | what it is |
|---|---|---|
| `charts/polytomic` | `polytomic` | The Polytomic application and MCP server. Installed by customers and by Polytomic's own environments. |
| `charts/polytomic-base` | `polytomic-base` | Library chart of shared templates the `polytomic` chart (and Polytomic's internal `ping` chart) is built on. |
| `charts/polytomic-base/test-consumer` | | Unpublished chart that exists to unit-test the library. |

## Installing

Both packages are public.

```
helm install polytomic oci://ghcr.io/polytomic/charts/polytomic --version 2.0.0 -f values.yaml
```

See `charts/polytomic/README.md`, `charts/polytomic/docs/quickstart.md` and, when coming from
the 1.x on-premises chart, `charts/polytomic/UPGRADE-v2.0.md`.

## Working on the charts

```
make tools          # install helm-unittest and helm-values-schema-json at pinned versions
make check-tools    # install kubeconform, trivy, zizmor and actionlint into bin/
make deps           # vendor dependencies; re-run after editing the lib
make lint
make test
make kubeconform    # render every ci/ fixture and validate against Kubernetes schemas
make trivy-table    # Trivy misconfiguration report for charts/polytomic (report only)
make workflow-lint  # zizmor and actionlint on .github/workflows
make schema-check   # fail if values.schema.json is stale
make template FIXTURE=bundled   # render charts/polytomic with one ci/ fixture
make schema         # regenerate charts/polytomic/values.schema.json
```

Dependency tarballs under `charts/*/charts/` are gitignored; `Chart.lock` is committed and
`make deps` rebuilds them. `bin/` and `build/` are gitignored too.

Renovate keeps the GitHub Actions digests, subchart versions and tool pins current. A subchart
bump PR also bumps the chart's `version:`; add the matching `CHANGELOG.md` entry before merging.

## Releasing

Each chart has its own version in `Chart.yaml` and its own `CHANGELOG.md`. `main` always holds
the *next* release version.

1. Open a PR that bumps `version:` in the chart's `Chart.yaml` and adds a `## [x.y.z]` entry
   to its `CHANGELOG.md`. CI checks that the version is higher than `main`, is not already
   published, has a changelog entry, and (for the lib) that `charts/polytomic` pins the same
   lib version with an updated `Chart.lock`.
2. Merge. Every push to `main` that passes lint and tests publishes both charts as a
   prerelease, `<version>-<short sha>`, which you can pin to try a build before releasing:
   `--version 2.0.1-abc12345`. `helm install --version 2.0.1` never selects a prerelease.
   The same build can be rerun from the Actions tab (`CI`, run workflow, on `main`).
3. Tag the release: `polytomic-2.0.1` or `polytomic-base-1.0.1`. The tag workflow checks the
   tag matches `Chart.yaml`, runs lint and tests, and pushes that version to GHCR.

Prerelease builds older than 30 days are pruned weekly (`.github/workflows/prune.yml`).

## Verifying a release

Tagged releases are signed with cosign (keyless, Sigstore) and carry a GitHub build provenance
attestation. Either check proves the chart was built by this repository's release workflow.

```
cosign verify ghcr.io/polytomic/charts/polytomic:2.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/polytomic/charts/.github/workflows/release.yml@refs/tags/'

gh attestation verify oci://ghcr.io/polytomic/charts/polytomic:2.0.0 --owner polytomic
```

Prerelease builds from `main` are not signed.
