#!/usr/bin/env bash
set -euo pipefail

LIMIT=20
WORKFLOW=""
RUN_ID=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --limit <n>          Number of runs to inspect when listing (default: 20)
  --workflow <name>    Restrict listing to a workflow name
  --run-id <id>        Show failed logs for a specific run ID
  -h, --help           Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --workflow)
      WORKFLOW="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$RUN_ID" ]]; then
  echo "[INFO] Run summary for $RUN_ID"
  gh run view "$RUN_ID"
  echo
  echo "[INFO] Failed-step logs for $RUN_ID"
  gh run view "$RUN_ID" --log-failed
  exit 0
fi

ARGS=(run list --limit "$LIMIT" --json databaseId,workflowName,headBranch,status,conclusion,createdAt,url)
if [[ -n "$WORKFLOW" ]]; then
  ARGS+=(--workflow "$WORKFLOW")
fi

echo "run_id workflow branch status conclusion created_at url"
gh "${ARGS[@]}" --jq '.[] | select((.conclusion == "failure") or (.status != "completed")) | "\(.databaseId) \(.workflowName|gsub(" ";"_")) \(.headBranch) \(.status) \(.conclusion // "-") \(.createdAt) \(.url)"'
