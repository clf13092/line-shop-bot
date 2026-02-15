# AgentCore CI Runbook

## Target files

- `.github/workflows/deploy-agentcore.yml`
- `agentcore/.bedrock_agentcore.yaml`
- `agentcore/src/main.py`

## Baseline checks

1. Workflow auth
- OIDC role must have permissions for AgentCore deploy APIs and related resources.

2. Tooling
- Python setup done (`actions/setup-python`)
- `pip install uv bedrock-agentcore-starter-toolkit`

3. Working directory
- Deploy command runs with `working-directory: agentcore`

4. Config compatibility
- `.bedrock_agentcore.yaml` has valid `entrypoint`, `deployment_type`, and AWS region/account.

## Common errors and fixes

### `uv is required for direct_code_deploy deployment but was not found`

Cause:
- CLI mode requires `uv` in runner environment.

Fix:
- Install `uv` in workflow before deploy.

### Runtime deploy works locally but fails in CI

Likely causes:
- Missing dependency (`uv` / wrong CLI package)
- Wrong IAM role assumptions in workflow
- Mismatch between workflow cwd and config path

Fix order:
1. Verify install step and versions.
2. Verify `working-directory` and paths.
3. Verify IAM role permissions.
4. Re-run with failed-step logs.
