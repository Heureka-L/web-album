#!/bin/bash

echo "=================================================="
echo "视频缩略图生成测试"
echo "=================================================="
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIDEO_DIR="$PROJECT_DIR/uploads"
THUMBNAIL_DIR="$PROJECT_DIR/thumbnails/cache"

mkdir -p "$THUMBNAIL_DIR"

if [ ! -d "$VIDEO_DIR" ]; then
    echo "❌ uploads 目录不存在"
    exit 1
fi

echo "检查视频文件..."
VIDEO_FILES=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" \))

if [ -z "$VIDEO_FILES" ]; then
    echo "❌ uploads 目录中没有视频文件"
    echo ""
    echo "当前文件列表:"
    ls -la "$VIDEO_DIR" | head -20
    exit 1
fi

VIDEO_COUNT=$(echo "$VIDEO_FILES" | wc -l)
echo "✓ 找到 $VIDEO_COUNT 个视频文件"
echo ""

echo "检查依赖包..."
source "$PROJECT_DIR/venv/bin/activate"

if python -c "import cv2; print(f'✓ OpenCV {cv2.__version__}')" 2>/dev/null; then
    echo "✓ OpenCV 已安装"
else
    echo "❌ OpenCV 未安装或无法导入"
    exit 1
fi

if python -c "import numpy; print(f'✓ NumPy {numpy.__version__}')" 2>/dev/null; then
    echo "✓ NumPy 已安装"
else
    echo "❌ NumPy 未安装或无法导入"
    exit 1
fi

echo ""
echo "测试 OpenCV 读取视频..."
echo "$VIDEO_FILES" | head -3 | while read video_path; do
    if [ -f "$video_path" ]; then
        echo "测试: $(basename "$video_path")"
        python -c "
import cv2
import sys

cap = cv2.VideoCapture('$video_path')

if not cap.isOpened():
    print('  ❌ 无法打开视频')
    sys.exit(1)

ret, frame = cap.read()

if not ret:
    print('  ❌ 无法读取视频帧')
    cap.release()
    sys.exit(1)

print(f'  ✓ 视频帧读取成功 ({frame.shape})')
cap.release()
"
    fi
done

echo ""
echo "生成缩略图..."
python <<EOF
import os
import cv2
import sys

video_dir = "$VIDEO_DIR"
thumbnail_dir = "$THUMBNAIL_DIR"

video_files = []
for root, dirs, files in os.walk(video_dir):
    for file in files:
        if file.lower().endswith(('.mp4', '.avi', '.mov', '.mkv', '.wmv')):
            video_files.append(os.path.join(root, file))

print(f"找到 {len(video_files)} 个视频文件")

success_count = 0
failed_count = 0

for video_path in video_files[:10]:
    filename = os.path.basename(video_path)
    safe_name = filename.replace(os.sep, '_').replace('/', '_').replace('\\', '_')
    thumbnail_name = os.path.splitext(safe_name)[0] + '_video.jpg'
    thumbnail_path = os.path.join(thumbnail_dir, thumbnail_name)
    
    if os.path.exists(thumbnail_path) and os.path.getsize(thumbnail_path) > 0:
        print(f"⏭ {filename} - 缩略图已存在")
        success_count += 1
        continue
    
    try:
        print(f"📹 处理: {filename}")
        
        # 检查文件可读性
        if not os.access(video_path, os.R_OK):
            raise Exception("文件无法读取")
        
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            raise Exception("无法打开视频")
        
        ret, frame = cap.read()
        
        if not ret:
            raise Exception("无法读取视频帧")
        
        resize_size = (320, 200)
        resized = cv2.resize(frame, resize_size, interpolation=cv2.INTER_AREA)
        cv2.imwrite(thumbnail_path, resized)
        
        cap.release()
        
        if os.path.exists(thumbnail_path) and os.path.getsize(thumbnail_path) > 0:
            print(f"  ✓ 缩略图生成成功 ({os.path.getsize(thumbnail_path)} bytes)")
            success_count += 1
        else:
            print(f"  ❌ 缩略图文件无效")
            failed_count += 1
            
    except Exception as e:
        print(f"  ❌ {e}")
        failed_count += 1

print(f"\n生成完成: 成功 {success_count}, 失败 {failed_count}")

if failed_count > 0:
    print("\n⚠️ 部分视频缩略图生成失败，可能原因:")
    print("  - 视频格式不支持")
    print("  - 视频文件损坏")
    print("  - 文件权限问题")
    print("  - 需要安装额外的编解码器")
EOF

echo ""
echo "缩略图目录信息:"
ls -la "$THUMBNAIL_DIR" 2>/dev/null | head -10
echo ""

THUMBNAIL_COUNT=$(find "$THUMBNAIL_DIR" -type f -name "*.jpg" 2>/dev/null | wc -l)
echo "当前缩略图数量: $THUMBNAIL_COUNT"
echo ""

echo "=================================================="
echo "测试完成"
echo "=================================================="
echo ""
echo "缩略图位置: $THUMBNAIL_DIR"
echo "Web访问: http://localhost:5000/thumbnail/<视频文件名>"

if [ $THUMBNAIL_COUNT -gt 0 ]; then
    echo ""
    echo "示例缩略图文件:"
    ls -lh "$THUMBNAIL_DIR" | head -5
fi
