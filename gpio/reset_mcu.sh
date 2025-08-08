#!/usr/bin/env bash
# 仅用于复位MCU的简易脚本
# 依赖: nc (netcat)

set -euo pipefail

HOST="localhost"
PORT=8888

usage() {
  echo "用法: $0 [-H host] [-p port]"
  echo "  -H host   服务器地址，默认: localhost"
  echo "  -p port   服务器端口，默认: 8888"
}

# 依赖检查
if ! command -v nc >/dev/null 2>&1; then
  echo "错误: 未找到 nc (netcat)，请先安装: sudo apt-get install -y netcat" >&2
  exit 1
fi

# 解析参数
while getopts ":H:p:h" opt; do
  case "$opt" in
    H) HOST="$OPTARG";;
    p) PORT="$OPTARG";;
    h) usage; exit 0;;
    *) usage; exit 2;;
  esac
done

send_reset() {
  echo -n "reset" | nc "$HOST" "$PORT"
}

resp=$(send_reset || true)
echo "$resp"

if ! echo "$resp" | grep -q "^OK:RESET"; then
  echo "警告: 复位命令未被确认，請检查gpio-daemon服务与连接" >&2
  exit 1
fi

exit 0 