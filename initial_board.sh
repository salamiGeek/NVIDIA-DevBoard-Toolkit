#!/bin/bash
set -e  # 任何命令失败时立即退出

# =================================================================
# 设备驱动安装与开发工具配置脚本 (Ubuntu 22.04)
# 优化点：
# 1. 合并APT操作为单命令  2. 增加错误检查  3. 自动权限验证
# =================================================================

# --------------------- 权限验证 ---------------------
if [ "$(id -u)" != "0" ]; then
    echo "错误：本脚本必须使用sudo或root权限运行"
    exit 1
fi

# --------------------- 参数检查 ---------------------
KO_FILE="${1:-$(dirname "$0")/ch341.ko}"  # 默认路径参数
INSTALL_SCRIPT="$(dirname "$0")/install_ch341.sh"
DFU_INSTALL_SCRIPT="$(dirname "$0")/install_dfu.sh"
DFU_DEB_FILE="${2:-$(dirname "$0")/dfu-util_0.11-3_arm64.deb}"  # 添加本地dfu-util deb文件参数
SOURCES_LIST_FILE="$(dirname "$0")/sources.list"  # 新的软件源文件

echo "======= 开始设备驱动安装 ======="

# --------------------- 替换软件源 ---------------------
echo "步骤0: 替换软件源为清华大学镜像"
if [ -f "$SOURCES_LIST_FILE" ]; then
    # 备份原有软件源（仅在备份文件不存在时）
    if [ -f "/etc/apt/sources.list" ]; then
        if [ -f "/etc/apt/sources.list.back" ]; then
            echo "备份文件 /etc/apt/sources.list.back 已存在，跳过备份"
        else
            echo "备份原有软件源到 /etc/apt/sources.list.back"
            cp /etc/apt/sources.list /etc/apt/sources.list.back
        fi
    fi
    
    # 复制新的软件源
    echo "复制新的软件源文件"
    cp "$SOURCES_LIST_FILE" /etc/apt/sources.list
    echo "√ 软件源替换完成"
else
    echo "警告: 软件源文件 $SOURCES_LIST_FILE 不存在，跳过软件源替换"
fi

# 检查驱动安装脚本是否存在
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "错误: 安装脚本 $INSTALL_SCRIPT 不存在!"
    exit 2
fi

# 检查驱动文件是否存在
if [ ! -f "$KO_FILE" ]; then
    echo "错误: 驱动文件 $KO_FILE 未找到!"
    exit 3
fi

# 检查dfu安装脚本是否存在
if [ ! -f "$DFU_INSTALL_SCRIPT" ]; then
    echo "错误: DFU安装脚本 $DFU_INSTALL_SCRIPT 不存在!"
    exit 4
fi

# 检查软件源文件是否存在（可选检查，不存在时给出警告但不退出）
if [ ! -f "$SOURCES_LIST_FILE" ]; then
    echo "警告: 软件源文件 $SOURCES_LIST_FILE 不存在，将使用系统默认软件源"
fi

# --------------------- 执行驱动安装 ---------------------
echo "步骤1: 安装 CH341 驱动 ($KO_FILE)"
chmod +x "$INSTALL_SCRIPT"  # 确保脚本可执行
"$INSTALL_SCRIPT" "$KO_FILE"
echo "√ CH341驱动安装完成"

# --------------------- 安装dfu工具 ---------------------
echo "步骤2: 安装DFU工具 ($DFU_DEB_FILE)"
chmod +x "$DFU_INSTALL_SCRIPT"  # 确保脚本可执行
"$DFU_INSTALL_SCRIPT" "$DFU_DEB_FILE"
echo "√ DFU工具安装完成"

# --------------------- 安装基础工具 ---------------------
echo "步骤3: 安装基础系统工具"
apt update -qq

echo "安装NVIDIA驱动更新所需的基础工具..."
apt install -y cpio gzip findutils || {
    echo "警告: 基础工具安装失败，尝试修复..."
    apt --fix-broken install -y
    apt install -y cpio gzip findutils
}
echo "√ 基础工具安装完成"

# --------------------- 系统更新 ---------------------
echo "步骤4: 执行系统更新（确保内核和驱动兼容性）"
echo "开始系统升级，这可能需要几分钟时间..."
echo "处理可能的NVIDIA包冲突..."

# 先尝试修复可能的包问题
apt --fix-broken install -y

# 如果upgrade失败，尝试排除有问题的nvidia包
if ! apt upgrade -y; then
    echo "升级过程中遇到错误，尝试排除有问题的NVIDIA包..."
    
    # 标记有问题的nvidia包为hold，暂时不升级
    apt-mark hold nvidia-l4t-initrd 2>/dev/null || true
    
    # 重新尝试升级其他包
    echo "重新尝试升级其他包..."
    if apt upgrade -y; then
        echo "√ 系统更新完成（已跳过有问题的NVIDIA包）"
        echo "提示：nvidia-l4t-initrd 包已被暂时保留，避免升级冲突"
    else
        echo "警告：系统升级仍有问题，继续执行后续步骤..."
    fi
else
    echo "√ 系统更新完成"
fi

# --------------------- 安装开发工具和WiFi驱动 ---------------------
echo "步骤5: 安装开发工具集和WiFi驱动 (picocom/sshpass/stlink-tools/iwlwifi-modules)"
apt install -y \
    picocom \
    sshpass \
    stlink-tools \
    iwlwifi-modules
echo "√ 所有开发工具和WiFi驱动安装完成"

# --------------------- 验证WiFi驱动 ---------------------
echo "步骤5.1: 验证WiFi驱动安装"
echo "WiFi驱动加载信息："
dmesg | grep iwlwifi | tail -10 || echo "未找到iwlwifi相关信息"

echo "检查网络接口："
ip link show | grep -E "(wlan|wlp)" || echo "未找到WiFi网络接口"

echo "检查WiFi硬件："
lspci | grep -i wireless || echo "未检测到WiFi硬件"

echo "提示：如果WiFi仍未工作，请检查："
echo "1. 硬件是否支持"
echo "2. 是否需要重启系统以加载新的内核模块"
echo "3. 是否需要安装额外的固件包"
echo "√ WiFi驱动验证完成"

# --------------------- 验证安装 ---------------------
echo "步骤6: 验证安装结果"
echo "基础工具验证："
command -v cpio >/dev/null && echo "状态: cpio 已安装" || echo "警告: cpio 未安装!"
command -v gzip >/dev/null && echo "状态: gzip 已安装" || echo "警告: gzip 未安装!"
command -v find >/dev/null && echo "状态: findutils 已安装" || echo "警告: findutils 未安装!"

echo "驱动和工具验证："
lsmod | grep -q ch341 && echo "状态: CH341 驱动已加载" || echo "警告: CH341 驱动未加载!"
command -v picocom >/dev/null && echo "状态: picocom 已安装"
command -v sshpass >/dev/null && echo "状态: sshpass 已安装"
command -v dfu-util >/dev/null && echo "状态: dfu-util 已安装"
command -v st-flash >/dev/null && echo "状态: stlink-tools 已安装"
lsmod | grep -q iwlwifi && echo "状态: WiFi驱动(iwlwifi)已加载" || echo "警告: WiFi驱动未加载!"


# --------------------- 清理和建议 ---------------------
echo "步骤7: 清理和后续建议"

# 检查是否有被hold的nvidia包
if apt-mark showhold | grep -q nvidia-l4t-initrd; then
    echo "检测到nvidia-l4t-initrd包被暂时保留"
    echo "如需稍后手动处理该包，请运行："
    echo "  sudo apt-mark unhold nvidia-l4t-initrd"
    echo "  sudo apt install --reinstall nvidia-l4t-initrd"
fi

echo "建议："
echo "1. 重启系统以确保所有驱动正常加载"
echo "2. 重启后检查WiFi是否正常工作"
echo "3. 如有WiFi问题，可尝试: sudo systemctl restart NetworkManager"

echo "======= 所有操作已完成! ======="
