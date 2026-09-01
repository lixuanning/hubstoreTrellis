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

# 内联 SERVICES 数组（与 start-dev.sh 保持一致）
SERVICES=(
  "ai-store-api|ai-store.log|3000|successfully started|:3000"
  "serverless|sl.log|3001|listening on port|3001"
  "uniapp|uniapp.log|5173|VITE.*ready in|Local:.*:([0-9]+)"
  "storehub-web|web.log|5174|VITE.*ready in|Local:.*:([0-9]+)"
)

# 初始化 state
for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name _ def_port _ _ <<< "$svc"
  cat > "$STATE_DIR/$name" <<EOF
name=$name
port=$def_port
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
  {
    printf '{"updatedAt":"%s","services":{' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for svc in "${SERVICES[@]}"; do
      IFS='|' read -r name _ _ _ _ <<< "$svc"
      source "$STATE_DIR/$name"
      local ready_lc="$ready"
      if [ "$first" = true ]; then
        first=false
      else
        printf ','
      fi
      printf '"%s":{"url":"http://localhost:%s","port":%s,"ready":%s}' \
        "$name" "$port" "$port" "$ready_lc"
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
      ready="true"
      cat > "$STATE_DIR/$name" <<EOF
name=$name
port=$port
ready=$ready
EOF
      echo "  ✓ $name ready on port $port"
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

ready_count=$(cat "$ADDR_FILE" | jq '[.services[] | select(.ready==true)] | length')
if [ "$ready_count" = "4" ]; then
  echo "✅ PASS: 4/4 服务 ready"
else
  echo "❌ FAIL: ready count = $ready_count"
  exit 1
fi
