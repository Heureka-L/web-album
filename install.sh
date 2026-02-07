#!/bin/bash

set -e

echo "=================================================="
echo "Flask 网页相册 - 自动安装脚本"
echo "=================================================="

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo ""
echo "1. 检查 Python 环境..."
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 python3，请先安装 Python 3.7 或更高版本"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "找到 Python 版本: $PYTHON_VERSION"

echo ""
echo "2. 检查并创建虚拟环境..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "虚拟环境创建成功"
else
    echo "虚拟环境已存在"
fi

echo ""
echo "3. 激活虚拟环境..."
source venv/bin/activate

echo ""
echo "4. 升级 pip..."
pip install --upgrade pip

echo ""
echo "5. 安装依赖包..."
pip install -r requirements.txt

echo ""
echo "6. 设置脚本权限..."
chmod +x run.sh
chmod +x install.sh

echo ""
echo "7. 安装 systemd 服务..."
SERVICE_NAME="webalbum"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_FILE"

if [ -f "$SERVICE_PATH" ]; then
    echo "服务文件已存在，将重新创建"
    sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
    sudo systemctl disable $SERVICE_NAME 2>/dev/null || true
fi

CURRENT_USER=$(whoami)
CURRENT_DIR=$(pwd)

sudo tee $SERVICE_PATH > /dev/null <<EOF
[Unit]
Description=Flask Web Album Service
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$CURRENT_DIR
Environment="PATH=$CURRENT_DIR/venv/bin"
ExecStart=$CURRENT_DIR/venv/bin/python $CURRENT_DIR/app.py
Restart=always
RestartSec=10
StandardOutput=append:$CURRENT_DIR/logs/webalbum.log
StandardError=append:$CURRENT_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "8. 创建日志目录..."
mkdir -p logs
touch logs/webalbum.log
touch logs/error.log

echo ""
echo "9. 重新加载 systemd 配置..."
sudo systemctl daemon-reload

echo ""
echo "10. 启用开机自启动..."
sudo systemctl enable $SERVICE_NAME

echo ""
echo "=================================================="
echo "安装完成！"
echo "=================================================="
echo ""
echo "使用方法："
echo "  启动服务: sudo systemctl start $SERVICE_NAME"
echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
echo "  查看状态: sudo systemctl status $SERVICE_NAME"
echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "访问地址: http://localhost:5000"
echo ""
echo "是否现在启动服务？(y/n)"
read -r choice

if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    sudo systemctl start $SERVICE_NAME
    echo ""
    echo "服务已启动！"
    echo "使用 'sudo systemctl status $SERVICE_NAME' 查看服务状态"
else
    echo ""
    echo "未启动服务。您可以稍后使用以下命令启动："
    echo "  sudo systemctl start $SERVICE_NAME"
fi

echo ""
echo "=================================================="
