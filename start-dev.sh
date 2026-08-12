#!/bin/zsh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

pids=()

cleanup() {
  echo
  echo "🛑 正在关闭所有 dev 进程..."
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null
  done
  echo "✅ 所有进程已关闭"
  exit 0
}
trap cleanup INT TERM

run_with_prefix() {
  local name="$1"
  local color="$2"
  local dir="$3"
  shift 3
  local cmd=("$@")

  (
    cd "$dir" || exit 1
    exec "${cmd[@]}"
  ) 2>&1 | while IFS= read -r line; do
    printf "%b[%s]%b %s\n" "$color" "$name" '\033[0m' "$line"
  done &
  pids+=("$!")
}

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BOLD='\033[1m'

echo "${BOLD}🚀 StoreHub Dev Environment 启动中...${RESET:-}"
echo "   📦 ai-store-api :3000  → ${MAGENTA}ai-store${RESET:-}  npm run start:debug"
echo "   📦 serverless   :3001  → ${YELLOW}sl${RESET:-}        npm run debug"
echo "   📦 uniapp H5    :5173? → ${CYAN}uniapp${RESET:-}     yarn dev:h5:dev"
echo "   📦 storehub-web :5173? → ${GREEN}web${RESET:-}          yarn dev"
echo
echo "   按 Ctrl+C 一次性关闭所有进程"
echo "────────────────────────────────────────────"

run_with_prefix "ai-store" "$MAGENTA" "$ROOT_DIR/ai-store-api"     npm run start:debug
run_with_prefix "sl"       "$YELLOW"  "$ROOT_DIR/storehub-servless" npm run debug
run_with_prefix "uniapp"   "$CYAN"    "$ROOT_DIR/storehub-uniapp"   yarn dev:h5:dev
run_with_prefix "web"      "$GREEN"   "$ROOT_DIR/storehub-web"      yarn dev

echo "✅ 所有服务已启动（等待各自输出 ready 信息）"
echo "────────────────────────────────────────────"

for pid in "${pids[@]}"; do
  wait "$pid"
done
