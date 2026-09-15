#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

apply=false
if [[ "${1:-}" == "--apply" ]]; then
  apply=true
  shift
fi

if (( $# > 0 )); then
  printf 'Usage: %s [--apply]\n' "$0" >&2
  exit 2
fi

required_variables=(
  AWS_REGION
  STACK_NAME
  CODEBUILD_PROJECT_NAME
  GITHUB_REPOSITORY_URL
  GITHUB_BRANCH
  CODE_CONNECTION_ARN
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'Required environment variable is not set: %s\n' "$variable_name" >&2
    exit 1
  fi
done

CODEBUILD_IMAGE="${CODEBUILD_IMAGE:-aws/codebuild/standard:7.0}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-14}"

repository_id="${GITHUB_REPOSITORY_URL#https://github.com/}"
repository_id="${repository_id%.git}"
if [[ "$repository_id" == "$GITHUB_REPOSITORY_URL" || "$repository_id" != */* ]]; then
  printf 'GITHUB_REPOSITORY_URL must be an HTTPS GitHub clone URL.\n' >&2
  exit 1
fi

aws_cli=(aws)
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_cli+=(--profile "$AWS_PROFILE")
fi
aws_cli+=(--region "$AWS_REGION")

account_id="$("${aws_cli[@]}" sts get-caller-identity --query Account --output text)"
caller_arn="$("${aws_cli[@]}" sts get-caller-identity --query Arn --output text)"

parameters=(
  "ProjectName=$CODEBUILD_PROJECT_NAME"
  "GitHubRepositoryUrl=$GITHUB_REPOSITORY_URL"
  "GitHubBranch=$GITHUB_BRANCH"
  "CodeConnectionArn=$CODE_CONNECTION_ARN"
  "BuildImage=$CODEBUILD_IMAGE"
  "LogRetentionDays=$LOG_RETENTION_DAYS"
)

deploy_command=(
  "${aws_cli[@]}" cloudformation deploy
  --template-file infrastructure/codebuild-stack.yml
  --stack-name "$STACK_NAME"
  --capabilities CAPABILITY_IAM
  --parameter-overrides "${parameters[@]}"
  --tags Lab=aws-devops-demo
  --no-fail-on-empty-changeset
)

printf 'AWS account: %s\n' "$account_id"
printf 'Caller ARN:  %s\n' "$caller_arn"
printf 'AWS region:  %s\n' "$AWS_REGION"
printf 'Stack name:  %s\n' "$STACK_NAME"
printf 'Project:     %s\n' "$CODEBUILD_PROJECT_NAME"
printf 'Command:\n'
printf '  %q' "${deploy_command[@]}"
printf '\n'

if [[ "$apply" != true ]]; then
  printf 'Dry run only. Re-run with --apply after reviewing the account, stack, and command.\n'
  exit 0
fi

printf 'Deploying the reviewed stack...\n'
"${deploy_command[@]}"
