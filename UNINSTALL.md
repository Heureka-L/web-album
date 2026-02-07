# 完全卸载 Flask 网页相册项目

## 方法一：使用卸载脚本（推荐）

```bash
cd /path/to/webalbum
chmod +x uninstall.sh
./uninstall.sh
```

脚本会：
- 停止并禁用 systemd 服务
- 删除虚拟环境和 Python 缓存
- 删除数据库、日志、上传文件
- 删除应用代码和配置文件
- 可选：删除整个项目目录

## 方法二：手动卸载

### 1. 停止服务

```bash
sudo systemctl stop webalbum
sudo systemctl disable webalbum
```

### 2. 删除 systemd 服务

```bash
sudo rm /etc/systemd/system/webalbum.service
sudo systemctl daemon-reload
```

### 3. 停止所有 Flask 进程

```bash
pkill -f "python app.py"
pkill -f "python.*app\.py"
```

### 4. 删除项目文件

```bash
cd /path/to/webalbum

# 删除虚拟环境
rm -rf venv

# 删除数据库
rm -f users.db

# 删除日志
rm -rf logs

# 删除应用文件
rm -f app.py
rm -f requirements.txt
rm -f install.sh
rm -f run.sh
rm -f deploy.sh
rm -f diagnose.sh
rm -f uninstall.sh
rm -f FIXES.md
rm -f README.md

# 删除目录
rm -rf templates
rm -rf static
rm -rf uploads
rm -rf thumbnails
rm -rf .git

# 删除其他文件
rm -f webalbum.pid
rm -f *.log
```

### 5. 删除项目目录（可选）

```bash
cd /tmp
rm -rf /path/to/webalbum
```

## 方法三：一键命令（快速清理）

```bash
# 完全卸载（包括项目目录）
cd /path/to/webalbum && \
sudo systemctl stop webalbum && \
sudo systemctl disable webalbum && \
sudo rm /etc/systemd/system/webalbum.service && \
sudo systemctl daemon-reload && \
pkill -f "python app.py" && \
cd /tmp && \
rm -rf /path/to/webalbum && \
echo "卸载完成"
```

## 方法四：仅删除配置（保留代码）

如果你想保留代码但重置所有配置：

```bash
cd /path/to/webalbum

# 停止服务
sudo systemctl stop webalbum

# 删除数据库
rm -f users.db

# 删除日志
rm -rf logs

# 删除上传文件
rm -rf uploads/*

# 删除缩略图
rm -rf thumbnails/*

# 重启服务
sudo systemctl start webalbum
```

## 验证卸载

### 检查服务状态

```bash
sudo systemctl status webalbum
# 应显示 "Unit webalbum.service could not be found" 或 "Loaded: not-found"
```

### 检查端口占用

```bash
sudo lsof -i :5000
# 应该没有输出

# 或
sudo netstat -tuln | grep 5000
# 应该没有输出
```

### 检查进程

```bash
ps aux | grep "python app.py"
# 应该没有输出

# 或
pgrep -f "app.py"
# 应该没有输出
```

### 检查文件

```bash
ls -la /path/to/webalbum
# 应该为空或不包含项目文件

ls -la /etc/systemd/system/webalbum.service
# 应显示 "No such file or directory"
```

## 清理 Python 依赖（可选）

如果不再需要 Flask 等包，可以卸载：

```bash
# 在虚拟环境外卸载（全局安装）
pip3 uninstall flask flask-login werkzeug opencv-python-headless numpy

# 在虚拟环境内卸载
cd /path/to/webalbum
source venv/bin/activate
pip uninstall flask flask-login werkzeug opencv-python-headless numpy
```

## 清理防火墙规则

如果之前添加了防火墙规则，可以删除：

```bash
# Ubuntu/Debian
sudo ufw delete allow 5000

# CentOS/RHEL
sudo firewall-cmd --permanent --remove-port=5000/tcp
sudo firewall-cmd --reload
```

## 重要提示

⚠️ **卸载前注意事项**：

1. **备份重要数据**
   ```bash
   # 备份上传的文件
   cp -r uploads/ /backup/webalbum_uploads/

   # 备份数据库
   cp users.db /backup/
   ```

2. **确认路径**
   - 确保删除的是正确的项目目录
   - 不要误删其他重要文件

3. **检查权限**
   - 需要sudo权限删除 systemd 服务
   - 确保有权限删除项目文件

## 故障排查

### 服务无法停止

```bash
# 强制停止
sudo systemctl kill webalbum

# 或直接 kill 进程
pkill -9 -f "webalbum"
```

### 文件被占用无法删除

```bash
# 查找占用进程
sudo lsof /path/to/file

# 停止占用进程后重试
```

### 虚拟环境删除失败

```bash
# 确保先退出虚拟环境
deactivate

# 强制删除
rm -rf venv
```

## 重新安装

如果卸载后想重新安装：

```bash
# 克隆或下载项目
git clone <repository-url>
cd webalbum

# 或上传项目文件后
cd /path/to/webalbum

# 运行安装脚本
chmod +x install.sh
./install.sh

# 启动服务
sudo systemctl start webalbum
sudo systemctl enable webalbum
```
