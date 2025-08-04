# NVIDIA 开发板初始化工具集

这个项目提供了一套用于NVIDIA开发板的初始化和配置工具，包括驱动安装、系统配置和应用程序管理工具。

## 项目内容

### 核心脚本
- `initial_board.sh` - 开发板初始化主脚本，包含驱动安装和系统配置
- `install_ch341.sh` - CH341串口驱动安装脚本
- `install_dfu.sh` - DFU工具安装脚本

### 驱动和工具文件
- `ch341.ko` - CH341串口驱动内核模块
- `dfu-util_0.11-3_arm64.deb` - DFU工具Debian安装包
- `sources.list` - 优化的APT软件源配置（清华大学镜像）

### udev规则文件
- `rules.d/99-ch341.rules` - CH341设备的udev规则文件
- `rules.d/99-dfu-devices.rules` - DFU设备的udev规则文件
- `rules.d/99-robot-serial.rules` - 机器人串口设备的udev规则文件

### AppImage应用管理工具
- `install_appimage.sh` - AppImage应用安装脚本
- `uninstall_appimage.sh` - AppImage应用卸载脚本
- `test_appimage_tools.sh` - AppImage工具测试脚本
- `AppImage管理工具使用说明.md` - AppImage工具详细文档

## 功能特性

- ✅ 自动安装CH341串口驱动
- ✅ 自动安装DFU工具及配置
- ✅ 配置优化的软件源
- ✅ 安装开发必备工具（picocom/sshpass/stlink-tools等）
- ✅ 安装WiFi驱动支持
- ✅ AppImage应用程序管理
- ✅ 独立的udev规则配置
- ✅ 机器人串口设备自动识别（热插拔支持）

## 系统要求

- Ubuntu 22.04 (推荐)
- ARM64架构
- root或sudo权限

## 使用方法

### 开发板初始化

```bash
# 使用默认配置
sudo ./initial_board.sh

# 指定驱动和DFU工具路径
sudo ./initial_board.sh /path/to/ch341.ko /path/to/dfu-util.deb
```

### CH341驱动独立安装

```bash
sudo ./install_ch341.sh /path/to/ch341.ko
```

### DFU工具独立安装

```bash
sudo ./install_dfu.sh /path/to/dfu-util.deb
```

### AppImage应用管理

安装AppImage应用：
```bash
./install_appimage.sh MyApp.AppImage "应用名称" "应用类别"
```

卸载AppImage应用：
```bash
./uninstall_appimage.sh
# 或
./uninstall_appimage.sh MyApp
```

## 安装后验证

初始化脚本会自动验证安装结果，包括：
- 驱动加载状态
- 工具安装状态
- WiFi驱动状态
- udev规则安装状态

## 注意事项

1. 所有系统级操作需要root或sudo权限
2. 安装过程中可能需要重启系统以应用某些更改
3. 如遇NVIDIA包冲突，脚本会自动处理并提供解决建议
4. udev规则文件存放在rules.d目录中，安装时会自动复制到系统目录
5. 机器人串口设备支持热插拔，插入后会自动创建设备链接(/dev/ttyRobotSerial)

## 故障排除

### CH341驱动问题
- 检查设备是否正确连接
- 查看内核消息：`dmesg | grep ch341`
- 检查设备节点：`ls -l /dev/ttyCH341*`
- 检查udev规则：`cat /etc/udev/rules.d/99-ch341.rules`

### DFU工具问题
- 验证安装：`dfu-util --version`
- 检查udev规则：`cat /etc/udev/rules.d/99-dfu-devices.rules`
- 重载udev规则：`sudo udevadm control --reload-rules && sudo udevadm trigger`

### 机器人串口问题
- 检查设备是否正确连接
- 检查设备节点：`ls -l /dev/ttyRobotSerial`
- 检查udev规则：`cat /etc/udev/rules.d/99-robot-serial.rules`
- 重载udev规则：`sudo udevadm control --reload-rules && sudo udevadm trigger`

### WiFi驱动问题
- 检查驱动加载状态：`lsmod | grep iwlwifi`
- 检查网络接口：`ip link show`
- 重启网络服务：`sudo systemctl restart NetworkManager` 