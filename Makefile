HELM_UNITTEST_VERSION ?= 1.0.3
HELM_SCHEMA_VERSION   ?= 2.4.0

LIB      := charts/polytomic-base
CONSUMER := charts/polytomic-base/test-consumer
CHART    := charts/polytomic

# Charts that render: the app chart and the lib's test harness.
RENDERABLE := $(CHART) $(CONSUMER)

.PHONY: tools deps lint template test schema clean

## Install the Helm plugins CI uses, at pinned versions. Fails on a version
## mismatch rather than running with whatever is installed.
tools:
	@helm plugin list | grep -qE '^unittest[[:space:]]+$(HELM_UNITTEST_VERSION)[[:space:]]' \
		|| helm plugin install https://github.com/helm-unittest/helm-unittest --version $(HELM_UNITTEST_VERSION) --verify=false
	@helm plugin list | grep -qE '^schema[[:space:]]+$(HELM_SCHEMA_VERSION)[[:space:]]' \
		|| helm plugin install https://github.com/losisin/helm-values-schema-json --version $(HELM_SCHEMA_VERSION) --verify=false
	@helm plugin list | grep -qE '^unittest[[:space:]]+$(HELM_UNITTEST_VERSION)[[:space:]]' || { echo "helm-unittest $(HELM_UNITTEST_VERSION) required"; exit 1; }
	@helm plugin list | grep -qE '^schema[[:space:]]+$(HELM_SCHEMA_VERSION)[[:space:]]' || { echo "helm-values-schema-json $(HELM_SCHEMA_VERSION) required"; exit 1; }

## Vendor dependencies (the lib, Bitnami, NFS) from Chart.lock. Re-run after
## editing the lib: consumers render the vendored copy. Not a prerequisite of
## lint/test because it refreshes every configured Helm repo; CI runs it first.
deps:
	@for c in $(RENDERABLE); do helm dependency build "$$c"; done

## Bare lint, then schema-aware lint per ci fixture. Run `make deps` first.
lint:
	@for c in $(RENDERABLE); do \
		helm lint --skip-schema-validation "$$c" || exit 1; \
		for f in "$$c"/ci/*-values.yaml; do \
			[ -e "$$f" ] || continue; \
			helm lint -f "$$f" "$$c" || exit 1; \
		done; \
	done

## Render the app chart with one ci fixture: make template FIXTURE=bundled
FIXTURE ?= default
template:
	helm template polytomic $(CHART) -f $(CHART)/ci/$(FIXTURE)-values.yaml

## helm-unittest for the app chart and the lib's test-consumer. Run `make deps`
## first, and again after editing the lib.
test:
	@for c in $(RENDERABLE); do helm unittest "$$c" || exit 1; done

## Regenerate values.schema.json from values.yaml annotations.
schema:
	helm schema -f $(CHART)/values.yaml -o $(CHART)/values.schema.json \
		--draft 2020 \
		--schema-root.id https://github.com/polytomic/charts/polytomic/values.schema.json \
		--schema-root.title "polytomic chart values"

clean:
	rm -rf $(CHART)/charts $(CONSUMER)/charts
