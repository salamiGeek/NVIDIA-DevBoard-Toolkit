#!/bin/bash
# GPIO守护进程测试脚本

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 定义RPC端口
PORT=8888

# 检查nc命令是否可用
if ! command -v nc &> /dev/null; then
    echo -e "${RED}错误: 未找到nc命令${NC}"
    echo "请安装netcat工具："
    echo "sudo apt-get install netcat"
    exit 1
fi

# 检查服务是否运行
echo -e "${YELLOW}检查GPIO守护进程服务状态...${NC}"
if ! systemctl is-active --quiet gpio-daemon.service; then
    echo -e "${RED}GPIO守护进程未运行${NC}"
    echo -e "尝试启动服务..."
    sudo systemctl start gpio-daemon.service
    
    if ! systemctl is-active --quiet gpio-daemon.service; then
        echo -e "${RED}无法启动GPIO守护进程${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}GPIO守护进程正在运行${NC}"

# 测试状态查询
echo -e "\n${YELLOW}测试状态查询...${NC}"
response=$(echo "status" | nc localhost $PORT)
echo -e "${BLUE}响应: ${response}${NC}"

# 测试正常模式
echo -e "\n${YELLOW}测试设置为正常模式...${NC}"
response=$(echo "normal" | nc localhost $PORT)
echo -e "${BLUE}响应: ${response}${NC}"

sleep 1

# 测试复位功能
echo -e "\n${YELLOW}测试复位功能...${NC}"
response=$(echo "reset" | nc localhost $PORT)
echo -e "${BLUE}响应: ${response}${NC}"

sleep 1

# 测试DFU模式
echo -e "\n${YELLOW}测试进入DFU模式...${NC}"
response=$(echo "dfu" | nc localhost $PORT)
echo -e "${BLUE}响应: ${response}${NC}"

sleep 1

# 恢复正常模式
echo -e "\n${YELLOW}恢复正常模式...${NC}"
response=$(echo "normal" | nc localhost $PORT)
echo -e "${BLUE}响应: ${response}${NC}"

echo -e "\n${GREEN}测试完成${NC}"
exit 0 