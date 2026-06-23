#!/usr/bin/env bash
set -euo pipefail

project_name="${1:-}"
repo_path="${2:-$PWD}"

if [[ -n "$project_name" ]]; then
  if [[ ! "$project_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "invalid project name: $project_name" >&2
    exit 1
  fi

  printf '%s\n' "$project_name"
  exit 0
fi

if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git worktree: $repo_path" >&2
  exit 1
fi

remote_url="$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)"

if [[ -z "$remote_url" ]]; then
  echo "origin remote is missing: $repo_path" >&2
  exit 1
fi

trimmed_remote="${remote_url%.git}"
owner=""
repo=""

if [[ "$trimmed_remote" =~ ^git@github\.com:([^/]+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
elif [[ "$trimmed_remote" =~ ^https?://github\.com/([^/]+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
elif [[ "$trimmed_remote" =~ ^ssh://git@github\.com/([^/]+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
else
  echo "unsupported github remote format: $remote_url" >&2
  exit 1
fi

if [[ "$owner" != "kt-cloud-infra-ops" ]]; then
  echo "remote owner is not kt-cloud-infra-ops: $owner" >&2
  exit 1
fi

printf '%s\n' "$repo"
