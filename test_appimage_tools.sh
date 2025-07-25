#!/bin/bash

# =================================================================
# AppImage 管理工具测试脚本
# 功能：验证安装和卸载脚本的基本功能
# =================================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}测试: $1${NC}"
}

print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ 通过${NC}"
    else
        echo -e "${RED}✗ 失败${NC}"
    fi
    echo ""
}

# 检查脚本文件是否存在
check_scripts() {
    print_header "检查脚本文件"
    
    print_test "检查 install_appimage.sh 是否存在"
    if [ -f "install_appimage.sh" ]; then
        print_result 0
    else
        print_result 1
        return 1
    fi
    
    print_test "检查 uninstall_appimage.sh 是否存在"
    if [ -f "uninstall_appimage.sh" ]; then
        print_result 0
    else
        print_result 1
        return 1
    fi
    
    print_test "检查脚本是否可执行"
    if [ -x "install_appimage.sh" ] && [ -x "uninstall_appimage.sh" ]; then
        print_result 0
    else
        print_result 1
        echo "提示：运行 chmod +x *.sh 来设置执行权限"
        return 1
    fi
    
    return 0
}

# 测试脚本语法
test_syntax() {
    print_header "测试脚本语法"
    
    print_test "检查 install_appimage.sh 语法"
    if bash -n install_appimage.sh 2>/dev/null; then
        print_result 0
    else
        print_result 1
        echo "语法错误详情："
        bash -n install_appimage.sh
        return 1
    fi
    
    print_test "检查 uninstall_appimage.sh 语法"
    if bash -n uninstall_appimage.sh 2>/dev/null; then
        print_result 0
    else
        print_result 1
        echo "语法错误详情："
        bash -n uninstall_appimage.sh
        return 1
    fi
    
    return 0
}

# 测试帮助功能
test_help() {
    print_header "测试帮助功能"
    
    print_test "测试 install_appimage.sh --help"
    if ./install_appimage.sh --help >/dev/null 2>&1; then
        print_result 0
    else
        print_result 1
        return 1
    fi
    
    print_test "测试 uninstall_appimage.sh --help"
    if ./uninstall_appimage.sh --help >/dev/null 2>&1; then
        print_result 0
    else
        print_result 1
        return 1
    fi
    
    return 0
}

# 测试参数验证
test_parameter_validation() {
    print_header "测试参数验证"
    
    print_test "测试安装脚本无参数调用"
    if ./install_appimage.sh >/dev/null 2>&1; then
        print_result 0
    else
        print_result 1
    fi
    
    print_test "测试安装脚本不存在文件"
    if ! ./install_appimage.sh "nonexistent.AppImage" >/dev/null 2>&1; then
        print_result 0  # 应该失败
    else
        print_result 1
    fi
    
    print_test "测试卸载脚本 --list 选项"
    if ./uninstall_appimage.sh --list >/dev/null 2>&1; then
        print_result 0
    else
        print_result 1
    fi
    
    return 0
}

# 测试系统依赖
test_dependencies() {
    print_header "测试系统依赖"
    
    local deps=("file" "find" "basename" "dirname" "mktemp")
    local missing=0
    
    for dep in "${deps[@]}"; do
        print_test "检查命令: $dep"
        if command -v "$dep" >/dev/null 2>&1; then
            print_result 0
        else
            print_result 1
            missing=1
        fi
    done
    
    return $missing
}

# 创建一个虚拟AppImage用于测试（仅用于参数验证）
create_dummy_appimage() {
    print_header "创建测试用虚拟AppImage"
    
    print_test "创建虚拟AppImage文件"
    
    # 创建一个简单的ELF可执行文件
    cat > dummy_test.sh << 'EOF'
#!/bin/bash
echo "这是一个测试AppImage"
echo "用法: $0 [选项]"
case "$1" in
    --appimage-extract)
        echo "模拟AppImage提取功能"
        mkdir -p squashfs-root
        echo "虚拟图标内容" > squashfs-root/test.png
        ;;
    *)
        echo "测试AppImage运行中..."
        ;;
esac
EOF
    
    chmod +x dummy_test.sh
    
    # 重命名为 .AppImage
    mv dummy_test.sh TestApp.AppImage
    
    if [ -f "TestApp.AppImage" ]; then
        print_result 0
        echo "创建了测试文件: TestApp.AppImage"
    else
        print_result 1
        return 1
    fi
    
    return 0
}

# 清理测试文件
cleanup_test_files() {
    print_header "清理测试文件"
    
    print_test "清理虚拟AppImage文件"
    if [ -f "TestApp.AppImage" ]; then
        rm -f TestApp.AppImage
        print_result 0
    else
        echo "无需清理"
        print_result 0
    fi
    
    # 清理可能的提取目录
    if [ -d "squashfs-root" ]; then
        rm -rf squashfs-root
    fi
    
    return 0
}

# 显示最终报告
show_report() {
    print_header "测试总结"
    
    echo "✅ 脚本基本功能测试完成"
    echo ""
    echo "📋 接下来你可以："
    echo "   1. 使用真实的AppImage文件测试安装功能"
    echo "   2. 验证桌面快捷方式是否正常创建"
    echo "   3. 测试卸载功能"
    echo ""
    echo "🔧 使用示例："
    echo "   ./install_appimage.sh your-app.AppImage"
    echo "   ./uninstall_appimage.sh"
    echo ""
    echo "📖 更多信息请查看: AppImage管理工具使用说明.md"
}

# 主测试流程
main() {
    echo -e "${GREEN}AppImage 管理工具测试程序${NC}"
    echo ""
    
    local failed=0
    
    # 运行各项测试
    check_scripts || failed=1
    test_syntax || failed=1
    test_help || failed=1
    test_parameter_validation || failed=1
    test_dependencies || failed=1
    
    # 可选的实际文件测试
    echo -e "${YELLOW}是否创建虚拟AppImage进行基本测试? [y/N]: ${NC}"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        create_dummy_appimage
        echo ""
        echo -e "${YELLOW}虚拟AppImage已创建，你现在可以测试安装功能${NC}"
        echo -e "${YELLOW}运行: ./install_appimage.sh TestApp.AppImage${NC}"
        echo ""
        echo -e "${YELLOW}测试完成后是否立即清理? [y/N]: ${NC}"
        read -r cleanup_answer
        if [[ "$cleanup_answer" =~ ^[Yy]$ ]]; then
            cleanup_test_files
        fi
    fi
    
    show_report
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}🎉 所有测试通过！${NC}"
        exit 0
    else
        echo -e "${RED}❌ 部分测试失败，请检查上述错误信息${NC}"
        exit 1
    fi
}

# 运行测试
main "$@" 