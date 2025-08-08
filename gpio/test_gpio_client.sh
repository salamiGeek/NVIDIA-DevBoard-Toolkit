#!/usr/bin/env bash
# Bash 版 GPIO 守护进程 RPC 测试客户端
# 依赖: nc (netcat)

set -euo pipefail

HOST="localhost"
PORT=8888
COMMAND=""
AUTO=0

usage() {
  cat <<EOF
用法: $0 [-H host] [-p port] [-c command] [-A]
  -H host     服务器地址，默认: localhost
  -p port     服务器端口，默认: 8888
  -c command  直接发送命令(status|normal|reset|dfu|test|test_exit)
  -A          运行自动测试序列
不带 -c/-A 进入交互模式，输入 exit 退出。
EOF
}

# 依赖检查
if ! command -v nc >/dev/null 2>&1; then
  echo "错误: 未找到 nc (netcat)，请先安装: sudo apt-get install -y netcat" >&2
  exit 1
fi

# 解析参数
while getopts ":H:p:c:A" opt; do
  case "$opt" in
    H) HOST="$OPTARG";;
    p) PORT="$OPTARG";;
    c) COMMAND="$OPTARG";;
    A) AUTO=1;;
    *) usage; exit 2;;
  esac
done

send_cmd() {
  local cmd="$1"
  # -n 避免追加换行
  # 某些系统 netcat 变种可能需要 -q 1 才能在发送后退出，这里尝试兼容
  if response=$(echo -n "$cmd" | nc "$HOST" "$PORT"); then
    echo "$response"
  else
    echo "发送失败: $cmd" >&2
    return 1
  fi
}

run_auto() {
  local seq=(
    status
    normal
    reset
    dfu
    normal
    test
    status
    test_exit
    status
  )
  echo "开始自动测试..."
  for cmd in "${seq[@]}"; do
    printf "命令: %-10s => " "$cmd"
    send_cmd "$cmd" || true
    sleep 0.3
  done
  echo "自动测试完成。"
}

run_interactive() {
  echo "进入交互模式。可用命令: status, normal, reset, dfu, test, test_exit, exit"
  while true; do
    read -rp "> " line || break
    line=${line//$'\r'/}
    line=${line//$'\n'/}
    [[ -z "$line" ]] && continue
    [[ "$line" == "exit" || "$line" == "quit" ]] && break
    send_cmd "$line" || true
  done
}

if [[ "$AUTO" -eq 1 ]]; then
  run_auto
  exit 0
fi

if [[ -n "$COMMAND" ]]; then
  send_cmd "$COMMAND"
  exit $?
fi

run_interactive 