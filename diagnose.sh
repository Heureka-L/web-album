#!/bin/bash

echo "=================================================="
echo "Flask 网页相册 - 诊断脚本"
echo "=================================================="
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "1. 检查 Python 环境..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 python3"
else
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "✅ Python 版本: $PYTHON_VERSION"
fi

echo ""
echo "2. 检查虚拟环境..."
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在"
else
    echo "✅ 虚拟环境存在"

    if [ -f "venv/bin/python" ]; then
        echo "   Python: $(venv/bin/python --version 2>&1 | cut -d' ' -f2)"
    fi
fi

echo ""
echo "3. 检查依赖包..."
if [ -d "venv" ]; then
    source venv/bin/activate

    echo "检查 Flask..."
    python -c "import flask; print(f'  ✅ Flask {flask.__version__}')" 2>/dev/null || echo "  ❌ Flask 未安装"

    echo "检查 Flask-Login..."
    python -c "import flask_login; print(f'  ✅ Flask-Login 已安装')" 2>/dev/null || echo "  ❌ Flask-Login 未安装"

    echo "检查 opencv-python-headless..."
    python -c "import cv2; print(f'  ✅ opencv-python {cv2.__version__}')" 2>/dev/null || echo "  ❌ opencv-python 未安装"

    echo "检查 numpy..."
    python -c "import numpy; print(f'  ✅ numpy {numpy.__version__}')" 2>/dev/null || echo "  ❌ numpy 未安装"
else
    echo "⚠️  跳过（虚拟环境不存在）"
fi

echo ""
echo "4. 检查文件结构..."
for dir in uploads templates static thumbnails; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo "✅ $dir/ 存在 ($file_count 个文件)"
    else
        echo "❌ $dir/ 不存在"
    fi
done

if [ -f "app.py" ]; then
    echo "✅ app.py 存在"
else
    echo "❌ app.py 不存在"
fi

if [ -f "requirements.txt" ]; then
    echo "✅ requirements.txt 存在"
else
    echo "❌ requirements.txt 不存在"
fi

echo ""
echo "5. 检查数据库..."
if [ -f "users.db" ]; then
    echo "✅ users.db 存在"

    if [ -d "venv" ]; then
        source venv/bin/activate
        python -c "
import sqlite3
conn = sqlite3.connect('users.db')
cursor = conn.cursor()

# 检查表结构
cursor.execute('SELECT sql FROM sqlite_master WHERE type=\"table\" AND name=\"users\"')
result = cursor.fetchone()
if result:
    print('  用户表结构:')
    print('  ' + result[0])

# 检查列
cursor.execute('PRAGMA table_info(users)')
columns = cursor.fetchall()
print('  列信息:')
for col in columns:
    print(f'    - {col[1]} ({col[2]})')

# 检查用户数量
cursor.execute('SELECT COUNT(*) FROM users')
count = cursor.fetchone()[0]
print(f'  用户数量: {count}')

if count > 0:
    cursor.execute('SELECT id, username, is_admin FROM users')
    users = cursor.fetchall()
    print('  用户列表:')
    for user in users:
        is_admin = '管理员' if user[2] else '普通用户'
        print(f'    - ID: {user[0]}, 用户名: {user[1]}, 角色: {is_admin}')

conn.close()
" 2>&1
    fi
else
    echo "⚠️  users.db 不存在（首次运行会自动创建）"
fi

echo ""
echo "6. 检查 systemd 服务..."
SERVICE_NAME="webalbum"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"

if [ -f "$SERVICE_PATH" ]; then
    echo "✅ systemd 服务文件已安装"

    echo ""
    echo "7. 检查服务状态..."
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo "✅ 服务运行中"
            systemctl status $SERVICE_NAME --no-pager -l | head -20
        else
            echo "❌ 服务未运行"
            echo ""
            echo "查看详细状态:"
            systemctl status $SERVICE_NAME --no-pager -l | head -20
        fi
    else
        echo "⚠️  systemctl 命令不可用"
    fi
else
    echo "❌ systemd 服务文件未安装"
fi

echo ""
echo "8. 检查端口占用..."
PORT=5000
if command -v netstat &> /dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo "⚠️  端口 $PORT 已被占用"
        netstat -tuln 2>/dev/null | grep ":$PORT "
    else
        echo "✅ 端口 $PORT 未被占用"
    fi
elif command -v ss &> /dev/null; then
    if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo "⚠️  端口 $PORT 已被占用"
        ss -tuln 2>/dev/null | grep ":$PORT "
    else
        echo "✅ 端口 $PORT 未被占用"
    fi
else
    echo "⚠️  无法检查端口（需要 netstat 或 ss）"
fi

echo ""
echo "9. 检查日志文件..."
if [ -f "logs/webalbum.log" ]; then
    echo "✅ logs/webalbum.log 存在"
    echo "  最近的错误:"
    grep -i "error\|exception\|traceback" logs/webalbum.log | tail -5 || echo "  无错误"
else
    echo "⚠️  logs/webalbum.log 不存在"
fi

echo ""
echo "10. 测试应用启动..."
if [ -d "venv" ]; then
    source venv/bin/activate
    echo "启动测试（5秒后自动停止）..."
    timeout 5 python app.py > /tmp/test_run.log 2>&1 &
    TEST_PID=$!
    sleep 3

    if ps -p $TEST_PID > /dev/null 2>&1; then
        echo "✅ 应用启动成功"

        if command -v curl &> /dev/null; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/ 2>/dev/null || echo "000")
            echo "  HTTP 响应码: $HTTP_CODE"

            if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
                echo "  ✅ 应用响应正常"
            else
                echo "  ❌ 应用响应异常"
            fi
        fi

        kill $TEST_PID 2>/dev/null
    else
        echo "❌ 应用启动失败"
        echo "错误信息:"
        cat /tmp/test_run.log
    fi
else
    echo "⚠️  跳过（虚拟环境不存在）"
fi

echo ""
echo "=================================================="
echo "诊断完成"
echo "=================================================="
