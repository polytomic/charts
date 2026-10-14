#!/bin/sh
# Markdown summary of a `trivy config --format json` report.
set -eu

json=${1:?usage: report-trivy.sh <trivy.json> [fixture]}
fixture=${2:-}

echo "### Trivy"
echo
if [ ! -s "$json" ]; then
  echo "Not run: the scan failed before producing a report."
  exit 0
fi

jq -r --arg fixture "$fixture" '
  def esc: tostring | gsub("\\|"; "\\|") | gsub("`"; "\\`") | gsub("\n"; " ");
  def rank: {CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3}[.] // 4;
  [.Results[]? | select((.Misconfigurations // []) | length > 0)] as $results
  | [$results[] | .Target as $t | .Misconfigurations[] | . + {Target: $t}] as $all
  | ($all | group_by(.Severity) | map({key: .[0].Severity, value: length}) | from_entries) as $bySev
  | "\($all | length) misconfigurations"
    + (if $fixture != "" then " with the `\($fixture)` fixture" else "" end)
    + ": " + (["CRITICAL", "HIGH", "MEDIUM", "LOW"] | map("\(.) \($bySev[.] // 0)") | join(", ")),
    (if ($all | length) == 0 then empty else (
      "",
      "| template | checks | failures |",
      "|---|---|---|",
      ($results[] | "| \(.Target | esc) | \((.MisconfSummary.Successes // 0) + (.MisconfSummary.Failures // 0)) | \(.MisconfSummary.Failures // 0) |"),
      "",
      "<details><summary>findings</summary>",
      "",
      "| severity | id | template | title |",
      "|---|---|---|---|",
      ($all | sort_by((.Severity | rank), .Target, (.CauseMetadata.StartLine // 0), .ID)[]
        | "| \(.Severity) | [\(.ID | esc)](\(.PrimaryURL // "")) | \(.Target | esc):\(.CauseMetadata.StartLine // 0)-\(.CauseMetadata.EndLine // 0) | \(.Title | esc) |"),
      "",
      "</details>"
    ) end)
' "$json"
