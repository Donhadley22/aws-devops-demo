#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

build_id="${1:-}"
if [[ "$build_id" == "--build-id" ]]; then
  build_id="${2:-}"
  shift 2
else
  shift $(( $# > 0 ? 1 : 0 ))
fi

if [[ -z "$build_id" || $# -ne 0 ]]; then
  printf 'Usage: %s BUILD_ID\n' "$0" >&2
  exit 2
fi

aws_cli=(aws)
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_cli+=(--profile "$AWS_PROFILE")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  aws_cli+=(--region "$AWS_REGION")
fi

exists="$("${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" --query 'length(builds)' --output text)"
if [[ "$exists" != "1" ]]; then
  printf 'Build was not found: %s\n' "$build_id" >&2
  exit 1
fi

printf 'Build evidence\n'
"${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" \
  --query 'builds[0].{BuildId:id,OverallStatus:buildStatus,ResolvedSourceCommit:resolvedSourceVersion,StartTime:startTime,CompletionTime:endTime,LogGroup:logs.groupName,LogStream:logs.streamName,ArtifactLocation:artifacts.location}' \
  --output table

printf 'Phase evidence\n'
"${aws_cli[@]}" codebuild batch-get-builds --ids "$build_id" \
  --query 'builds[0].phases[].{Phase:phaseType,Status:phaseStatus,StartTime:startTime,EndTime:endTime,DurationSeconds:durationInSeconds}' \
  --output table
