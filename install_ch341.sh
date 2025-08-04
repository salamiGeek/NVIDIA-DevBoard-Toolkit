#!/bin/bash
# CH341 驱动自动安装脚本 (Ubuntu 22.04)
# 用法：sudo ./install_ch341.sh /path/to/ch341.ko

# 检查参数
if [ $# -ne 1 ]; then
    echo "错误：请指定 ch341.ko 文件路径"
    echo "用法: sudo $0 /path/to/ch341.ko"
    exit 1
fi

KO_PATH=$1
KERNEL_VERSION=$(uname -r)
TARGET_DIR="/lib/modules/$KERNEL_VERSION/kernel/drivers/usb/serial"
UDEV_RULE="/etc/udev/rules.d/99-ch341.rules"
MODULES_FILE="/etc/modules"
SCRIPT_DIR="$(dirname "$0")"
RULES_SRC="${SCRIPT_DIR}/rules.d/99-ch341.rules"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用 sudo 执行此脚本"
    exit 1
fi

# 检查 .ko 文件是否存在
if [ ! -f "$KO_PATH" ]; then
    echo "错误：文件 $KO_PATH 不存在"
    exit 1
fi

# 检查 udev 规则文件是否存在
if [ ! -f "$RULES_SRC" ]; then
    echo "错误：udev 规则文件 $RULES_SRC 不存在"
    exit 1
fi

echo "=== 步骤 1：准备系统环境 ==="
apt update
systemctl stop brltty
systemctl disable brltty
apt remove -y brltty
apt autoremove -y
apt install -y unzip build-essential linux-headers-$KERNEL_VERSION

echo "=== 步骤 2：安装驱动模块 ==="
# 创建目标目录
mkdir -p $TARGET_DIR
# 复制驱动文件
cp -v $KO_PATH $TARGET_DIR/
# 修复模块权限
chmod 644 $TARGET_DIR/ch341.ko
# 更新模块依赖
depmod -a

printf "\n=== 步骤 3：配置自动加载 ==="
# 检查模块是否已在配置中
if ! grep -q "ch341" $MODULES_FILE; then
    echo -e "\n# CH341 串口驱动" >> $MODULES_FILE
    echo "ch341" >> $MODULES_FILE
    echo "已添加 ch341 到 $MODULES_FILE"
else
    echo -e "\nch341 已在 $MODULES_FILE 中"
fi

printf "\n=== 步骤 4：配置 Udev 规则 ==="
# 复制 udev 规则文件
cp -v "$RULES_SRC" "$UDEV_RULE"
echo "已安装 udev 规则：$UDEV_RULE"

printf "\n=== 步骤 5：加载驱动并验证 ==="
udevadm control --reload-rules
udevadm trigger
modprobe ch341

printf "\n\n=== 验证安装 ==="
echo -e "\n1. 查看模块:"
lsmod | grep ch341

echo -e "\n2. 检查设备节点:"
ls -l /dev/ttyCH341*

echo -e "\n3. 检查内核消息:"
dmesg | grep ch341 -i | tail -n 5

printf "\n=== 安装完成 ==="
echo -e "\n请重新插拔 CH341 设备以应用配置"
echo "设备路径：/dev/ttyCH341* (全局可读写)"
