# AGENTS.md

Guidance for AI coding assistants working in this repository.

## Layout

- `charts/polytomic-base`: library chart. `templates/_*.tpl` only; renders nothing itself.
  `test-consumer/` is an unpublished chart that carries the lib's unit tests.
- `charts/polytomic`: the application chart. `templates/*.yaml` are one-line wrappers that
  call the lib; `templates/mcp/*.yaml` call the same lib templates for the MCP component;
  `templates/_helpers.tpl` holds everything chart-specific.
- `.github/workflows`: `ci.yml` (lint, tests, version checks; prerelease on green push to
  main), `release.yml` (publish on tag), `prune.yml` (weekly prerelease cleanup).

## The lib contract

Every lib template and helper takes a dict, never the Helm root:
`(dict "root" $ "values" <block> "name" <prefix>)`. `values` is `.Values` for the app and
`.Values.mcp` for MCP; `name` is `""` or `"mcp"`. Consumer helpers are dispatched as
`<Chart.Name>[.<name>].<helper>`, and every consumer must define `reservedConfigKeys`,
`extraConfigData` and `extraEgress` for each name it renders. Snippets rendered through
`tpl` (initContainers, volumes, volumeMounts) get the dict as `.`, with the Helm root at
`.root`. `charts/polytomic-base/README.md` has the full contract.

The polytomic chart decorates its values before calling the lib (`polytomic.decorateAppValues`
and `polytomic.decorateMcpValues` in `_helpers.tpl`): the shared volume is prepended to
`services.defaults`, MCP inherits naming and image settings from the root, and the Vector
label is added when that DaemonSet is on. Work on a `deepCopy`; never mutate `.Values`.

## Rules

- The chart never renders a Kubernetes Secret and no secret value ever goes in
  `values.yaml`, a `ci/` fixture or a test. Secrets come from `secrets.external.entries`
  (ESO) and `secrets.existing`. Bucket and registry credentials are assumed to come from
  the environment or a secret source.
- Anything the chart computes from typed values is a reserved `config:` key. Add it to
  `polytomic.reservedConfigKeys` when you add it to `extraConfigData`.
- Features that are off by default render nothing when off: no labels, env vars, RBAC or
  Services for a disabled DaemonSet or MCP.
- Comments in templates and values are short. No paragraphs.

## Working

```
make tools check-tools     # once
make deps                  # and again after editing the lib
make lint
make test
make kubeconform           # fixture renders validated against Kubernetes schemas
make workflow-lint         # zizmor + actionlint, after editing .github/workflows
make schema-check          # after editing values.yaml annotations
make template FIXTURE=mcp  # eyeball a render; fixtures live in charts/polytomic/ci
```

- Renovate PRs do not bump chart versions; the next release PR bumps the version and adds the
  changelog entry. Tool pins in the `Makefile` carry `# renovate:` comments.

- helm-unittest suites live in `charts/polytomic/tests` and
  `charts/polytomic-base/test-consumer/tests`. Add a test with every behaviour change.
  Assertions against subchart templates must list the sibling templates those include.
- `values.schema.json` is generated: edit the `# @schema` annotations in `values.yaml` and run
  `make schema`. Cross-field rules live in `polytomic.validateConfig`.
- A release PR (labelled `release:<chart>`) needs a plain `x.y.z` `version:` newer than the
  last release and a matching `## [x.y.z]` entry in that chart's `CHANGELOG.md`. Releasing the
  lib also means updating the pin and `Chart.lock` in `charts/polytomic`
  (`helm dependency update charts/polytomic`). `scripts/release-check.sh <chart>` checks this.
  Unlabelled PRs have no version rules.
- Pinned tool versions live at the top of the `Makefile`; CI uses the same targets.

## Releasing

`main` holds the next release version. Every push to `main` publishes a `<version>-<sha>`
prerelease to try. Merging a PR labelled `release:polytomic` or `release:polytomic-base`
publishes that chart at its `Chart.yaml` version, signs it and tags `<chart>-<version>`. Nothing
is tagged by hand.
