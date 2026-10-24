# Tool pins. The `# renovate:` comments let Renovate bump them.
# renovate: datasource=github-releases depName=helm-unittest/helm-unittest extractVersion=^v(?<version>.*)$
HELM_UNITTEST_VERSION ?= 1.0.3
# renovate: datasource=github-releases depName=losisin/helm-values-schema-json extractVersion=^v(?<version>.*)$
HELM_SCHEMA_VERSION   ?= 2.4.0
# renovate: datasource=github-releases depName=yannh/kubeconform extractVersion=^v(?<version>.*)$
KUBECONFORM_VERSION   ?= 0.8.0
# renovate: datasource=github-releases depName=aquasecurity/trivy extractVersion=^v(?<version>.*)$
TRIVY_VERSION         ?= 0.76.1
# renovate: datasource=github-releases depName=zizmorcore/zizmor extractVersion=^v(?<version>.*)$
ZIZMOR_VERSION        ?= 1.30.1
# renovate: datasource=github-releases depName=rhysd/actionlint extractVersion=^v(?<version>.*)$
ACTIONLINT_VERSION    ?= 1.7.12

# Kubernetes versions fixtures are validated against: the chart's floor and current.
KUBE_VERSIONS   ?= 1.34.0 1.35.0
# datreeio/CRDs-catalog commit kubeconform fetches CRD schemas (ExternalSecret) from.
CRD_CATALOG_REV ?= 63669a570e231d4f1f8396d229a1de512bcf0a34
# Fixture Trivy scans the app chart with: app + MCP + ExternalSecrets.
TRIVY_FIXTURE   ?= mcp

LIB      := charts/polytomic-base
CONSUMER := charts/polytomic-base/test-consumer
CHART    := charts/polytomic
BIN      := bin
BUILD    := build

# Charts that render: the app chart and the lib's test harness.
RENDERABLE := $(CHART) $(CONSUMER)

OS   := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')

KUBECONFORM_URL := https://github.com/yannh/kubeconform/releases/download/v$(KUBECONFORM_VERSION)/kubeconform-$(OS)-$(ARCH).tar.gz
TRIVY_URL       := https://github.com/aquasecurity/trivy/releases/download/v$(TRIVY_VERSION)/trivy_$(TRIVY_VERSION)_$(if $(filter darwin,$(OS)),macOS,Linux)-$(if $(filter arm64,$(ARCH)),ARM64,64bit).tar.gz
ZIZMOR_URL      := https://github.com/zizmorcore/zizmor/releases/download/v$(ZIZMOR_VERSION)/zizmor-$(if $(filter arm64,$(ARCH)),aarch64,x86_64)-$(if $(filter darwin,$(OS)),apple-darwin,unknown-linux-gnu).tar.gz
ACTIONLINT_URL  := https://github.com/rhysd/actionlint/releases/download/v$(ACTIONLINT_VERSION)/actionlint_$(ACTIONLINT_VERSION)_$(OS)_$(ARCH).tar.gz

CRD_SCHEMA := https://raw.githubusercontent.com/datreeio/CRDs-catalog/$(CRD_CATALOG_REV)/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json

# fetch <url> <binary>: download a release tarball and install the named binary into bin/.
FETCH = fetch() { tmp=$$(mktemp -d) \
	&& curl --fail --location --silent --show-error "$$1" -o "$$tmp/archive.tar.gz" \
	&& tar -xzf "$$tmp/archive.tar.gz" -C "$$tmp" \
	&& bin=$$(find "$$tmp" -type f -name "$$2" | head -n 1) && [ -n "$$bin" ] \
	&& mkdir -p $(BIN) && chmod +x "$$bin" && mv "$$bin" $(BIN)/"$$2" && rm -rf "$$tmp"; }

# Shared Trivy invocation; report only, never fails.
TRIVY_SCAN = $(BIN)/trivy config --skip-version-check --exit-code 0 --helm-values $(CHART)/ci/$(TRIVY_FIXTURE)-values.yaml

.PHONY: tools check-tools deps lint template render kubeconform kubeconform-report trivy trivy-table trivy-report workflow-lint test schema schema-check clean clean-tools

## Install the Helm plugins CI uses, at pinned versions. Fails on a version
## mismatch rather than running with whatever is installed.
tools:
	@helm plugin list | grep -qE '^unittest[[:space:]]+$(HELM_UNITTEST_VERSION)[[:space:]]' \
		|| helm plugin install https://github.com/helm-unittest/helm-unittest --version $(HELM_UNITTEST_VERSION) --verify=false
	@helm plugin list | grep -qE '^schema[[:space:]]+$(HELM_SCHEMA_VERSION)[[:space:]]' \
		|| helm plugin install https://github.com/losisin/helm-values-schema-json --version $(HELM_SCHEMA_VERSION) --verify=false
	@helm plugin list | grep -qE '^unittest[[:space:]]+$(HELM_UNITTEST_VERSION)[[:space:]]' || { echo "helm-unittest $(HELM_UNITTEST_VERSION) required"; exit 1; }
	@helm plugin list | grep -qE '^schema[[:space:]]+$(HELM_SCHEMA_VERSION)[[:space:]]' || { echo "helm-values-schema-json $(HELM_SCHEMA_VERSION) required"; exit 1; }

## Install the scanners and linters into bin/ at pinned versions.
check-tools:
	@$(FETCH); $(BIN)/kubeconform -v 2>/dev/null | grep -qF 'v$(KUBECONFORM_VERSION)' || fetch '$(KUBECONFORM_URL)' kubeconform
	@$(FETCH); $(BIN)/trivy --version 2>/dev/null | grep -qF 'Version: $(TRIVY_VERSION)' || fetch '$(TRIVY_URL)' trivy
	@$(FETCH); $(BIN)/zizmor --version 2>/dev/null | grep -qF '$(ZIZMOR_VERSION)' || fetch '$(ZIZMOR_URL)' zizmor
	@$(FETCH); $(BIN)/actionlint --version 2>/dev/null | grep -qF '$(ACTIONLINT_VERSION)' || fetch '$(ACTIONLINT_URL)' actionlint

## Vendor dependencies (the lib, Bitnami, NFS) from Chart.lock. Re-run after
## editing the lib: consumers render the vendored copy. Not a prerequisite of
## lint/test because it refreshes every configured Helm repo; CI runs it first.
## Helm only resolves Chart.yaml repository URLs that are registered locally.
deps:
	@helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
	@helm repo add nfs-ganesha-server-and-external-provisioner \
		https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner/ --force-update
	@for c in $(RENDERABLE); do helm dependency build "$$c" || exit 1; done

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

## Render every ci fixture of every renderable chart, per Kubernetes version,
## into build/render/<chart>/<fixture>/<version>.yaml. Run `make deps` first.
render:
	@rm -rf $(BUILD)/render $(BUILD)/kubeconform.log
	@for c in $(RENDERABLE); do \
		name=$$(basename "$$c"); n=0; \
		for f in "$$c"/ci/*-values.yaml; do \
			[ -e "$$f" ] || continue; n=$$((n + 1)); \
			fixture=$$(basename "$$f" -values.yaml); \
			out=$(BUILD)/render/$$name/$$fixture; mkdir -p "$$out"; \
			for k in $(KUBE_VERSIONS); do \
				helm template ci-render "$$c" -f "$$f" --kube-version "$$k" > "$$out/$$k.yaml" || exit 1; \
			done; \
		done; \
		[ "$$n" -gt 0 ] || { echo "$$name: no ci fixtures found"; exit 1; }; \
	done

## Validate every render against the Kubernetes API schemas for its version.
## Checks every file before failing; output is kept in build/kubeconform.log
## for `make kubeconform-report`.
kubeconform: render
	@log=$(BUILD)/kubeconform.log; : > "$$log"; failed=0; \
	for f in $$(find $(BUILD)/render -name '*.yaml' | sort); do \
		echo "== $$f" >> "$$log"; \
		if $(BIN)/kubeconform -strict -summary -kubernetes-version "$$(basename "$$f" .yaml)" \
			-schema-location default -schema-location '$(CRD_SCHEMA)' "$$f" >> "$$log" 2>&1; \
		then :; else failed=1; fi; \
	done; \
	cat "$$log"; [ "$$failed" -eq 0 ]

## Markdown summary of the last `make kubeconform`; CI posts it on PRs.
kubeconform-report:
	@mkdir -p $(BUILD)/report
	scripts/report-kubeconform.sh $(BUILD)/kubeconform.log > $(BUILD)/report/kubeconform.md

## Trivy misconfiguration scan of the app chart. Report only: never fails.
## SARIF for CI; `make trivy-table` to read it locally.
trivy:
	@mkdir -p $(BUILD)
	$(TRIVY_SCAN) --format sarif --output $(BUILD)/trivy.sarif $(CHART)

trivy-table:
	$(TRIVY_SCAN) $(CHART)

## Markdown summary of the scan; CI posts it on PRs.
trivy-report:
	@mkdir -p $(BUILD)/report
	$(TRIVY_SCAN) --format json --output $(BUILD)/trivy.json $(CHART)
	scripts/report-trivy.sh $(BUILD)/trivy.json $(TRIVY_FIXTURE) > $(BUILD)/report/trivy.md

## Lint the GitHub workflows: zizmor (security) then actionlint (correctness).
workflow-lint:
	$(BIN)/zizmor .github/workflows
	$(BIN)/actionlint

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

## Fail if values.schema.json is out of date with values.yaml.
schema-check: schema
	git diff --exit-code $(CHART)/values.schema.json

clean:
	rm -rf $(CHART)/charts $(CONSUMER)/charts $(BUILD)

clean-tools:
	rm -rf $(BIN)
