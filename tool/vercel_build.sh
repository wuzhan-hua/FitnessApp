#!/usr/bin/env bash

set -euo pipefail

FLUTTER_ROOT="${HOME}/flutter"
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "缺少 SUPABASE_URL 或 SUPABASE_ANON_KEY 环境变量。" >&2
  echo "请在 Vercel Project Settings -> Environment Variables 中配置后再重新部署。" >&2
  exit 1
fi

flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
