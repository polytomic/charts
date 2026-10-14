#!/usr/bin/env bash
# GHCR package versions of a chart.
#   ghcr.sh versions <chart>       prints "<id> <tag>" per tag; nothing if no package yet
#   ghcr.sh delete <chart> <tag>   deletes the version carrying <tag>; no-op if absent
# Needs gh auth (GH_TOKEN in CI): read:packages to list, delete:packages to delete.
set -euo pipefail

cmd=${1:?usage: ghcr.sh versions <chart> | delete <chart> <tag>}
chart=${2:?chart required}
owner=${GITHUB_REPOSITORY_OWNER:-polytomic}

# Package endpoints differ for organisations and user accounts.
if [[ "$(gh api "/users/$owner" --jq .type)" == "Organization" ]]; then base="/orgs/$owner"; else base="/users/$owner"; fi
pkg="$base/packages/container/charts%2F$chart"

versions() {
  local raw
  if ! raw=$(gh api --paginate "$pkg/versions" 2>&1); then
    grep -q 'HTTP 404' <<<"$raw" && return 0
    echo "::error::could not list GHCR versions of $chart: $raw" >&2
    return 1
  fi
  jq -r '.[] | .id as $id | .metadata.container.tags[]? | "\($id) \(.)"' <<<"$raw"
}

case "$cmd" in
  versions) versions ;;
  delete)
    tag=${3:?tag required}
    ids=$(versions | awk -v t="$tag" '$2 == t {print $1}')
    for id in $ids; do
      echo "deleting $chart $tag from GHCR (package version $id)"
      gh api --method DELETE "$pkg/versions/$id" --silent
    done ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
