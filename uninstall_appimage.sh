#!/bin/bash
set -e  # 任何命令失败时立即退出

# =================================================================
# AppImage 卸载脚本 (Ubuntu/Debian)
# 功能：
# 1. 列出已安装的AppImage  2. 选择性卸载  3. 清理相关文件
# 4. 更新桌面数据库  5. 批量卸载支持
# =================================================================

# --------------------- 配置参数 ---------------------
APPIMAGE_DIR="/opt/appimages"
DESKTOP_DIR="/usr/share/applications"
ICON_DIR="/usr/share/pixmaps"
USER_DESKTOP_DIR="$HOME/Desktop"

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
    echo "AppImage 卸载脚本"
    echo ""
    echo "用法:"
    echo "  $0                    - 交互式卸载"
    echo "  $0 [AppImage名称]     - 直接卸载指定应用"
    echo "  $0 --list            - 仅列出已安装的AppImage"
    echo "  $0 --clean-all       - 卸载所有AppImage"
    echo ""
    echo "示例:"
    echo "  $0                   # 显示菜单选择卸载"
    echo "  $0 MyApp             # 直接卸载MyApp"
    echo "  $0 --list            # 列出所有已安装的AppImage"
    echo "  $0 --clean-all       # 卸载所有AppImage"
}

# --------------------- 权限检查 ---------------------
check_permissions() {
    if [ "$(id -u)" != "0" ]; then
        print_warning "检测到非root权限，某些操作需要sudo权限"
        NEED_SUDO=true
    else
        NEED_SUDO=false
    fi
}

# --------------------- 获取已安装的AppImage列表 ---------------------
get_installed_appimages() {
    local appimages=()
    
    if [ -d "$APPIMAGE_DIR" ]; then
        while IFS= read -r -d '' file; do
            basename=$(basename "$file")
            name="${basename%.*}"
            appimages+=("$name:$file")
        done < <(find "$APPIMAGE_DIR" -name "*.AppImage" -type f -print0 2>/dev/null)
    fi
    
    printf '%s\n' "${appimages[@]}"
}

# --------------------- 列出已安装的AppImage ---------------------
list_appimages() {
    print_info "扫描已安装的AppImage..."
    
    local appimages
    mapfile -t appimages < <(get_installed_appimages)
    
    if [ ${#appimages[@]} -eq 0 ]; then
        print_warning "未找到已安装的AppImage应用"
        return 1
    fi
    
    echo ""
    echo "已安装的AppImage应用："
    echo "----------------------------------------"
    
    local i=1
    for appimage in "${appimages[@]}"; do
        local name="${appimage%%:*}"
        local path="${appimage##*:}"
        local size=$(ls -lh "$path" 2>/dev/null | awk '{print $5}' || echo "未知")
        
        echo "$i. $name ($size)"
        ((i++))
    done
    
    echo "----------------------------------------"
    echo "总共: $((i-1)) 个应用"
    echo ""
}

# --------------------- 卸载单个AppImage ---------------------
uninstall_appimage() {
    local target_name="$1"
    local found=false
    
    print_info "搜索应用: $target_name"
    
    # 搜索AppImage文件
    local appimage_file=""
    if [ -d "$APPIMAGE_DIR" ]; then
        appimage_file=$(find "$APPIMAGE_DIR" -name "*${target_name}*" -type f | head -1)
    fi
    
    if [ -z "$appimage_file" ]; then
        print_error "未找到应用: $target_name"
        return 1
    fi
    
    local basename=$(basename "$appimage_file")
    local name="${basename%.*}"
    
    print_info "找到应用: $name"
    print_info "文件路径: $appimage_file"
    
    # 确认卸载
    if [ "$FORCE_UNINSTALL" != "true" ]; then
        echo -n "确认卸载 '$name'? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "取消卸载"
            return 0
        fi
    fi
    
    print_info "开始卸载 $name..."
    
    # 删除AppImage文件
    if [ -f "$appimage_file" ]; then
        if [ "$NEED_SUDO" = true ]; then
            sudo rm -f "$appimage_file"
        else
            rm -f "$appimage_file"
        fi
        print_success "已删除AppImage文件"
    fi
    
    # 删除桌面文件
    local desktop_file="$DESKTOP_DIR/${name}.desktop"
    if [ -f "$desktop_file" ]; then
        if [ "$NEED_SUDO" = true ]; then
            sudo rm -f "$desktop_file"
        else
            rm -f "$desktop_file"
        fi
        print_success "已删除桌面文件"
    fi
    
    # 删除用户桌面快捷方式
    local user_desktop_file="$USER_DESKTOP_DIR/${name}.desktop"
    if [ -f "$user_desktop_file" ]; then
        rm -f "$user_desktop_file"
        print_success "已删除用户桌面快捷方式"
    fi
    
    # 删除图标文件
    local icon_patterns=("${name}.png" "${name}.svg" "${name}.ico" "${name}.xpm")
    for icon_pattern in "${icon_patterns[@]}"; do
        local icon_file="$ICON_DIR/$icon_pattern"
        if [ -f "$icon_file" ]; then
            if [ "$NEED_SUDO" = true ]; then
                sudo rm -f "$icon_file"
            else
                rm -f "$icon_file"
            fi
            print_success "已删除图标文件: $icon_pattern"
            break
        fi
    done
    
    print_success "应用 '$name' 卸载完成"
    found=true
    
    return 0
}

# --------------------- 交互式卸载 ---------------------
interactive_uninstall() {
    while true; do
        local appimages
        mapfile -t appimages < <(get_installed_appimages)
        
        if [ ${#appimages[@]} -eq 0 ]; then
            print_warning "未找到已安装的AppImage应用"
            break
        fi
        
        list_appimages
        
        echo "请选择要卸载的应用 (输入序号), 或输入 'q' 退出:"
        echo -n "选择: "
        read -r choice
        
        if [[ "$choice" =~ ^[Qq]$ ]]; then
            print_info "退出卸载程序"
            break
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#appimages[@]} ]; then
            local selected="${appimages[$((choice-1))]}"
            local name="${selected%%:*}"
            
            uninstall_appimage "$name"
            
            echo ""
            echo -n "继续卸载其他应用? [y/N]: "
            read -r continue_choice
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                break
            fi
            echo ""
        else
            print_error "无效选择，请输入有效的序号"
            echo ""
        fi
    done
}

# --------------------- 卸载所有AppImage ---------------------
uninstall_all() {
    print_warning "即将卸载所有AppImage应用!"
    echo -n "确认继续? [y/N]: "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消操作"
        return 0
    fi
    
    local appimages
    mapfile -t appimages < <(get_installed_appimages)
    
    if [ ${#appimages[@]} -eq 0 ]; then
        print_warning "未找到已安装的AppImage应用"
        return 0
    fi
    
    print_info "开始批量卸载..."
    FORCE_UNINSTALL=true
    
    for appimage in "${appimages[@]}"; do
        local name="${appimage%%:*}"
        uninstall_appimage "$name"
        echo ""
    done
    
    # 清理空目录
    if [ -d "$APPIMAGE_DIR" ]; then
        if [ "$NEED_SUDO" = true ]; then
            sudo rmdir "$APPIMAGE_DIR" 2>/dev/null || true
        else
            rmdir "$APPIMAGE_DIR" 2>/dev/null || true
        fi
    fi
    
    print_success "所有AppImage应用已卸载"
}

# --------------------- 更新桌面数据库 ---------------------
update_desktop_database() {
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
}

# --------------------- 主程序 ---------------------
main() {
    echo "======= AppImage 卸载工具 ======="
    echo ""
    
    check_permissions
    
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --list)
            list_appimages
            exit 0
            ;;
        --clean-all)
            uninstall_all
            update_desktop_database
            exit 0
            ;;
        "")
            interactive_uninstall
            ;;
        *)
            uninstall_appimage "$1"
            ;;
    esac
    
    update_desktop_database
    
    echo ""
    print_success "操作完成!"
}

# 执行主程序
main "$@" 