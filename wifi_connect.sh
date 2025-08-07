#!/bin/bash

# ======= 用户配置部分 =======
SSID=""                    # Wi-Fi 名称（必填）
USERNAME=""          # 登录用户名
PASSWORD=""          # 登录密码
CON_NAME="EAP_WIFI"              # 自定义连接名
IFNAME="wlan0"                    # 网卡名称，请根据实际修改
# ===========================

# 检查 nmcli 是否安装
if ! command -v nmcli &> /dev/null; then
    echo "错误：nmcli 未安装。请先安装 NetworkManager。"
    exit 1
fi

# 创建 Wi-Fi 连接
nmcli connection add type wifi \
    con-name "$CON_NAME" \
    ifname "$IFNAME" \
    ssid "$SSID" \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap peap \
    802-1x.phase2-auth mschapv2 \
    802-1x.identity "$USERNAME" \
    802-1x.password "$PASSWORD" \
    802-1x.system-ca-certs no

# 激活连接
nmcli connection up "$CON_NAME"
