# NumPy 兼容性修复和分页功能更新

## 问题说明

视频缩略图无法正常加载，错误信息：
```
AttributeError: _ARRAY_API not found
A module that was compiled using NumPy 1.x cannot be run in NumPy 2.4.2
```

## 根本原因

opencv-python-headless 4.9.0.80 是使用 NumPy 1.x 编译的，但服务器安装了 NumPy 2.4.2，导致不兼容。

## 解决方案

### 1. 更新 requirements.txt

在 `requirements.txt` 中添加版本限制：
```
numpy<2.0.0
```

### 2. 服务器上更新依赖

在服务器上执行以下命令：

```bash
cd /root/00-webAlbum

# 停止服务
sudo systemctl stop webalbum

# 激活虚拟环境
source venv/bin/activate

# 安装兼容的 NumPy 版本
pip install 'numpy<2.0.0' --force-reinstall

# 验证安装
python -c "import numpy; print(f'NumPy version: {numpy.__version__}')"
python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')"

# 测试导入（不报错即可）
python -c "import cv2; import numpy; print('导入成功')"

# 重启服务
sudo systemctl start webalbum

# 查看服务状态
sudo systemctl status webalbum
```

### 3. 验证修复

访问相册中的视频文件，确认缩略图正常显示。如果之前生成的缩略图有问题，会自动重新生成。

---

## 新功能说明

### 图片缩略图

现在支持图片自动生成缩略图：
- 自动生成 300x200 的缩略图
- 缩略图缓存到 `thumbnails/` 目录
- 首次访问时自动生成，后续直接读取缓存
- 失败时自动降级到原图

### 分页功能

文件列表现在支持分页：
- 默认每页显示 20 个文件
- 智能页码显示（省略中间页码）
- 支持上一页/下一页导航
- 显示当前页码范围信息

分页控制：
- URL 参数 `?page=1` - 页码（从1开始）
- URL 参数 `?per_page=20` - 每页文件数
- 示例：`/?page=2&per_page=30`

---

## 完整部署步骤

### 方法一：更新现有部署（推荐）

```bash
# 1. 登录服务器
ssh root@47.113.204.202

# 2. 进入项目目录
cd /root/00-webAlbum

# 3. 拉取最新代码
git pull origin main

# 4. 停止服务
sudo systemctl stop webalbum

# 5. 激活虚拟环境
source venv/bin/activate

# 6. 更新依赖（修复 NumPy 兼容性）
pip install -r requirements.txt --force-reinstall

# 7. 验证 OpenCV 能正常导入
python -c "import cv2; import numpy; print('✓ OpenCV 和 NumPy 导入成功')"

# 8. 重启服务
sudo systemctl start webalbum

# 9. 查看状态和日志
sudo systemctl status webalbum
tail -f /var/log/syslog | grep webalbum
```

### 方法二：全新部署

如果之前部署有问题，可以完全重新部署：

```bash
# 1. 停止并清除旧服务
sudo systemctl stop webalbum
sudo systemctl disable webalbum
sudo rm /etc/systemd/system/webalbum.service
sudo systemctl daemon-reload
cd /root
rm -rf 00-webAlbum

# 2. 克隆项目（或上传文件）
git clone git@github.com:Heureka-L/web-album.git 00-webAlbum
cd 00-webAlbum

# 3. 运行安装脚本
chmod +x install.sh
./install.sh

# 4. 启动服务
sudo systemctl start webalbum

# 5. 查看状态
sudo systemctl status webalbum
```

---

## 验证修复成功

### 检查依赖版本

```bash
cd /root/00-webAlbum
source venv/bin/activate
pip list | grep -E "numpy|opencv"
```

预期输出：
```
numpy                1.26.4
opencv-python-headless 4.9.0.80
```

### 测试缩略图生成

```bash
# 测试导入OpenCV
python -c "
import cv2
import numpy as np
print('✓ NumPy 版本:', np.__version__)
print('✓ OpenCV 版本:', cv2.__version__)
print('✓ 导入成功，可以生成缩略图')
"
```

### 测试Web应用

1. 访问 `http://47.113.204.202:5000`
2. 登录账号
3. 打开包含视频的文件夹
4. 确认视频缩略图正常显示
5. 确认分页功能正常工作
6. 检查浏览器控制台无错误

---

## 故障排查

### 问题1：NumPy 版本仍然不兼容

```bash
# 强制降级 NumPy
source venv/bin/activate
pip install 'numpy<2.0.0' --force-reinstall

# 删除缓存重新安装
rm -rf venv/lib/python*/site-packages/numpy*
pip install 'numpy<2.0.0'
```

### 问题2：OpenCV 导入失败

```bash
# 检查是否有其他包冲突
source venv/bin/activate
pip list | grep numpy

# 如果有多个 numpy 版本，清理后重装
pip uninstall numpy opencv-python-headless -y
pip install 'numpy<2.0.0' opencv-python-headless
```

### 问题3：缩略图仍未生成

```bash
# 清理缩略图缓存
cd /root/00-webAlbum
rm -rf thumbnails/*

# 重启服务
sudo systemctl restart webalbum

# 查看日志
sudo journalctl -u webalbum -f
```

### 问题4：分页功能显示异常

```bash
# 检查 app.py 是否正确更新
cd /root/00-webAlbum
git status
git diff origin/main

# 如果有未提交的更改，解决后重新部署
git stash
git pull
```

---

## 性能优化建议

### 缩略图缓存

缩略图生成后会被缓存，后续访问会更快。如果需要清理缓存：

```bash
# 清理所有缩略图
rm -rf thumbnails/*

# 只清理特定用户的缩略图（如果实现了用户隔离）
# find thumbnails/ -name "用户ID_*" -delete
```

### 分页调整

要调整每页显示的文件数，修改 `app.py`：

```python
per_page = request.args.get('per_page', 50, type=int)  # 改为 50
```

或通过 URL 参数调整：
```
/?per_page=50
```

---

## 更新日志

**f110938** - 2026-02-07
- ✅ 修复 NumPy 2.x 与 opencv-python-headless 兼容性问题
- ✅ 实现图片和视频统一缩略图功能
- ✅ 添加文件列表分页功能
- ✅ 优化前端加载性能
- ✅ 添加响应式分页样式

---

## 相关文件

- `requirements.txt` - 依赖配置
- `app.py` - 主应用文件（缩略图和分页逻辑）
- `templates/index.html` - 前端模板（分页UI）
- `static/style.css` - 分页样式
