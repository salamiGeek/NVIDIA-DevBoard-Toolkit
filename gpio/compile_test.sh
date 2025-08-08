#!/bin/bash
# GPIO守护进程编译和测试脚本

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始编译GPIO守护进程...${NC}"

# 检查libgpiod开发库是否已安装
if ! pkg-config --exists libgpiod 2>/dev/null; then
    echo -e "${RED}警告: 未检测到libgpiod开发库${NC}"
    echo -e "${YELLOW}在实际设备上，请先安装libgpiod-dev:${NC}"
    echo "sudo apt-get update"
    echo "sudo apt-get install -y libgpiod-dev"
    echo ""
    echo -e "${YELLOW}在当前环境中继续编译（可能会有错误）...${NC}"
fi

# 编译GPIO守护进程
echo -e "${YELLOW}编译GPIO守护进程...${NC}"
gcc -Wall -o gpio_daemon gpio_daemon.c -lgpiod

# 检查编译结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}编译成功!${NC}"
    
    # 设置可执行权限
    chmod +x gpio_daemon
    
    echo -e "${YELLOW}GPIO守护进程可执行文件已创建${NC}"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "1. 前台运行: ./gpio_daemon -f"
    echo "2. 后台运行: sudo ./gpio_daemon"
    echo ""
    echo -e "${YELLOW}测试RPC接口:${NC}"
    echo "echo 'status' | nc localhost 8888  # 查询状态"
    echo "echo 'normal' | nc localhost 8888  # 设置为正常模式"
    echo "echo 'reset'  | nc localhost 8888  # 复位单片机"
    echo "echo 'dfu'    | nc localhost 8888  # 进入DFU模式"
    echo ""
    echo -e "${YELLOW}如需完整测试，可运行:${NC}"
    echo "./test_gpio_daemon.sh"
else
    echo -e "${RED}编译失败!${NC}"
    echo -e "${YELLOW}可能的原因:${NC}"
    echo "1. libgpiod开发库未安装"
    echo "2. 代码存在语法错误"
    echo "3. 缺少必要的头文件"
    echo ""
    echo -e "${YELLOW}解决方案:${NC}"
    echo "1. 安装libgpiod开发库: sudo apt-get install -y libgpiod-dev"
    echo "2. 检查代码语法"
    echo "3. 确保gpiod.h头文件可用"
fi

exit 0 