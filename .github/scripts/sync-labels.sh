#!/usr/bin/env bash
# Sync repository labels from a YAML config to GitHub.
# - Adds labels that don't exist.
# - Updates labels whose color/description drifted.
# - Does NOT delete labels by default. Set PRUNE=1 to remove labels that are
#   in the repo but not in the config (opt-in; intended for manual local runs,
#   not for CI).
#
# Requirements (all preinstalled on ubuntu-latest):
#   gh, yq (mikefarah, JSON-capable), jq, bash
#
# Env:
#   GH_TOKEN  required. Token with `issues: write` on the repo.
#   DRY_RUN   optional. "1" prints actions without executing them.
#   PRUNE     optional. "1" deletes repo labels that are missing from CONFIG.
#             Combine with DRY_RUN=1 first to preview what would be deleted.
set -euo pipefail

CONFIG="${1:-.github/labels.yml}"
DRY_RUN="${DRY_RUN:-0}"
PRUNE="${PRUNE:-0}"

if [[ ! -f "$CONFIG" ]]; then
  echo "config not found: $CONFIG" >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

existing=$(gh label list --limit 1000 --json name,color,description)

yq -o=json '.[]' "$CONFIG" | jq -c '.' | while IFS= read -r label; do
  name=$(jq -r '.name'              <<<"$label")
  color=$(jq -r '.color'            <<<"$label")
  desc=$(jq -r '.description // ""' <<<"$label")

  current=$(jq --arg n "$name" '.[] | select(.name == $n)' <<<"$existing")

  if [[ -z "$current" ]]; then
    echo "create: $name"
    run gh label create "$name" --color "$color" --description "$desc"
  else
    cur_color=$(jq -r '.color'            <<<"$current")
    cur_desc=$(jq -r '.description // ""' <<<"$current")
    if [[ "$cur_color" != "$color" || "$cur_desc" != "$desc" ]]; then
      echo "update: $name (color $cur_color -> $color)"
      run gh label edit "$name" --color "$color" --description "$desc"
    else
      echo "unchanged: $name"
    fi
  fi
done

if [[ "$PRUNE" == "1" ]]; then
  desired_names=$(yq -o=json -I=0 '[.[].name]' "$CONFIG")
  jq -r --argjson keep "$desired_names" \
    '.[] | select(.name | IN($keep[]) | not) | .name' <<<"$existing" \
    | while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        echo "delete: $name"
        run gh label delete "$name" --yes
      done
fi
