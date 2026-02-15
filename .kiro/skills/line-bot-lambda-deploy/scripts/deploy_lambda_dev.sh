#!/usr/bin/env bash
set -euo pipefail

REGION="ap-northeast-1"
IMAGE_TAG="latest"
LOCAL_IMAGE="line-shop-bot"
PUSH_LATEST=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --tag <tag>         Image tag to push/deploy (default: latest)
  --region <region>   AWS region (default: ap-northeast-1)
  --push-latest       Also tag and push :latest
  -h, --help          Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --push-latest)
      PUSH_LATEST=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "[ERROR] Must run inside a git repository." >&2
  exit 1
fi

cd "$REPO_ROOT"

if [[ ! -d "lambda" || ! -d "terraform" ]]; then
  echo "[ERROR] Expected lambda/ and terraform/ in repo root: $REPO_ROOT" >&2
  exit 1
fi

echo "[INFO] Resolving Terraform outputs..."
ECR_URL="$(terraform -chdir=terraform output -raw ecr_repository_url)"
LAMBDA_FN="$(terraform -chdir=terraform output -raw lambda_function_name)"
ECR_REGISTRY="${ECR_URL%%/*}"
ECR_REPOSITORY="${ECR_URL##*/}"

IMAGE_URI_TAG="${ECR_URL}:${IMAGE_TAG}"

echo "[INFO] Building image (${LOCAL_IMAGE}:${IMAGE_TAG}) for linux/amd64..."
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  --load \
  -t "${LOCAL_IMAGE}:${IMAGE_TAG}" \
  ./lambda

echo "[INFO] Logging in to ECR (${ECR_REGISTRY})..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "[INFO] Tagging and pushing ${IMAGE_URI_TAG} ..."
docker tag "${LOCAL_IMAGE}:${IMAGE_TAG}" "$IMAGE_URI_TAG"
docker push "$IMAGE_URI_TAG"

if [[ "$PUSH_LATEST" -eq 1 && "$IMAGE_TAG" != "latest" ]]; then
  echo "[INFO] Also tagging and pushing ${ECR_URL}:latest ..."
  docker tag "${LOCAL_IMAGE}:${IMAGE_TAG}" "${ECR_URL}:latest"
  docker push "${ECR_URL}:latest"
fi

echo "[INFO] Resolving image digest for tag '${IMAGE_TAG}'..."
IMAGE_DIGEST="$(aws ecr describe-images \
  --region "$REGION" \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids imageTag="$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' \
  --output text)"

if [[ -z "$IMAGE_DIGEST" || "$IMAGE_DIGEST" == "None" ]]; then
  echo "[ERROR] Failed to resolve digest for ${ECR_REPOSITORY}:${IMAGE_TAG}" >&2
  exit 1
fi

IMAGE_URI_DIGEST="${ECR_URL}@${IMAGE_DIGEST}"

echo "[INFO] Updating Lambda (${LAMBDA_FN}) with ${IMAGE_URI_DIGEST} ..."
aws lambda update-function-code \
  --region "$REGION" \
  --function-name "$LAMBDA_FN" \
  --image-uri "$IMAGE_URI_DIGEST" \
  >/tmp/line-bot-lambda-update.json

aws lambda wait function-updated \
  --region "$REGION" \
  --function-name "$LAMBDA_FN"

echo "[INFO] Deployment complete."
aws lambda get-function \
  --region "$REGION" \
  --function-name "$LAMBDA_FN" \
  --query '{FunctionName:Configuration.FunctionName,State:Configuration.State,LastUpdateStatus:Configuration.LastUpdateStatus,ResolvedImageUri:Code.ResolvedImageUri}' \
  --output json
