# Lambda Deploy Failure Patterns

## 1. Unsupported image manifest/media type

Symptom:
- `InvalidParameterValueException`
- `The image manifest, config or layer media type ... is not supported`

Likely cause:
- Multi-arch index or attestations pushed by default build settings.

Fix:
1. Build single-platform amd64 image:
   - `docker buildx build --platform linux/amd64 --provenance=false --sbom=false --load ...`
2. Push to ECR.
3. Resolve digest via `aws ecr describe-images`.
4. Update Lambda with `repo@sha256:digest`.

## 2. ECR auth failure

Symptom:
- `no basic auth credentials`
- `denied: requested access to the resource is denied`

Fix:
- `aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <registry>`

## 3. Wrong function/repo selected

Symptom:
- update succeeds but wrong environment reflects changes.

Fix:
- Read values from Terraform outputs in this repo:
  - `terraform -chdir=terraform output -raw ecr_repository_url`
  - `terraform -chdir=terraform output -raw lambda_function_name`

## 4. Push succeeded but Lambda still old image

Likely cause:
- tag reused without digest pinning or stale CI reference.

Fix:
- Always update Lambda with digest URI.
