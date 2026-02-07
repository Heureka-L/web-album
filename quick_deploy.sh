#!/bin/bash

SERVER="47.113.204.202"
USER="root"
PROJECT="/root/heureka-album"

echo "Heureka Album - 快速部署脚本"
echo "================================"
echo ""
echo "请确保："
echo "1. 您已配置SSH密钥认证或准备好输入密码"
echo "2. 服务器已安装Python 3.7+"
echo "3. 服务器网络连接正常"
echo ""
echo "部署内容："
echo "- 服务器: $SERVER"
echo "- 用户: $USER"
echo "- 项目目录: $PROJECT"
echo ""
read -p "按回车键继续部署..."

cat << 'EOF'

请在打开的SSH会话中依次执行以下命令：

# 1. 系统更新和依赖安装
apt-get update && apt-get install -y python3 python3-pip python3-venv git

# 2. 克隆项目
cd /root
git clone git@github.com:Heureka-L/web-album.git

# 3. 配置虚拟环境
cd heureka-album
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. 创建必要目录
mkdir -p logs uploads

# 5. 后台运行
nohup python3 app.py > logs/app.log 2>&1 &

# 6. 验证运行状态
sleep 2
ps aux | grep python3.*app.py | grep -v grep

# 7. 测试访问
curl -I http://localhost:5000

EOF

echo ""
echo "================================"
echo "部署完成！"
echo "================================"
echo ""
echo "访问地址: http://$SERVER:5000"
echo ""
echo "首次访问将显示初始化页面，创建管理员账号即可开始使用。"
echo ""
