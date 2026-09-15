#!/usr/bin/env bash

set -euo pipefail

required_commands=(node npm)

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
done

node_major="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$node_major" != "22" ]]; then
  printf 'Node.js 22 is required; found %s.\n' "$(node --version)" >&2
  exit 1
fi

if [[ ! -f package-lock.json ]]; then
  printf 'package-lock.json is required for deterministic installation.\n' >&2
  exit 1
fi

printf 'Installing dependencies with npm ci...\n'
npm ci

mkdir -p dist reports
printf 'Local setup complete. Generated directories: dist/ and reports/.\n'
