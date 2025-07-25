# AppImage 管理工具使用说明

这个工具包含两个bash脚本，用于在Ubuntu/Debian系统上安装和卸载AppImage应用程序。

## 文件说明

- `install_appimage.sh` - AppImage安装脚本
- `uninstall_appimage.sh` - AppImage卸载脚本

## 安装脚本 (install_appimage.sh)

### 功能特性

✅ **自动安装到系统目录** (`/opt/appimages/`)  
✅ **自动提取应用图标**  
✅ **创建系统菜单项** (`.desktop`文件)  
✅ **创建桌面快捷方式**  
✅ **智能权限处理** (自动检测是否需要sudo)  
✅ **完整的错误检查和验证**  
✅ **彩色输出和友好提示**  

### 使用方法

```bash
# 基本安装
./install_appimage.sh MyApp.AppImage

# 指定应用名称和类别
./install_appimage.sh MyApp.AppImage "我的应用" "Development"

# 查看帮助
./install_appimage.sh --help
```

### 参数说明

1. **AppImage文件路径** (必需) - 要安装的AppImage文件
2. **应用名称** (可选) - 在菜单中显示的名称，默认从文件名推断
3. **应用类别** (可选) - 应用分类，默认为"Utility"

### 支持的应用类别

- `AudioVideo` - 音视频应用
- `Development` - 开发工具
- `Education` - 教育软件
- `Game` - 游戏
- `Graphics` - 图形图像
- `Internet` - 网络应用
- `Office` - 办公软件
- `Science` - 科学计算
- `Settings` - 系统设置
- `System` - 系统工具
- `Utility` - 实用工具

### 安装后的文件位置

- **AppImage文件**: `/opt/appimages/MyApp.AppImage`
- **桌面文件**: `/usr/share/applications/MyApp.desktop`
- **图标文件**: `/usr/share/pixmaps/MyApp.png` (如果成功提取)
- **用户桌面快捷方式**: `~/Desktop/MyApp.desktop`

## 卸载脚本 (uninstall_appimage.sh)

### 功能特性

✅ **交互式菜单选择**  
✅ **列出所有已安装的AppImage**  
✅ **单个或批量卸载**  
✅ **自动清理相关文件**  
✅ **更新桌面数据库**  

### 使用方法

```bash
# 交互式卸载 (推荐)
./uninstall_appimage.sh

# 直接卸载指定应用
./uninstall_appimage.sh MyApp

# 列出已安装的AppImage
./uninstall_appimage.sh --list

# 卸载所有AppImage
./uninstall_appimage.sh --clean-all

# 查看帮助
./uninstall_appimage.sh --help
```

## 使用示例

### 安装示例

```bash
# 安装一个代码编辑器
./install_appimage.sh VSCode.AppImage "Visual Studio Code" "Development"

# 安装一个图像编辑器
./install_appimage.sh GIMP.AppImage "GIMP" "Graphics"

# 简单安装（自动推断名称和类别）
./install_appimage.sh MyApp.AppImage
```

### 卸载示例

```bash
# 交互式卸载
./uninstall_appimage.sh
# 然后按提示选择要卸载的应用

# 直接卸载
./uninstall_appimage.sh VSCode

# 查看已安装的应用
./uninstall_appimage.sh --list
```

## 系统要求

- Ubuntu 20.04+ 或 Debian 10+
- Bash 4.0+
- 安装系统级应用需要sudo权限

## 权限说明

脚本会自动检测当前用户权限：
- **root用户**: 直接执行所有操作
- **普通用户**: 自动使用sudo执行需要权限的操作

## 故障排除

### AppImage无法执行
```bash
# 检查文件权限
ls -la MyApp.AppImage

# 手动设置执行权限
chmod +x MyApp.AppImage
```

### 图标未显示
- 图标提取失败时会使用系统默认图标
- 可以手动替换图标文件：`/usr/share/pixmaps/MyApp.png`

### 桌面文件无效
```bash
# 手动验证桌面文件
desktop-file-validate /usr/share/applications/MyApp.desktop

# 手动更新桌面数据库
sudo update-desktop-database /usr/share/applications/
```

## 注意事项

1. **备份重要数据**: 卸载会完全删除AppImage文件
2. **权限要求**: 系统级安装需要sudo权限
3. **路径限制**: AppImage文件路径不应包含特殊字符
4. **兼容性**: 仅在Linux系统上测试，主要支持Ubuntu/Debian

## 技术特性

- **错误处理**: 完整的错误检查和回滚机制
- **用户友好**: 彩色输出和详细的操作反馈
- **安全性**: 文件格式验证和权限检查
- **兼容性**: 支持各种AppImage格式和图标类型
- **清理**: 自动清理临时文件和更新系统缓存 