#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

apply=false
project_name="${CODEBUILD_PROJECT_NAME:-}"

while (( $# > 0 )); do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --project-name)
      project_name="${2:-}"
      shift 2
      ;;
    *)
      printf 'Usage: %s [--project-name NAME] [--apply]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$project_name" ]]; then
  printf 'Set CODEBUILD_PROJECT_NAME or pass --project-name NAME.\n' >&2
  exit 1
fi

aws_cli=(aws)
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_cli+=(--profile "$AWS_PROFILE")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  aws_cli+=(--region "$AWS_REGION")
fi

start_command=("${aws_cli[@]}" codebuild start-build --project-name "$project_name")

printf 'Command:\n'
printf '  %q' "${start_command[@]}"
printf '\n'

if [[ "$apply" != true ]]; then
  printf 'Dry run only. Re-run with --apply to start the build.\n'
  exit 0
fi

"${start_command[@]}" --query 'build.{BuildId:id,Status:buildStatus,SourceVersion:resolvedSourceVersion}' --output table
