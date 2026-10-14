#!/usr/bin/env bash
# Release rules for one chart: release-check.sh [--allow-published] <chart>
# Needs gh auth (GH_TOKEN in CI) to list what GHCR already has.
# --allow-published lets a release job re-run after a push that was not tagged.
set -euo pipefail

allow_published=0
if [[ "${1:-}" == "--allow-published" ]]; then allow_published=1; shift; fi
chart=${1:?usage: release-check.sh [--allow-published] <chart>}
dir="charts/$chart"
owner=${GITHUB_REPOSITORY_OWNER:-polytomic}

fail() { echo "::error::$*"; exit 1; }
parse_version() { awk -F'[: \t]+' '/^version:/ {gsub(/["'\'']/, "", $2); print $2; exit}' "$1"; }

version=$(parse_version "$dir/Chart.yaml")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$chart version $version must be a plain X.Y.Z release version."

# Published releases: X.Y.Z tags on the GHCR package, oldest first. Package
# endpoints differ for organisations and user accounts; 404 means no package yet.
# RELEASE_CHECK_PUBLISHED overrides the list for testing.
if [[ -z "${RELEASE_CHECK_PUBLISHED+x}" ]]; then
  if [[ "$(gh api "/users/$owner" --jq .type)" == "Organization" ]]; then base="/orgs/$owner"; else base="/users/$owner"; fi
  if ! raw=$(gh api --paginate "$base/packages/container/charts%2F$chart/versions" 2>&1); then
    grep -q 'HTTP 404' <<<"$raw" || fail "could not list published versions of $chart: $raw"
    raw='[]'
  fi
  published=$(jq -r '.[].metadata.container.tags[]? | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$raw" | sort -V)
else
  published=$RELEASE_CHECK_PUBLISHED
fi
newest=$(tail -n 1 <<<"$published")

if grep -qxF "$version" <<<"$published"; then
  (( allow_published )) || fail "$chart $version is already published; pick a new version."
elif [[ -n "$newest" && "$(printf '%s\n%s\n' "$newest" "$version" | sort -V | tail -n 1)" != "$version" ]]; then
  fail "$chart version $version is not greater than the newest release $newest."
fi

grep -qF "## [$version]" "$dir/CHANGELOG.md" || fail "$dir/CHANGELOG.md has no entry for $version."

if [[ "$chart" == "polytomic-base" ]]; then
  pinned=$(awk '/name: polytomic-base/{f=1} f && /version:/{gsub(/["'\'']/, "", $2); print $2; exit}' charts/polytomic/Chart.yaml)
  [[ "$pinned" == "$version" ]] || fail "charts/polytomic pins polytomic-base $pinned but the lib is $version."
  locked=$(awk '/name: polytomic-base/{f=1} f && /version:/{print $2; exit}' charts/polytomic/Chart.lock)
  [[ "$locked" == "$version" ]] || fail "charts/polytomic/Chart.lock records polytomic-base $locked; run helm dependency update charts/polytomic."
fi

echo "$chart $version ok"
