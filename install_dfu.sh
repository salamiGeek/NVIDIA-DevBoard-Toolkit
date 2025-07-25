#!/bin/bash
set -e  # 任何命令失败时立即退出

# =================================================================
# DFU 工具独立安装脚本 (Ubuntu 22.04)
# 功能：
# 1. 安装 dfu-util 本地 deb 包
# 2. 配置 udev 规则
# 3. 验证安装结果
# =================================================================

# --------------------- 权限验证 ---------------------
if [ "$(id -u)" != "0" ]; then
    echo "错误：本脚本必须使用sudo或root权限运行"
    exit 1
fi

# --------------------- 参数检查 ---------------------
DFU_DEB_FILE="${1:-$(dirname "$0")/dfu-util_0.11-3_arm64.deb}"  # dfu-util deb文件路径参数
DFU_UDEV_RULE="/etc/udev/rules.d/99-dfu-devices.rules"

echo "======= 开始 DFU 工具安装 ======="

# 检查dfu-util deb文件是否存在
if [ ! -f "$DFU_DEB_FILE" ]; then
    echo "错误: dfu-util deb文件 $DFU_DEB_FILE 未找到!"
    echo "用法: $0 [dfu-util_deb_file_path]"
    exit 2
fi

# --------------------- 安装dfu-util本地deb文件 ---------------------
echo "步骤1: 安装本地dfu-util包 ($DFU_DEB_FILE)"
if dpkg -i "$DFU_DEB_FILE"; then
    echo "√ dfu-util本地包安装完成"
else
    echo "错误: dfu-util包安装失败"
    echo "尝试修复依赖关系..."
    apt-get install -f -y
    echo "依赖关系修复完成，重新尝试安装..."
    dpkg -i "$DFU_DEB_FILE"
    echo "√ dfu-util本地包安装完成"
fi

# --------------------- 写入 dfu udev 规则 ---------------------
echo "步骤2: 写入 dfu udev 规则"
echo "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"28e9\", ATTRS{idProduct}==\"0189\", MODE=\"0666\"" > "$DFU_UDEV_RULE"
echo "已创建 udev 规则：$DFU_UDEV_RULE"

echo "步骤3: 重载udev 规则"
udevadm control --reload-rules
udevadm trigger
echo "√ udev 规则重载完成"

# --------------------- 验证安装 ---------------------
echo "步骤4: 验证安装结果"
if command -v dfu-util >/dev/null; then
    echo "√ dfu-util 已成功安装"
    echo "版本信息："
    dfu-util --version
else
    echo "✗ dfu-util 安装失败"
    exit 3
fi

# 验证 udev 规则
if [ -f "$DFU_UDEV_RULE" ]; then
    echo "√ udev 规则已创建"
    echo "规则内容："
    cat "$DFU_UDEV_RULE"
else
    echo "✗ udev 规则创建失败"
    exit 4
fi

echo "======= DFU 工具安装完成! ======="
echo "提示：如果设备未识别，请拔插USB设备或重启系统" 