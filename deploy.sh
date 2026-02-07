#!/bin/bash

SERVER_IP="47.113.204.202"
SERVER_USER="root"
SERVER_PASS="Lbx375921"
PROJECT_DIR="/root/heureka-album"
REPO_URL="git@github.com:Heureka-L/web-album.git"

echo "=================================================="
echo "Heureka Album - 服务器部署脚本"
echo "=================================================="
echo ""

echo "1. 检查SSH连接..."
if ! ping -c 1 -W 1 $SERVER_IP > /dev/null 2>&1; then
    echo "警告: 无法连接到服务器 $SERVER_IP"
    echo "请检查网络连接"
fi

echo ""
echo "2. 准备部署命令..."
cat > /tmp/deploy_commands.sh << 'DEPLOYCMDS'
#!/bin/bash

set -e

echo "开始部署 Heureka Album..."

echo "[1/6] 安装系统依赖..."
apt-get update > /dev/null 2>&1
apt-get install -y python3 python3-pip python3-venv git > /dev/null 2>&1

echo "[2/6] 克隆项目..."
if [ -d "/root/heureka-album" ]; then
    cd /root/heureka-album
    git pull origin main
else
    git clone git@github.com:Heureka-L/web-album.git /root/heureka-album
    cd /root/heureka-album
fi

echo "[3/6] 创建虚拟环境..."
python3 -m venv venv

echo "[4/6] 安装Python依赖..."
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

echo "[5/6] 创建必要的目录..."
mkdir -p logs uploads

echo "[6/6] 测试运行..."
python3 -c "import flask; import flask_login; import werkzeug.security"

echo ""
echo "=================================================="
echo "部署完成！"
echo "=================================================="
echo ""
echo "项目位置: /root/heureka-album"
echo ""
DEPLOYCMDS

chmod +x /tmp/deploy_commands.sh

echo "3. 上传并执行部署脚本..."
echo ""
echo "由于当前环境限制，请手动执行以下命令："
echo ""
echo "```bash"
echo "# 方式1：使用 expect 脚本（需要安装 expect）"
echo "# 安装 expect: apt-get install expect"
echo ""
echo "# 或使用以下 expect 脚本："
cat > /tmp/deploy.expect << 'EXPECTSCRIPT'
#!/usr/bin/expect -f

set timeout 300
spawn ssh root@47.113.204.202

expect "password:"
send "Lbx375921\r"

expect "#"
send "python3 --version\r"

expect "#"
send "cd /root && rm -rf heureka-album\r"

expect "#"
send "git clone git@github.com:Heureka-L/web-album.git heureka-album\r"

expect "#"
send "cd heureka-album\r"

expect "#"
send "python3 -m venv venv\r"

expect "#"
send "source venv/bin/activate && pip install -r requirements.txt\r"

expect "#"
send "mkdir -p logs uploads\r"

expect "#"
send "python3 app.py &\r"

expect "#"
send "exit\r"

expect eof
EXPECTSCRIPT

chmod +x /tmp/deploy.expect
echo "已创建部署脚本: /tmp/deploy.expect"
echo ""
echo "执行命令: expect /tmp/deploy.expect"
echo ""

echo "=================================================="
echo "部署说明"
echo "=================================================="
echo ""
echo "由于当前环境限制，请按以下步骤手动部署："
echo ""
echo "1. 连接到服务器："
echo "   ssh root@47.113.204.202"
echo ""
echo "2. 安装依赖："
echo "   apt-get update"
echo "   apt-get install -y python3 python3-pip python3-venv git"
echo ""
echo "3. 克隆项目："
echo "   cd /root"
echo "   git clone git@github.com:Heureka-L/web-album.git"
echo ""
echo "4. 安装Python依赖："
echo "   cd heureka-album"
echo "   python3 -m venv venv"
echo "   source venv/bin/activate"
echo "   pip install -r requirements.txt"
echo ""
echo "5. 后台运行应用："
echo "   nohup python3 app.py > logs/app.log 2>&1 &"
echo ""
echo "6. 访问应用："
echo "   http://47.113.204.202:5000"
echo ""
echo "=================================================="
