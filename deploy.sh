#!/bin/bash
# Deploy backend by building on the VPS (native amd64) — no Mac QEMU.
#
#   ./deploy.sh              # rsync → docker build on VPS → restart container
#   LOCAL=1 ./deploy.sh      # Mac buildx --platform linux/amd64 --push
#
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-yashchauhan008/retailos-server:latest}"
SSH_HOST="${SSH_HOST:-187.52.116.113}"
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
REMOTE_DIR="${REMOTE_DIR:-/root/retailos}"
REMOTE_BUILD="${REMOTE_BUILD:-${REMOTE_DIR}/build}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20 -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}")

if [ "${LOCAL:-0}" = "1" ]; then
  echo "LOCAL=1 — building on this Mac via buildx (slow / fragile)"
  docker buildx build \
    --platform linux/amd64 \
    -f Dockerfile \
    -t "${IMAGE}" \
    --push .
  echo "Pushed ${IMAGE}. On VPS run: cd ~/retailos && bash server-up.sh"
  exit 0
fi

echo "==> Syncing source → ${SSH_USER}@${SSH_HOST}:${REMOTE_BUILD}"
"${SSH[@]}" "mkdir -p $(printf '%q' "$REMOTE_BUILD")"
rsync -az --delete \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=20 -p ${SSH_PORT}" \
  --exclude node_modules \
  --exclude .git \
  --exclude /logs \
  --exclude /files \
  --exclude /tmp \
  --exclude '*.log' \
  --exclude .env \
  --exclude .env.prod \
  --exclude .DS_Store \
  --exclude dist \
  ./ "${SSH_USER}@${SSH_HOST}:${REMOTE_BUILD}/"

echo "==> Building ${IMAGE} on VPS (native amd64)"
"${SSH[@]}" "docker build -f $(printf '%q' "${REMOTE_BUILD}/Dockerfile") -t $(printf '%q' "$IMAGE") $(printf '%q' "$REMOTE_BUILD")"

echo "==> Restarting retailos-api (use local image, do not pull Hub)"
"${SSH[@]}" "cd $(printf '%q' "$REMOTE_DIR") && sed -i 's/pull_policy: always/pull_policy: never/' retailos-server-compose.yaml && PULL=0 bash server-up.sh"

echo "==> Status"
"${SSH[@]}" "docker ps --filter name=retailos- --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

echo
echo "Done. Built and restarted on VPS."
echo "Optional Hub backup (needs docker login on VPS):  ssh ${SSH_USER}@${SSH_HOST} docker push ${IMAGE}"
