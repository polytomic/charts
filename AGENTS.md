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
make tools                 # once
make deps                  # and again after editing the lib
make lint
make test
make template FIXTURE=mcp  # eyeball a render; fixtures live in charts/polytomic/ci
```

- helm-unittest suites live in `charts/polytomic/tests` and
  `charts/polytomic-base/test-consumer/tests`. Add a test with every behaviour change.
  Assertions against subchart templates must list the sibling templates those include.
- `values.schema.json` is generated: edit the `# @schema` annotations in `values.yaml` and run
  `make schema`. Cross-field rules live in `polytomic.validateConfig`.
- Bumping a chart version needs a matching `## [x.y.z]` entry in that chart's
  `CHANGELOG.md`. Bumping the lib also means updating the pin and `Chart.lock` in
  `charts/polytomic` (`helm dependency update charts/polytomic`).
- Pinned tool versions live at the top of the `Makefile`; CI uses the same targets.

## Releasing

`main` holds the next release version. Merge a version-bump PR, optionally pin the resulting
`<version>-<sha>` prerelease somewhere to try it, then push a tag named
`polytomic-<version>` or `polytomic-base-<version>`.
