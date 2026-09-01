#!/bin/zsh
# 单元测试 start-dev.sh 的 watcher 逻辑
# 直接 import 关键的 SERVICES 数组 + watch loop，在 mock 日志上跑

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

LOG_DIR="$TEST_DIR/.dev-logs"
STATE_DIR="$TEST_DIR/.dev-state"
ADDR_FILE="$TEST_DIR/.dev-addresses.json"
mkdir -p "$LOG_DIR" "$STATE_DIR"

get_lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
  else
    hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

# 内联 SERVICES 数组（与 start-dev.sh 保持一致）
SERVICES=(
  "ai-store-api|ai-store.log|3000|successfully started|:3000"
  "serverless|sl.log|3001|listening on port|3001"
  "uniapp|uniapp.log|5173|VITE.*ready in|Local:.*:([0-9]+)|Network:.*://([^/]+):([0-9]+)"
  "storehub-web|web.log|5174|VITE.*ready in|Local:.*:([0-9]+)|Network:.*://([^/]+):([0-9]+)"
)

# 初始化 state
LAN_IP="$(get_lan_ip)"
echo "LAN IP detected: $LAN_IP"
for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name _ def_port _ _ _ <<< "$svc"
  cat > "$STATE_DIR/$name" <<EOF
name=$name
port=$def_port
local_url=http://localhost:$def_port
network_url=http://$LAN_IP:$def_port
ready=false
EOF
done

# 写入 mock 日志
cat > "$LOG_DIR/ai-store.log" <<EOF
[Nest] LOG [NestFactory] Starting Nest application...
[Nest] LOG [RouterExplorer] Mapped {/, GET}
[Nest] LOG [NestApplication] Nest application successfully started
EOF

cat > "$LOG_DIR/sl.log" <<EOF
Pagoda Serverless starting...
Server listening on port 3001
EOF

cat > "$LOG_DIR/uniapp.log" <<EOF
VITE v5.4.10  ready in 1234 ms
➜  Local:   http://localhost:5175/
➜  Network: http://192.168.1.10:5175/
EOF

cat > "$LOG_DIR/web.log" <<EOF
VITE v5.4.10  ready in 567 ms
➜  Local:   http://localhost:5180/
➜  Network: http://192.168.1.10:5180/
EOF

# 跑 watcher 一次
write_addr_file() {
  local first=true
  local lan_ip
  lan_ip="$(get_lan_ip)"
  {
    printf '{"updatedAt":"%s","lanIp":"%s","services":{' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$lan_ip"
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

# 模拟一次扫描
for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name log def_port ready_re port_re <<< "$svc"
  source "$STATE_DIR/$name"

  if [ "$ready" != "true" ] && [ -f "$LOG_DIR/$log" ]; then
    if grep -Eq "$ready_re" "$LOG_DIR/$log" 2>/dev/null; then
      local extracted
      extracted=$(grep -Eo "$port_re" "$LOG_DIR/$log" 2>/dev/null | tail -1 | grep -oE '[0-9]+$' | head -1)
      if [ -n "$extracted" ]; then
        port="$extracted"
      fi
      local net_url
      net_url=$(grep -Eo 'Network:[[:space:]]+http://[^[:space:]]+' "$LOG_DIR/$log" 2>/dev/null | tail -1 | sed 's/^Network:[[:space:]]*//' | sed 's:/*$::')
      if [ -n "$net_url" ]; then
        network_url="$net_url"
      else
        network_url="http://$LAN_IP:$port"
      fi
      local_url="http://localhost:$port"
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
done

write_addr_file

echo
echo "===== ADDR FILE ====="
cat "$ADDR_FILE" | jq .
echo
echo "===== VALIDATION ====="
expected_ports='{"ai-store-api":3000,"serverless":3001,"uniapp":5175,"storehub-web":5180}'
actual_ports=$(cat "$ADDR_FILE" | jq -c '.services | with_entries(.value = .value.port)')
echo "expected: $expected_ports"
echo "actual:   $actual_ports"
if [ "$expected_ports" = "$actual_ports" ]; then
  echo "✅ PASS: 端口全部解析正确"
else
  echo "❌ FAIL: 端口解析错误"
  exit 1
fi

# 校验 Network URL 包含真实 LAN IP
uniapp_net=$(cat "$ADDR_FILE" | jq -r '.services.uniapp.networkUrl')
storehub_net=$(cat "$ADDR_FILE" | jq -r '.services["storehub-web"].networkUrl')
echo "uniapp networkUrl:       $uniapp_net"
echo "storehub-web networkUrl: $storehub_net"
if [[ "$uniapp_net" == "http://192.168.1.10:5175" ]] && [[ "$storehub_net" == "http://192.168.1.10:5180" ]]; then
  echo "✅ PASS: vite Network URL 解析正确（无尾斜杠）"
else
  echo "❌ FAIL: vite Network URL 解析错误"
  exit 1
fi

# 校验 nest/slr 没有 Network 行时用 LAN IP 兜底
api_net=$(cat "$ADDR_FILE" | jq -r '.services["ai-store-api"].networkUrl')
sl_net=$(cat "$ADDR_FILE" | jq -r '.services.serverless.networkUrl')
echo "ai-store-api networkUrl: $api_net"
echo "serverless networkUrl:   $sl_net"
LAN_IP_NOW="$(get_lan_ip)"
if [[ "$api_net" == "http://$LAN_IP_NOW:3000" ]] && [[ "$sl_net" == "http://$LAN_IP_NOW:3001" ]]; then
  echo "✅ PASS: 非 vite 服务用 LAN IP 兜底"
else
  echo "❌ FAIL: 兜底 URL 错误"
  exit 1
fi

ready_count=$(cat "$ADDR_FILE" | jq '[.services[] | select(.ready==true)] | length')
if [ "$ready_count" = "4" ]; then
  echo "✅ PASS: 4/4 服务 ready"
else
  echo "❌ FAIL: ready count = $ready_count"
  exit 1
fi
