#!/usr/bin/env bash
set -euo pipefail
# Build + push the hub (and optionally the per-user sabela) image, then have the
# box pull and restart the hub via SSM, and (by default) tear down per-user
# notebook containers that are not on the current sabela image so every account
# respawns on the new image on next load. No SSH/keys needed.
#   ./infra/deploy-box.sh                  # hub only; recycle stale notebooks
#   ./infra/deploy-box.sh --with-sabela    # also rebuild the per-user image
#   ./infra/deploy-box.sh --keep-sessions  # leave running notebooks alone
source "$(dirname "$0")/.env"
: "${AWS_REGION:?}"; : "${ECR_REGISTRY:?}"; : "${ECR_HUB:?}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WITH_SABELA=0
TEARDOWN=1
for arg in "$@"; do
  case "$arg" in
    --with-sabela)   WITH_SABELA=1 ;;
    --keep-sessions) TEARDOWN=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "=== build + push hub image ==="
docker build --platform linux/amd64 -f "$ROOT/sabela-hub/Dockerfile" \
  -t datahaskell/sabela-hub "$ROOT/sabela-hub"
docker tag datahaskell/sabela-hub:latest "$ECR_HUB:latest"
docker push "$ECR_HUB:latest"

PULLS="\"docker pull $ECR_HUB:latest\""
if [ "$WITH_SABELA" = 1 ]; then
  : "${ECR_SABELA:?}"
  echo "=== build + push sabela image ==="
  docker build --platform linux/amd64 -t datahaskell/sabela "$ROOT"
  docker tag datahaskell/sabela:latest "$ECR_SABELA:latest"
  docker push "$ECR_SABELA:latest"
  PULLS="$PULLS,\"docker pull $ECR_SABELA:latest\""
fi

IID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names sabela-box \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text --region "$AWS_REGION")
if [ -z "$IID" ] || [ "$IID" = "None" ]; then
  echo "No running box in ASG 'sabela-box'. Run ./infra/setup-ec2.sh first." >&2
  exit 1
fi

echo "=== SSM pull + restart on $IID ==="
LOGIN="aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

# By default, remove per-user notebook containers whose image differs from the
# current sabela:latest, so the hub respawns them on the new image. This is a
# no-op when the sabela image is unchanged (every container already matches).
TEARDOWN_CMD=""
if [ "$TEARDOWN" = 1 ]; then
  : "${ECR_SABELA:?}"
  RECYCLE="S=\$(docker image inspect ${ECR_SABELA}:latest --format '{{.Id}}' 2>/dev/null) && for c in \$(docker ps --filter name=sabela-user --format '{{.Names}}'); do [ \$(docker inspect \$c --format '{{.Image}}') = \$S ] || docker rm -f \$c; done; true"
  TEARDOWN_CMD=",\"echo === recycling stale notebook containers ===\",\"$RECYCLE\""
fi

CMDS="[\"$LOGIN\",$PULLS,\"systemctl restart sabela-hub\",\"sleep 3\",\"systemctl is-active sabela-hub\",\"curl -fsS http://localhost:8080/_hub/health\"$TEARDOWN_CMD]"
CID=$(aws ssm send-command --instance-ids "$IID" --document-name AWS-RunShellScript \
  --comment "sabela box deploy" --parameters "commands=$CMDS" \
  --query 'Command.CommandId' --output text --region "$AWS_REGION")
aws ssm wait command-executed --command-id "$CID" --instance-id "$IID" \
  --region "$AWS_REGION" 2>/dev/null || true
aws ssm get-command-invocation --command-id "$CID" --instance-id "$IID" \
  --query '{Status:Status,Out:StandardOutputContent,Err:StandardErrorContent}' \
  --output json --region "$AWS_REGION"

echo ""
if [ "$TEARDOWN" = 1 ]; then
  echo "Done. Hub restarted and stale notebook containers were torn down, so every"
  echo "account respawns on the new image on next load. Notebook docs are preserved;"
  echo "only live kernel state for those sessions resets. Use --keep-sessions to skip."
else
  echo "Done (--keep-sessions). New sessions use the new image; existing user"
  echo "containers keep the old one until reaped (hub restart re-attaches them)."
fi
