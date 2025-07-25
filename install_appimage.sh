#!/bin/bash
set -e  # 任何命令失败时立即退出

# =================================================================
# AppImage 安装与快捷方式创建脚本 (Ubuntu/Debian)
# 功能：
# 1. 安装AppImage到系统目录  2. 自动提取图标  3. 创建桌面快捷方式
# 4. 创建菜单项  5. 自动权限处理  6. 完整的错误检查
# =================================================================

# --------------------- 配置参数 ---------------------
APPIMAGE_DIR="/opt/appimages"          # AppImage安装目录
DESKTOP_DIR="/usr/share/applications"   # 系统桌面文件目录
ICON_DIR="/usr/share/pixmaps"          # 系统图标目录
USER_DESKTOP_DIR="$HOME/Desktop"       # 用户桌面目录

# --------------------- 颜色输出 ---------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --------------------- 工具函数 ---------------------
print_error() {
    echo -e "${RED}错误: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}√ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

print_info() {
    echo -e "${BLUE}信息: $1${NC}"
}

# --------------------- 使用说明 ---------------------
show_usage() {
    echo "AppImage 安装脚本"
    echo ""
    echo "用法:"
    echo "  $0 [AppImage文件路径] [可选:应用名称] [可选:类别]"
    echo ""
    echo "参数:"
    echo "  AppImage文件路径  - 要安装的AppImage文件路径"
    echo "  应用名称         - 显示名称 (默认从文件名推断)"
    echo "  类别            - 应用类别 (如: Development, Graphics, Office等)"
    echo ""
    echo "示例:"
    echo "  $0 ./MyApp.AppImage"
    echo "  $0 ./MyApp.AppImage \"我的应用\" \"Development\""
    echo ""
    echo "支持的类别: AudioVideo, Development, Education, Game, Graphics,"
    echo "           Internet, Office, Science, Settings, System, Utility"
}

# --------------------- 参数检查 ---------------------
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

APPIMAGE_FILE="$1"
APP_NAME="${2:-}"
APP_CATEGORY="${3:-Utility}"

# 检查AppImage文件是否存在
if [ ! -f "$APPIMAGE_FILE" ]; then
    print_error "AppImage文件不存在: $APPIMAGE_FILE"
    exit 1
fi

# 检查文件是否为AppImage格式
if ! file "$APPIMAGE_FILE" | grep -q "ELF.*executable"; then
    print_error "文件不是有效的AppImage格式: $APPIMAGE_FILE"
    exit 1
fi

# --------------------- 权限检查 ---------------------
print_info "检查权限..."
if [ "$(id -u)" != "0" ]; then
    print_warning "检测到非root权限，某些操作需要sudo权限"
    NEED_SUDO=true
else
    NEED_SUDO=false
fi

# --------------------- 提取信息 ---------------------
print_info "分析AppImage文件..."

# 获取文件基本信息
APPIMAGE_BASENAME=$(basename "$APPIMAGE_FILE")
APPIMAGE_NAME="${APPIMAGE_BASENAME%.*}"  # 去掉扩展名

# 如果没有指定应用名称，从文件名推断
if [ -z "$APP_NAME" ]; then
    APP_NAME="$APPIMAGE_NAME"
    # 美化名称：去掉版本号、下划线替换为空格等
    APP_NAME=$(echo "$APP_NAME" | sed 's/-[0-9].*//' | sed 's/_/ /g' | sed 's/-/ /g')
fi

print_info "应用名称: $APP_NAME"
print_info "应用类别: $APP_CATEGORY"

# --------------------- 创建目录 ---------------------
print_info "创建必要目录..."

create_dir() {
    local dir="$1"
    if [ "$NEED_SUDO" = true ]; then
        sudo mkdir -p "$dir"
    else
        mkdir -p "$dir"
    fi
}

create_dir "$APPIMAGE_DIR"
create_dir "$ICON_DIR"

# --------------------- 安装AppImage ---------------------
print_info "安装AppImage到系统目录..."

TARGET_PATH="$APPIMAGE_DIR/$APPIMAGE_BASENAME"

# 复制文件
if [ "$NEED_SUDO" = true ]; then
    sudo cp "$APPIMAGE_FILE" "$TARGET_PATH"
    sudo chmod +x "$TARGET_PATH"
else
    cp "$APPIMAGE_FILE" "$TARGET_PATH"
    chmod +x "$TARGET_PATH"
fi

print_success "AppImage已安装到: $TARGET_PATH"

# --------------------- 提取图标 ---------------------
print_info "尝试提取应用图标..."

ICON_PATH=""
TEMP_DIR=$(mktemp -d)

# 尝试从AppImage中提取图标
if "$TARGET_PATH" --appimage-extract >/dev/null 2>&1; then
    cd "$TEMP_DIR"
    "$TARGET_PATH" --appimage-extract >/dev/null 2>&1 || true
    
    # 查找图标文件
    if [ -d "squashfs-root" ]; then
        # 常见图标路径
        for icon_pattern in "*.png" "*.svg" "*.ico" "*.xpm"; do
            FOUND_ICON=$(find squashfs-root -name "$icon_pattern" -type f | head -1)
            if [ -n "$FOUND_ICON" ]; then
                ICON_EXT="${FOUND_ICON##*.}"
                ICON_NAME="${APPIMAGE_NAME}.${ICON_EXT}"
                ICON_PATH="$ICON_DIR/$ICON_NAME"
                
                if [ "$NEED_SUDO" = true ]; then
                    sudo cp "$FOUND_ICON" "$ICON_PATH"
                else
                    cp "$FOUND_ICON" "$ICON_PATH"
                fi
                
                print_success "图标已提取: $ICON_PATH"
                break
            fi
        done
    fi
    
    # 清理临时文件
    rm -rf squashfs-root 2>/dev/null || true
fi

# 如果没有找到图标，使用默认图标
if [ -z "$ICON_PATH" ]; then
    print_warning "未能提取图标，将使用默认图标"
    ICON_PATH="application-x-executable"
fi

cd - >/dev/null

# 清理临时目录
rm -rf "$TEMP_DIR"

# --------------------- 创建桌面文件 ---------------------
print_info "创建桌面快捷方式..."

DESKTOP_FILE="$DESKTOP_DIR/${APPIMAGE_NAME}.desktop"

# 创建桌面文件内容
DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Installed via AppImage
Exec=$TARGET_PATH
Icon=$ICON_PATH
Categories=$APP_CATEGORY;
Terminal=false
StartupNotify=true
MimeType=application/x-appimage;"

# 写入桌面文件
if [ "$NEED_SUDO" = true ]; then
    echo "$DESKTOP_CONTENT" | sudo tee "$DESKTOP_FILE" >/dev/null
    sudo chmod 644 "$DESKTOP_FILE"
else
    echo "$DESKTOP_CONTENT" > "$DESKTOP_FILE"
    chmod 644 "$DESKTOP_FILE"
fi

print_success "桌面文件已创建: $DESKTOP_FILE"

# --------------------- 创建用户桌面快捷方式 ---------------------
if [ -d "$USER_DESKTOP_DIR" ] && [ -n "$USER" ]; then
    print_info "创建用户桌面快捷方式..."
    
    USER_DESKTOP_FILE="$USER_DESKTOP_DIR/${APPIMAGE_NAME}.desktop"
    
    # 为用户桌面创建可执行的快捷方式
    USER_DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Installed via AppImage
Exec=$TARGET_PATH
Icon=$ICON_PATH
Categories=$APP_CATEGORY;
Terminal=false
StartupNotify=true
MimeType=application/x-appimage;"

    echo "$USER_DESKTOP_CONTENT" > "$USER_DESKTOP_FILE"
    chmod +x "$USER_DESKTOP_FILE"
    
    print_success "用户桌面快捷方式已创建: $USER_DESKTOP_FILE"
fi

# --------------------- 更新桌面数据库 ---------------------
print_info "更新桌面数据库..."

if command -v update-desktop-database >/dev/null 2>&1; then
    if [ "$NEED_SUDO" = true ]; then
        sudo update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    else
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
    print_success "桌面数据库已更新"
fi

# 更新图标缓存
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    if [ "$NEED_SUDO" = true ]; then
        sudo gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
    else
        gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
    fi
    print_success "图标缓存已更新"
fi

# --------------------- 验证安装 ---------------------
print_info "验证安装结果..."

echo "安装验证："
[ -f "$TARGET_PATH" ] && print_success "AppImage文件: $TARGET_PATH"
[ -f "$DESKTOP_FILE" ] && print_success "桌面文件: $DESKTOP_FILE"
[ -f "$ICON_PATH" ] || [ "$ICON_PATH" = "application-x-executable" ] && print_success "图标文件: $ICON_PATH"

# --------------------- 完成信息 ---------------------
echo ""
echo "======= 安装完成! ======="
echo ""
print_success "应用名称: $APP_NAME"
print_success "安装路径: $TARGET_PATH"
print_success "桌面文件: $DESKTOP_FILE"
if [ -f "$USER_DESKTOP_DIR/${APPIMAGE_NAME}.desktop" ]; then
    print_success "桌面快捷方式: $USER_DESKTOP_DIR/${APPIMAGE_NAME}.desktop"
fi
echo ""
print_info "你现在可以："
echo "  1. 在应用菜单中找到 '$APP_NAME'"
echo "  2. 从桌面快捷方式启动应用"
echo "  3. 直接运行: $TARGET_PATH"
echo ""
print_info "卸载命令:"
echo "  sudo rm -f '$TARGET_PATH'"
echo "  sudo rm -f '$DESKTOP_FILE'"
echo "  sudo rm -f '$ICON_PATH'"
if [ -f "$USER_DESKTOP_DIR/${APPIMAGE_NAME}.desktop" ]; then
    echo "  rm -f '$USER_DESKTOP_DIR/${APPIMAGE_NAME}.desktop'"
fi
echo "" 