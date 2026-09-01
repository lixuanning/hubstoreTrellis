#!/bin/zsh
# 一次性启动 4 个 dev 服务：ai-store-api / serverless / uniapp / storehub-web
# 启动后会自动监听各服务日志，解析 ready 信号与端口，全部就绪后打印
# 服务地址表 + 持久化到 .dev-addresses.json

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT_DIR/.dev-logs"
ADDR_FILE="$ROOT_DIR/.dev-addresses.json"
STATE_DIR="$ROOT_DIR/.dev-state"

mkdir -p "$LOG_DIR" "$STATE_DIR"
rm -f "$LOG_DIR"/*.log "$STATE_DIR"/*
echo '{}' > "$ADDR_FILE"

pids=()
watcher_pid=""

cleanup() {
  echo
  echo "🛑 正在关闭所有 dev 进程..."
  if [ -n "$watcher_pid" ] && kill -0 "$watcher_pid" 2>/dev/null; then
    kill "$watcher_pid" 2>/dev/null || true
  fi
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null
  done
  rm -rf "$STATE_DIR"
  echo "✅ 所有进程已关闭"
  exit 0
}
trap cleanup INT TERM

# 获取本机 LAN IP（用于拼 network URL）
# macOS: ipconfig getifaddr en0；Linux: hostname -I
LAN_IP=""
get_lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
  else
    hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

# 服务元数据：name|logfile|default_port|ready_regex|port_re
# port_re 既要能匹配 Local 行也要能匹配 Network 行（vite 两种都会打）
SERVICES=(
  "ai-store-api|ai-store.log|3000|successfully started|:3000"
  "serverless|sl.log|3001|listening on port|3001"
  "uniapp|uniapp.log|5173|VITE.*ready in|Local:.*:([0-9]+)|Network:.*://([^/]+):([0-9]+)"
  "storehub-web|web.log|5174|VITE.*ready in|Local:.*:([0-9]+)|Network:.*://([^/]+):([0-9]+)"
)

# 初始化 state 文件
for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name _ def_port _ _ _ <<< "$svc"
  LAN_IP="$(get_lan_ip)"
  cat > "$STATE_DIR/$name" <<EOF
name=$name
port=$def_port
local_url=http://localhost:$def_port
network_url=http://$LAN_IP:$def_port
ready=false
EOF
done

write_addr_file() {
  local first=true
  LAN_IP="$(get_lan_ip)"
  {
    printf '{"updatedAt":"%s","lanIp":"%s","services":{' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LAN_IP"
    for svc in "${SERVICES[@]}"; do
      IFS='|' read -r name _ _ _ _ _ <<< "$svc"
      source "$STATE_DIR/$name"
      local ready_lc="$ready"
      if [ "$first" = true ]; then
        first=false
      else
        printf ','
      fi
      printf '"%s":{"localUrl":"http://localhost:%s","networkUrl":"%s","port":%s,"ready":%s}' \
        "$name" "$port" "$network_url" "$port" "$ready_lc"
    done
    printf '}}'
  } > "$ADDR_FILE"
}

print_summary() {
  local lan_ip
  lan_ip="$(get_lan_ip)"
  echo
  echo "────────────────────────────────────────────"
  echo "✅ 全部服务就绪（LAN IP: $lan_ip）"
  echo "┌────────────────┬───────────────────────────┬─────────────────────────────┐"
  echo "│ Service        │ Local                     │ Network                     │"
  echo "├────────────────┼───────────────────────────┼─────────────────────────────┤"
  for svc in "${SERVICES[@]}"; do
    IFS='|' read -r name _ _ _ _ _ <<< "$svc"
    source "$STATE_DIR/$name"
    printf "│ %-14s │ %-25s │ %-27s │\n" "$name" "http://localhost:$port" "$network_url"
  done
  echo "└────────────────┴───────────────────────────┴─────────────────────────────┘"
  echo "📋 地址文件：$ADDR_FILE"
  echo "   读取方式：cat $ADDR_FILE | jq .services.uniapp.networkUrl"
  echo "────────────────────────────────────────────"
}

run_with_prefix() {
  local name="$1"
  local color="$2"
  local dir="$3"
  local logfile="$4"
  shift 4
  local cmd=("$@")

  (
    cd "$dir" || exit 1
    exec "${cmd[@]}"
  ) 2>&1 | tee -a "$LOG_DIR/$logfile" | while IFS= read -r line; do
    printf "%b[%s]%b %s\n" "$color" "$name" '\033[0m' "$line"
  done &
  pids+=("$!")
}

# Watcher: 周期性扫描日志，更新 state
# 注意：必须用 function 而不是 ( ... ) & 子 shell，
#       zsh 在子 shell 中用 `local VAR; VAR=value` 会把赋值打到 stdout
watcher() {
  local TIMEOUT=30
  local START
  START=$(date +%s)
  local printed_summary=false
  local lan_ip="$(get_lan_ip)"

  while true; do
    local all_ready=true
    for svc in "${SERVICES[@]}"; do
      # zsh 数组切分（避免 background 函数中 `IFS='|' read ... <<<` 触发赋值打印 bug）
      local parts=("${(@s:|:)svc}")
      local name=$parts[1]
      local log=$parts[2]
      local def_port=$parts[3]
      local ready_re=$parts[4]
      local port_re=$parts[5]
      source "$STATE_DIR/$name"

      if [ "$ready" != "true" ] && [ -f "$LOG_DIR/$log" ]; then
        if grep -Eq "$ready_re" "$LOG_DIR/$log" 2>/dev/null; then
          # 提取纯数字端口（先按 port_re 匹配整段，再抓末尾数字）
          # 注意：必须用 `local VAR=$(...)` 合并写法，避免 zsh 在 background 函数 + 循环中
          #       将 `local VAR; VAR=value` 的赋值打到 stdout
          local extracted=$(grep -Eo "$port_re" "$LOG_DIR/$log" 2>/dev/null | tail -1 | grep -oE '[0-9]+$' | head -1)
          if [ -n "$extracted" ]; then
            port="$extracted"
          fi
          # vite 日志里同时有 Local 和 Network 两行，重新生成更精准的 URL
          local net_url=$(grep -Eo 'Network:[[:space:]]+http://[^[:space:]]+' "$LOG_DIR/$log" 2>/dev/null | tail -1 | sed 's/^Network:[[:space:]]*//' | sed 's:/*$::')
          if [ -n "$net_url" ]; then
            network_url="$net_url"
          else
            network_url="http://$lan_ip:$port"
          fi
          local local_url="http://localhost:$port"
          ready="true"
          cat > "$STATE_DIR/$name" <<EOF
name=$name
port=$port
local_url=$local_url
network_url=$network_url
ready=$ready
EOF
          echo "  ✓ $name ready ($local_url / $network_url)"
        fi
      fi

      if [ "$ready" != "true" ]; then
        all_ready=false
      fi
    done

    if [ "$all_ready" = "true" ]; then
      write_addr_file
      if [ "$printed_summary" = "false" ]; then
        print_summary
        printed_summary=true
      fi
      # watcher 继续运行保持 addr 文件最新；只打印一次
    fi

    local NOW=$(date +%s)
    local ELAPSED=$((NOW - START))
    if [ "$ELAPSED" -gt "$TIMEOUT" ] && [ "$printed_summary" = "false" ]; then
      echo
      echo "⚠️  ${TIMEOUT}s 等待超时（部分服务可能未就绪），打印当前状态："
      write_addr_file
      print_summary
      printed_summary=true
    fi

    sleep 1
  done
}
watcher &
watcher_pid=$!

# 启动横幅
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BOLD='\033[1m'
RESET='\033[0m'

echo "${BOLD}🚀 StoreHub Dev Environment 启动中...${RESET}"
echo "   📦 ai-store-api :3000  → ${MAGENTA}ai-store${RESET}  npm run start:debug"
echo "   📦 serverless   :3001  → ${YELLOW}sl${RESET}        npm run debug"
echo "   📦 uniapp H5    :5173? → ${CYAN}uniapp${RESET}     yarn dev:h5:dev"
echo "   📦 storehub-web :5174? → ${GREEN}web${RESET}        yarn dev"
echo
echo "   按 Ctrl+C 一次性关闭所有进程"
echo "   全部 ready 后会自动打印地址表 + 写 .dev-addresses.json"
echo "────────────────────────────────────────────"

run_with_prefix "ai-store" "$MAGENTA" "$ROOT_DIR/ai-store-api"      "ai-store.log" npm run start:debug
run_with_prefix "sl"       "$YELLOW"  "$ROOT_DIR/storehub-servless" "sl.log"       npm run debug
run_with_prefix "uniapp"   "$CYAN"    "$ROOT_DIR/storehub-uniapp"   "uniapp.log"   yarn dev:h5:dev
run_with_prefix "web"      "$GREEN"   "$ROOT_DIR/storehub-web"      "web.log"      yarn dev

echo "⏳ 等待各服务 ready（最多 30s）..."

for pid in "${pids[@]}"; do
  wait "$pid"
done
