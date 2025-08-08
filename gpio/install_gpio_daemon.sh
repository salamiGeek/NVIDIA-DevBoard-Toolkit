#!/bin/bash
# GPIO守护进程安装脚本

# 检查是否有root权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用root权限运行此脚本"
  exit 1
fi

# 安装依赖
echo "安装libgpiod依赖..."
apt-get update
apt-get install -y libgpiod-dev

# 编译GPIO守护进程
echo "编译GPIO守护进程..."
gcc -Wall -o gpio_daemon gpio_daemon.c -lgpiod

# 检查编译是否成功
if [ $? -ne 0 ]; then
  echo "编译失败，请检查错误信息"
  exit 1
fi

# 复制可执行文件到系统目录
echo "安装GPIO守护进程..."
cp gpio_daemon /usr/local/bin/
chmod +x /usr/local/bin/gpio_daemon

# 安装服务文件
echo "安装系统服务..."
cp gpio/gpio-daemon.service /etc/systemd/system/

# 重新加载systemd
systemctl daemon-reload

# 启用服务
systemctl enable gpio-daemon.service

# 启动服务
systemctl start gpio-daemon.service

echo "GPIO守护进程安装完成"
echo "可以使用以下命令检查服务状态："
echo "systemctl status gpio-daemon.service"

exit 0 