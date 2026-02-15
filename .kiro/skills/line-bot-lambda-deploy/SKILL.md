---
name: line-bot-lambda-deploy
description: Build, push, and deploy the LINE Bot Lambda container image in this repository. Use when asked to deploy Lambda, push images to ECR, verify deployed image digests, or fix Lambda update failures such as unsupported image manifest/media type errors.
---

# LINE Bot Lambda Deploy

## Overview

Use this skill for deterministic Lambda container deployment in this repo (`line-shop-bot`).
Prefer the bundled script to avoid manifest-format mistakes that break Lambda updates.

## Workflow

1. Validate prerequisites.
- Confirm AWS auth: `aws sts get-caller-identity`
- Confirm Docker daemon is running: `docker info`
- Confirm Terraform outputs are available: `terraform -chdir=terraform output`

2. Deploy with the script.
- Run: `./.kiro/skills/line-bot-lambda-deploy/scripts/deploy_lambda_dev.sh --tag <tag>`
- If no tag is provided, `latest` is used.

3. Verify result.
- Check Lambda status and resolved digest from script output.
- Optional manual check:
`aws lambda get-function --region ap-northeast-1 --function-name line-shop-bot-dev --query '{State:Configuration.State,LastUpdateStatus:Configuration.LastUpdateStatus,ResolvedImageUri:Code.ResolvedImageUri}' --output json`

## Guardrails

- Build image as a single-platform `linux/amd64` image with `--provenance=false --sbom=false --load`.
- Update Lambda with digest (`repo@sha256:...`), not only mutable tags.
- Do not assume `latest` has a Lambda-compatible manifest without verification.

## Troubleshooting

- If Lambda update fails with `image manifest ... not supported`:
  rebuild and push with this skill's script, then redeploy by digest.
- If ECR push fails due to auth:
  rerun AWS login and ECR login, then retry.
- If Terraform outputs are missing:
  initialize/select correct workspace or run from the repo with configured state.

## References

- Deployment failure patterns: `references/lambda-deploy-failures.md`
- Deployment script: `scripts/deploy_lambda_dev.sh`
