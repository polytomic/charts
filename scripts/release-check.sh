#!/usr/bin/env bash
# Release rules for one chart: release-check.sh [--allow-published] <chart>
# Needs gh auth (GH_TOKEN in CI) to list what GHCR already has.
# --allow-published lets a release job re-run after a push that was not tagged.
set -euo pipefail

allow_published=0
if [[ "${1:-}" == "--allow-published" ]]; then allow_published=1; shift; fi
chart=${1:?usage: release-check.sh [--allow-published] <chart>}
dir="charts/$chart"

fail() { echo "::error::$*"; exit 1; }
parse_version() { awk -F'[: \t]+' '/^version:/ {gsub(/["'\'']/, "", $2); print $2; exit}' "$1"; }

version=$(parse_version "$dir/Chart.yaml")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$chart version $version must be a plain X.Y.Z release version."

# Published releases: X.Y.Z tags on the GHCR package, oldest first.
# RELEASE_CHECK_PUBLISHED overrides the list for testing.
if [[ -z "${RELEASE_CHECK_PUBLISHED+x}" ]]; then
  versions=$("$(dirname "$0")/ghcr.sh" versions "$chart")
  published=$(awk '{print $2}' <<<"$versions" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V || true)
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
