#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}Flask 网页相册 - 完全卸载脚本${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="webalbum"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"

echo -e "${GREEN}当前项目目录:${NC} $PROJECT_DIR"
echo ""

echo -e "${YELLOW}警告：此操作将完全删除本项目及其所有数据！${NC}"
echo -e "${YELLOW}包括：数据库、上传文件、日志、配置等${NC}"
echo ""
read -p "确认要继续吗？输入 YES 继续: " confirm

if [ "$confirm" != "YES" ]; then
    echo -e "${GREEN}已取消卸载${NC}"
    exit 0
fi

echo ""

STEP=1
TOTAL_STEPS=15

print_step() {
    echo -e "${BLUE}[${STEP}/${TOTAL_STEPS}]${NC} $1"
    STEP=$((STEP + 1))
}

print_step "停止并禁用 systemd 服务..."
if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    sudo systemctl stop $SERVICE_NAME
    echo -e "${GREEN}  ✓ 服务已停止${NC}"
else
    echo -e "  服务未运行"
fi

if sudo systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
    sudo systemctl disable $SERVICE_NAME
    echo -e "${GREEN}  ✓ 服务已禁用${NC}"
else
    echo -e "  服务未启用"
fi

print_step "删除 systemd 服务文件..."
if [ -f "$SERVICE_PATH" ]; then
    sudo rm -f "$SERVICE_PATH"
    sudo systemctl daemon-reload
    sudo systemctl reset-failed 2>/dev/null || true
    echo -e "${GREEN}  ✓ 服务文件已删除${NC}"
else
    echo -e "  服务文件不存在"
fi

print_step "停止所有 Flask 进程..."
if pgrep -f "python.*app\.py" > /dev/null; then
    pkill -f "python.*app\.py" || true
    sleep 2
    pkill -9 -f "python.*app\.py" || true
    echo -e "${GREEN}  ✓ Flask 进程已停止${NC}"
else
    echo -e "  未发现运行中的 Flask 进程"
fi

print_step "删除虚拟环境..."
if [ -d "venv" ]; then
    rm -rf venv
    echo -e "${GREEN}  ✓ 虚拟环境已删除${NC}"
else
    echo -e "  虚拟环境不存在"
fi

print_step "删除数据库..."
if [ -f "users.db" ]; then
    rm -f users.db
    echo -e "${GREEN}  ✓ 数据库已删除${NC}"
else
    echo -e "  数据库不存在"
fi

print_step "删除日志文件和目录..."
if [ -d "logs" ]; then
    rm -rf logs
    echo -e "${GREEN}  ✓ 日志目录已删除${NC}"
else
    echo -e "  日志目录不存在"
fi

print_step "删除 PID 文件..."
rm -f webalbum.pid
rm -f nohup.out
echo -e "${GREEN}  ✓ PID 文件已删除${NC}"

print_step "清理测试缓存..."
rm -f cookies.txt 2>/dev/null || true
rm -f /tmp/test_run.log 2>/dev/null || true
echo -e "${GREEN}  ✓ 测试缓存已清理${NC}"

print_step "删除上传目录..."
if [ -d "uploads" ]; then
    echo -e "${YELLOW}  警告：uploads 目录包含重要的用户文件！${NC}"
    read -p "  是否删除 uploads 目录？(y/n): " delete_uploads
    if [ "$delete_uploads" = "y" ] || [ "$delete_uploads" = "Y" ]; then
        size=$(du -sh uploads 2>/dev/null | cut -f1)
        rm -rf uploads
        echo -e "${GREEN}  ✓ uploads 目录已删除 (${size})${NC}"
    else
        echo -e "  保留 uploads 目录"
    fi
else
    echo -e "  uploads 目录不存在"
fi

print_step "删除缩略图目录..."
if [ -d "thumbnails" ]; then
    size=$(du -sh thumbnails 2>/dev/null | cut -f1)
    rm -rf thumbnails
    echo -e "${GREEN}  ✓ thumbnails 目录已删除 (${size})${NC}"
else
    echo -e "  thumbnails 目录不存在"
fi

print_step "删除应用源代码文件..."
APP_FILES=()
[ -f "app.py" ] && APP_FILES+=("app.py")
[ -f "requirements.txt" ] && APP_FILES+=("requirements.txt")
[ -f "install.sh" ] && APP_FILES+=("install.sh")
[ -f "run.sh" ] && APP_FILES+=("run.sh")
[ -f "deploy.sh" ] && APP_FILES+=("deploy.sh")
[ -f "quick_deploy.sh" ] && APP_FILES+=("quick_deploy.sh")
[ -f "diagnose.sh" ] && APP_FILES+=("diagnose.sh")
[ -f "uninstall.sh" ] && APP_FILES+=("uninstall.sh")
[ -f "FIXES.md" ] && APP_FILES+=("FIXES.md")
[ -f "README.md" ] && APP_FILES+=("README.md")
[ -f "DEPLOYMENT.md" ] && APP_FILES+=("DEPLOYMENT.md")
[ -f "UNINSTALL.md" ] && APP_FILES+=("UNINSTALL.md")
[ -f "deploy_remote.expect" ] && APP_FILES+=("deploy_remote.expect")

if [ ${#APP_FILES[@]} -gt 0 ]; then
    rm -f "${APP_FILES[@]}"
    echo -e "${GREEN}  ✓ 已删除 ${#APP_FILES[@]} 个应用文件${NC}"
else
    echo -e "  无应用文件"
fi

print_step "删除模板目录..."
if [ -d "templates" ]; then
    file_count=$(find templates -type f | wc -l)
    rm -rf templates
    echo -e "${GREEN}  ✓ templates 目录已删除 (${file_count} 个文件)${NC}"
else
    echo -e "  templates 目录不存在"
fi

print_step "删除静态文件目录..."
if [ -d "static" ]; then
    file_count=$(find static -type f | wc -l)
    rm -rf static
    echo -e "${GREEN}  ✓ static 目录已删除 (${file_count} 个文件)${NC}"
else
    echo -e "  static 目录不存在"
fi

print_step "删除 git 资料和历史..."
if [ -d ".git" ]; then
    rm -rf .git
    rm -f .gitignore
    rm -f .gitattributes
    echo -e "${GREEN}  ✓ git 资料已删除${NC}"
else
    echo -e "  git 资料不存在"
fi

print_step "删除 .sisyphus 目录..."
if [ -d ".sisyphus" ]; then
    rm -rf .sisyphus
    echo -e "${GREEN}  ✓ .sisyphus 目录已删除${NC}"
else
    echo -e "  .sisyphus 目录不存在"
fi

print_step "清理 Python 缓存文件..."
pycache_count=$(find . -type d -name "__pycache__" 2>/dev/null | wc -l)
pyc_count=$(find . -type f -name "*.pyc" -o -name "*.pyo" 2>/dev/null | wc -l)

if [ "$pycache_count" -gt 0 ] || [ "$pyc_count" -gt 0 ]; then
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    find . -type f -name "*.pyo" -delete 2>/dev/null || true
    echo -e "${GREEN}  ✓ 已清理 ${pycache_count} 个 __pycache__ 目录和 ${pyc_count} 个 .pyc 文件${NC}"
else
    echo -e "  无 Python 缓存文件"
fi

DELETE_DIR=false
if [ -d "$PROJECT_DIR" ]; then
    echo ""
    echo -e "${YELLOW}项目目录清理建议:${NC}"
    remaining_files=$(find "$PROJECT_DIR" -type f 2>/dev/null | wc -l)
    remaining_dirs=$(find "$PROJECT_DIR" -type d 2>/dev/null | wc -l)

    echo "  剩余文件: $remaining_files"
    echo "  剩余目录: $remaining_dirs"

    if [ $remaining_files -eq 0 ] && [ $remaining_dirs -le 2 ]; then
        echo ""
        read -p "项目目录几乎为空，是否删除整个目录？(y/n): " delete_choice
        if [ "$delete_choice" = "y" ] || [ "$delete_choice" = "Y" ]; then
            DELETE_DIR=true
        fi
    else
        echo ""
        echo "  项目目录中还有其他文件，列表如下："
        ls -la "$PROJECT_DIR" 2>/dev/null | tail -n +4
        echo ""
        read -p "是否强制删除整个项目目录？(y/n): " delete_choice
        if [ "$delete_choice" = "y" ] || [ "$delete_choice" = "Y" ]; then
            DELETE_DIR=true
        fi
    fi
fi

if [ "$DELETE_DIR" = true ]; then
    echo ""
    print_step "删除整个项目目录..."
    cd /tmp
    rm -rf "$PROJECT_DIR"
    echo -e "${GREEN}  ✓ 项目目录已删除${NC}"
    PROJECT_DIR_DELETED=true
else
    echo ""
    echo -e "${YELLOW}保留项目目录${NC}"
    PROJECT_DIR_DELETED=false
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}卸载完成！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

echo -e "${GREEN}验证清理结果:${NC}"

if [ -f "$SERVICE_PATH" ]; then
    echo -e "  ${RED}✗ systemd 服务文件仍存在${NC}"
else
    echo -e "  ${GREEN}✓ systemd 服务已清理${NC}"
fi

if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    echo -e "  ${RED}✗ 服务仍在运行${NC}"
else
    echo -e "  ${GREEN}✓ 服务已停止${NC}"
fi

if pgrep -f "python.*app\.py" > /dev/null; then
    echo -e "  ${RED}✗ Flask 进程仍在运行${NC}"
else
    echo -e "  ${GREEN}✓ Flask 进程已停止${NC}"
fi

if [ "$PROJECT_DIR_DELETED" = true ]; then
    echo -e "  ${GREEN}✓ 项目目录已删除${NC}"
else
    echo -e "  ${YELLOW}! 项目目录保留（可能包含其他文件）${NC}"
fi

if [ -d "$PROJECT_DIR" ]; then
    echo ""
    echo -e "${YELLOW}项目目录剩余内容:${NC}"
    ls -la "$PROJECT_DIR" 2>/dev/null | tail -n +4 || echo "  (目录已不存在)"
fi

echo ""
echo -e "${BLUE}其他清理选项:${NC}"
echo "  • 防火墙规则: sudo ufw delete allow 5000"
echo "  • Python 依赖: pip uninstall flask flask-login werkzeug opencv-python-headless"
echo ""
