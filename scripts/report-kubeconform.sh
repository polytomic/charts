#!/bin/sh
# Markdown summary of a `make kubeconform` log (build/kubeconform.log).
set -eu

log=${1:?usage: report-kubeconform.sh <kubeconform.log>}

echo "### kubeconform"
echo
if [ ! -s "$log" ]; then
  echo "Not run: the render or an earlier step failed."
  exit 0
fi

awk '
  /^== / { file = $2; sub(/^.*render\//, "", file); sub(/\.yaml$/, "", file); next }
  /^Summary: / {
    # Summary: N resources found in 1 file - Valid: a, Invalid: b, Errors: c, Skipped: d
    n = $2; gsub(/,/, "")
    for (i = 1; i <= NF; i++) {
      if ($i == "Valid:") v = $(i + 1)
      if ($i == "Invalid:") inv = $(i + 1)
      if ($i == "Errors:") e = $(i + 1)
    }
    rows = rows "| " file " | " n " | " v " | " inv " | " e " |\n"
    if (inv + e > 0) bad = 1
    next
  }
  file != "" { fails = fails file ": " $0 "\n" }
  END {
    printf "| render | resources | valid | invalid | errors |\n|---|---|---|---|---|\n%s", rows
    if (bad) printf "\n<details><summary>failures</summary>\n\n```\n%s```\n\n</details>\n", fails
  }
' "$log"
