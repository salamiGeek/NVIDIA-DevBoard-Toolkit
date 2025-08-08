#!/bin/bash
# GPIO守护进程编译和安装脚本

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否有root权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用root权限运行此脚本${NC}"
  echo "例如: sudo $0"
  exit 1
fi

echo -e "${YELLOW}开始编译和安装GPIO守护进程...${NC}"

# 检查libgpiod开发库是否已安装
if pkg-config --exists libgpiod 2>/dev/null; then
    echo -e "${GREEN}libgpiod开发库已安装，跳过安装步骤${NC}"
else
    # 安装依赖
    echo -e "${YELLOW}安装libgpiod依赖...${NC}"
    apt-get update
    apt-get install -y libgpiod-dev
    
    # 再次检查是否安装成功
    if ! pkg-config --exists libgpiod 2>/dev/null; then
        echo -e "${RED}错误: libgpiod开发库安装失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}libgpiod开发库安装成功${NC}"
fi

# 编译GPIO守护进程
echo -e "${YELLOW}编译GPIO守护进程...${NC}"
gcc -Wall -o gpio_daemon_new gpio_daemon.c -lgpiod

# 检查编译是否成功
if [ $? -ne 0 ]; then
  echo -e "${RED}编译失败，请检查错误信息${NC}"
  exit 1
fi

echo -e "${GREEN}编译成功!${NC}"

# 检查服务是否正在运行，如果是则先停止
if systemctl is-active --quiet gpio-daemon.service; then
    echo -e "${YELLOW}停止现有的GPIO守护进程服务...${NC}"
    systemctl stop gpio-daemon.service
    # 等待服务完全停止
    sleep 2
fi

# 复制可执行文件到系统目录
echo -e "${YELLOW}安装GPIO守护进程...${NC}"
cp gpio_daemon_new /usr/local/bin/gpio_daemon
chmod +x /usr/local/bin/gpio_daemon
# 删除临时文件
rm -f gpio_daemon_new

# 安装服务文件
echo -e "${YELLOW}安装系统服务...${NC}"
cp gpio-daemon.service /etc/systemd/system/

# 重新加载systemd
echo -e "${YELLOW}重新加载systemd配置...${NC}"
systemctl daemon-reload

# 启用服务
echo -e "${YELLOW}启用GPIO守护进程服务...${NC}"
systemctl enable gpio-daemon.service

# 启动服务
echo -e "${YELLOW}启动GPIO守护进程服务...${NC}"
systemctl start gpio-daemon.service

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${NC}"
systemctl status gpio-daemon.service --no-pager

echo -e "${GREEN}GPIO守护进程安装完成！${NC}"
echo -e "${YELLOW}可以使用以下命令控制服务:${NC}"
echo "  systemctl start gpio-daemon.service    # 启动服务"
echo "  systemctl stop gpio-daemon.service     # 停止服务"
echo "  systemctl restart gpio-daemon.service  # 重启服务"
echo "  systemctl status gpio-daemon.service   # 查看服务状态"
echo -e "${YELLOW}可以使用以下命令测试RPC接口:${NC}"
echo "  echo -n 'status' | nc localhost 8888      # 查询当前状态"
echo "  echo -n 'normal' | nc localhost 8888      # 设置为正常运行状态"
echo "  echo -n 'reset'  | nc localhost 8888      # 复位单片机"
echo "  echo -n 'dfu'    | nc localhost 8888      # 进入DFU模式"
echo -e "${YELLOW}如需完整测试，可运行:${NC}"
echo "  ./test_gpio_daemon.sh"

exit 0 