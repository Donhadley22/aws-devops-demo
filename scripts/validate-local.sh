#!/usr/bin/env bash

set -euo pipefail

printf '[validate] Checking JavaScript syntax...\n'
npm run check

printf '[validate] Running Jest tests...\n'
npm test

printf '[validate] Building application files...\n'
npm run build

if command -v cfn-lint >/dev/null 2>&1; then
  printf '[validate] Running cfn-lint against both CloudFormation templates...\n'
  cfn-lint --format json --regions "${AWS_REGION:-eu-west-1}" \
    infrastructure/application.yml infrastructure/codebuild-stack.yml
else
  printf '[validate] cfn-lint is not installed; local CloudFormation schema validation was skipped.\n'
  printf '[validate] AWS CloudFormation validate-template requires credentials and is intentionally not called automatically.\n'
fi

printf '[validate] Local validation complete.\n'
