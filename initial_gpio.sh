#!/bin/bash

RESET_PIN_ADDR1=0x02430070
RESET_PIN_ADDR2=0x02430074

BOOT_PIN_ADDR1=0x02430068
BOOT_PIN_ADDR2=0x0243006c

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "错误：本脚本必须使用sudo或root权限运行"
    exit 1
fi

echo "开始配置GPIO引脚..."

# 写入RESET引脚寄存器
echo "配置RESET引脚..."
busybox devmem $RESET_PIN_ADDR1 w 0x000
busybox devmem $RESET_PIN_ADDR2 w 0x01F1F000

# 写入BOOT引脚寄存器
echo "配置BOOT引脚..."
busybox devmem $BOOT_PIN_ADDR1 w 0x000
busybox devmem $BOOT_PIN_ADDR2 w 0x01F1F000

echo "GPIO引脚配置完成"
