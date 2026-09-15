#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

build_id=""
timeout_seconds="${BUILD_WAIT_TIMEOUT_SECONDS:-1800}"
poll_seconds="${BUILD_POLL_SECONDS:-10}"

while (( $# > 0 )); do
  case "$1" in
    --build-id)
      build_id="${2:-}"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="${2:-}"
      shift 2
      ;;
    --poll-seconds)
      poll_seconds="${2:-}"
      shift 2
      ;;
    *)
      if [[ -z "$build_id" ]]; then
        build_id="$1"
        shift
      else
        printf 'Usage: %s BUILD_ID [--timeout-seconds N] [--poll-seconds N]\n' "$0" >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$build_id" ]]; then
  printf 'A CodeBuild build ID is required.\n' >&2
  exit 1
fi
if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ || ! "$poll_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Timeout and poll values must be positive integers.\n' >&2
  exit 1
fi

aws_cli=(aws)
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_cli+=(--profile "$AWS_PROFILE")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  aws_cli+=(--region "$AWS_REGION")
fi

start_time="$(date +%s)"
terminal_statuses='^(SUCCEEDED|FAILED|FAULT|STOPPED|TIMED_OUT)$'

while true; do
  status="$("${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" --query 'builds[0].buildStatus' --output text)"
  if [[ -z "$status" || "$status" == "None" ]]; then
    printf 'Build was not found: %s\n' "$build_id" >&2
    exit 1
  fi

  printf '%s  %s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$build_id" "$status"

  if [[ "$status" =~ $terminal_statuses ]]; then
    "${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" \
      --query 'builds[0].{BuildId:id,Status:buildStatus,ResolvedSourceVersion:resolvedSourceVersion}' --output table
    "${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" \
      --query 'builds[0].phases[].{Phase:phaseType,Status:phaseStatus,DurationSeconds:durationInSeconds}' --output table
    [[ "$status" == "SUCCEEDED" ]]
    exit
  fi

  elapsed=$(( $(date +%s) - start_time ))
  if (( elapsed >= timeout_seconds )); then
    printf 'Timed out after %s seconds while waiting for %s.\n' "$timeout_seconds" "$build_id" >&2
    exit 124
  fi

  sleep "$poll_seconds"
done
