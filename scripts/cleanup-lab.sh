#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

apply=false
stack_name=""

while (( $# > 0 )); do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --stack-name)
      stack_name="${2:-}"
      shift 2
      ;;
    *)
      if [[ -z "$stack_name" ]]; then
        stack_name="$1"
        shift
      else
        printf 'Usage: %s --stack-name EXACT_STACK_NAME [--apply]\n' "$0" >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$stack_name" ]]; then
  printf 'The exact stack name is required.\n' >&2
  exit 1
fi

aws_cli=(aws)
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_cli+=(--profile "$AWS_PROFILE")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  aws_cli+=(--region "$AWS_REGION")
fi

lab_tag="$("${aws_cli[@]}" cloudformation describe-stacks --stack-name "$stack_name" \
  --query "Stacks[0].Tags[?Key=='Lab'].Value | [0]" --output text)"
if [[ "$lab_tag" != "aws-devops-demo" ]]; then
  printf 'Refusing cleanup: stack %s does not have Lab=aws-devops-demo.\n' "$stack_name" >&2
  exit 1
fi

artifact_bucket="$("${aws_cli[@]}" cloudformation describe-stacks --stack-name "$stack_name" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactBucketName'].OutputValue | [0]" --output text)"
if [[ -z "$artifact_bucket" || "$artifact_bucket" == "None" ]]; then
  printf 'Refusing cleanup: the stack artifact bucket output could not be resolved.\n' >&2
  exit 1
fi

printf 'Stack:           %s\n' "$stack_name"
printf 'Artifact bucket: %s\n' "$artifact_bucket"
printf 'Cleanup scope:   only the versioned objects in this bucket and this CloudFormation stack\n'

if [[ "$apply" != true ]]; then
  printf 'Dry run only. The apply operation would empty this exact versioned bucket, then run:\n'
  printf '  %q' "${aws_cli[@]}" cloudformation delete-stack --stack-name "$stack_name"
  printf '\nRe-run with --apply to continue to an interactive confirmation.\n'
  exit 0
fi

read -r -p "Type the exact stack name to delete it and its lab resources: " confirmation
if [[ "$confirmation" != "$stack_name" ]]; then
  printf 'Confirmation did not match; nothing was deleted.\n' >&2
  exit 1
fi

delete_version_kind() {
  local query="$1"
  local objects
  local delete_payload

  while true; do
    objects="$("${aws_cli[@]}" s3api list-object-versions --bucket "$artifact_bucket" \
      --max-items 100 --query "$query" --output json)"
    if [[ "$objects" == "[]" || "$objects" == "null" ]]; then
      break
    fi
    delete_payload="$(printf '{"Objects":%s,"Quiet":true}' "$objects")"
    "${aws_cli[@]}" s3api delete-objects --bucket "$artifact_bucket" --delete "$delete_payload" >/dev/null
  done
}

printf 'Deleting object versions from the exact lab artifact bucket...\n'
delete_version_kind 'Versions[].{Key:Key,VersionId:VersionId}'
delete_version_kind 'DeleteMarkers[].{Key:Key,VersionId:VersionId}'

printf 'Deleting stack %s...\n' "$stack_name"
"${aws_cli[@]}" cloudformation delete-stack --stack-name "$stack_name"
"${aws_cli[@]}" cloudformation wait stack-delete-complete --stack-name "$stack_name"
printf 'Stack deletion completed.\n'
