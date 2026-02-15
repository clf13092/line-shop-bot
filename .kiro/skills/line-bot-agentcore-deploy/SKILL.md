---
name: line-bot-agentcore-deploy
description: Deploy and troubleshoot the AgentCore Runtime for this repository. Use when working on `agentcore/`, fixing `deploy-agentcore.yml`, diagnosing CI failures in AgentCore deployment, or validating `.bedrock_agentcore.yaml` and direct_code_deploy prerequisites.
---

# LINE Bot AgentCore Deploy

## Overview

Use this skill to deploy `agentcore/` safely in local and CI contexts.
Focus on preventing known failures in GitHub Actions, especially missing `uv` for `direct_code_deploy`.

## Workflow

1. Validate runtime config and credentials.
- Confirm AWS auth: `aws sts get-caller-identity`
- Confirm config file exists: `agentcore/.bedrock_agentcore.yaml`
- Confirm entrypoint exists: `agentcore/src/main.py`

2. Validate CLI prerequisites.
- Ensure `agentcore` CLI is installed.
- Ensure `uv` is installed when `deployment_type: direct_code_deploy`.

3. Deploy AgentCore runtime.
- Local deploy:
  - `cd agentcore`
  - `agentcore deploy --auto-update-on-conflict`

4. Verify deployment outputs.
- Check runtime ARN and deployment logs in CLI output.
- Confirm expected runtime values in `.bedrock_agentcore.yaml`.

## CI Guidance

For `.github/workflows/deploy-agentcore.yml`:
- Install both `bedrock-agentcore-starter-toolkit` and `uv` before deploy.
- Keep `working-directory: agentcore` for deploy step.
- Optionally print versions (`uv --version`, `agentcore --version`) for faster triage.

## Known Failure Pattern

- Error:
  - `uv is required for direct_code_deploy deployment but was not found`
- Fix:
  - Add `pip install uv bedrock-agentcore-starter-toolkit` in workflow setup.

## References

- AgentCore CI runbook: `references/agentcore-ci-runbook.md`
