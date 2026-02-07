#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

VENV_PATH="$PROJECT_DIR/venv"
PID_FILE="$PROJECT_DIR/webalbum.pid"
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"

case "$1" in
    start)
        echo "启动 Flask 网页相册..."

        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "服务已在运行中 (PID: $PID)"
                exit 1
            else
                rm "$PID_FILE"
            fi
        fi

        if [ ! -d "$VENV_PATH" ]; then
            echo "错误: 虚拟环境不存在，请先运行 ./install.sh"
            exit 1
        fi

        source "$VENV_PATH/bin/activate"
        nohup python app.py > "$LOG_DIR/webalbum.out.log" 2> "$LOG_DIR/webalbum.err.log" &
        PID=$!
        echo $PID > "$PID_FILE"

        echo "服务已启动 (PID: $PID)"
        echo "访问地址: http://localhost:5000"
        echo "查看日志: tail -f $LOG_DIR/webalbum.out.log"
        ;;

    stop)
        echo "停止 Flask 网页相册..."

        if [ ! -f "$PID_FILE" ]; then
            echo "服务未运行"
            exit 0
        fi

        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID"
            rm "$PID_FILE"
            echo "服务已停止"
        else
            echo "服务未运行"
            rm "$PID_FILE"
        fi
        ;;

    restart)
        "$0" stop
        sleep 2
        "$0" start
        ;;

    status)
        if [ ! -f "$PID_FILE" ]; then
            echo "服务未运行"
            exit 1
        fi

        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "服务运行中 (PID: $PID)"
            ps -p "$PID" -o pid,ppid,cmd,start,time
        else
            echo "服务未运行"
            rm "$PID_FILE"
            exit 1
        fi
        ;;

    logs)
        echo "显示日志 (Ctrl+C 退出):"
        tail -f "$LOG_DIR/webalbum.out.log"
        ;;

    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "命令说明:"
        echo "  start    - 启动服务（后台运行）"
        echo "  stop     - 停止服务"
        echo "  restart  - 重启服务"
        echo "  status   - 查看服务状态"
        echo "  logs     - 查看实时日志"
        exit 1
        ;;
esac
