# Known CI Failures

## Deploy AgentCore Runtime

Error:
- `uv is required for direct_code_deploy deployment but was not found`

Root cause:
- `direct_code_deploy` requires `uv`, but workflow installed only AgentCore toolkit.

Fix:
- Install `uv` alongside toolkit in workflow.

## Deploy to ECR -> Update Lambda function

Error:
- `The image manifest, config or layer media type ... is not supported`

Root cause:
- Image pushed in a format Lambda cannot consume (e.g., index/attestation artifacts).

Fix:
1. Build single-platform image with:
   - `docker buildx build --platform linux/amd64 --provenance=false --sbom=false --load`
2. Push image to ECR.
3. Resolve digest and update Lambda with `repo@sha256:...`.

## GitHub CLI GraphQL noise on issue/pr view/edit

Error:
- `Projects (classic) is being deprecated ...`

Impact:
- Some `gh issue view` or `gh pr edit` commands may fail even when target exists.

Workaround:
- Use `--json` variants for issue view when possible.
- Use `gh api repos/<owner>/<repo>/pulls/<number> -X PATCH` for PR body updates.
