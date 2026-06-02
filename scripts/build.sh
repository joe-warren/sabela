#!/usr/bin/env bash
set -euo pipefail

# Builds and pushes both the Sabela and hub images to ECR (no rollout).
# To build, push, AND roll out the hub on the box, use infra/deploy-box.sh
# (add --with-sabela to also rebuild the per-user image).

source "$(dirname "$0")/../infra/.env"

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "=== Building and pushing Sabela ==="
docker build --platform linux/amd64 -t datahaskell/sabela .
docker tag datahaskell/sabela:latest "$ECR_SABELA:latest"
docker push "$ECR_SABELA:latest"

echo "=== Building and pushing Hub ==="
docker build --platform linux/amd64 -f sabela-hub/Dockerfile -t datahaskell/sabela-hub sabela-hub/
docker tag datahaskell/sabela-hub:latest "$ECR_HUB:latest"
docker push "$ECR_HUB:latest"

echo ""
echo "Images pushed. Roll out the hub on the box with: ./infra/deploy-box.sh"
