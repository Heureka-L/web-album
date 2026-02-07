# Flask 网页相册 - 错误修复说明

## 已修复的问题

### 问题 1: `AttributeError: 'sqlite3.Row' object has no attribute 'get'`

**原因**：`sqlite3.Row` 对象不支持 `.get()` 方法，只支持索引访问。

**修复位置**：
- `app.py` 第 55 行
- `app.py` 第 242 行

**修复方法**：
将 `user.get('album_path')` 改为：
```python
album_path = user['album_path'] if 'album_path' in user.keys() else None
```

### 问题 2: `sqlite3.OperationalError: no such column: album_path`

**原因**：旧数据库缺少 `album_path` 列。

**修复位置**：`app.py` 的 `init_db()` 函数

**修复方法**：添加数据库迁移逻辑
```python
try:
    columns = conn.execute("PRAGMA table_info(users)").fetchall()
    column_names = [col[1] for col in columns]

    if 'album_path' not in column_names:
        conn.execute('ALTER TABLE users ADD COLUMN album_path TEXT')
        conn.commit()
        print("数据库迁移完成：已添加 album_path 列")
except Exception as e:
    print(f"数据库迁移警告: {e}")
```

## 服务器部署步骤

### 1. 更新应用代码

将修复后的 `app.py` 上传到服务器的项目目录：

```bash
# 在本地修复代码后
scp app.py root@47.113.204.202:/path/to/webalbum/
```

### 2. 运行诊断脚本

在服务器上运行诊断脚本检查整体状态：

```bash
cd /path/to/webalbum
chmod +x diagnose.sh
./diagnose.sh
```

### 3. 处理旧数据库

如果服务器上有旧的 `users.db`，有两个选择：

**选项 A：保留旧数据库（推荐）**
- 应用启动时会自动迁移数据库，添加缺失的列

**选项 B：删除旧数据库重新创建**
```bash
cd /path/to/webalbum
rm users.db
```

### 4. 重启服务

```bash
# 停止服务
sudo systemctl stop webalbum

# 重新安装（如果需要）
./install.sh

# 或手动重启
sudo systemctl restart webalbum

# 查看状态
sudo systemctl status webalbum

# 查看日志
sudo journalctl -u webalbum -n 50 --no-pager
```

### 5. 测试访问

在浏览器中访问服务器：
```
http://47.113.204.202:5000
```

首次访问会显示初始化页面，创建管理员账号。

## 故障排查

### 如果服务启动失败

1. 检查详细错误日志：
```bash
sudo journalctl -u webalbum -n 100 --no-pager
```

2. 检查本地日志：
```bash
cd /path/to/webalbum
cat logs/webalbum.out.log
cat logs/webalbum.err.log
```

3. 手动运行查看错误：
```bash
cd /path/to/webalbum
source venv/bin/activate
python app.py
```

### 如果端口被占用

```bash
# 查找占用端口的进程
sudo lsof -i :5000

# 或
sudo netstat -tuln | grep 5000

# 停止占用的进程
sudo kill <PID>

# 然后重启服务
sudo systemctl restart webalbum
```

### 如果依赖安装失败

```bash
cd /path/to/webalbum
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 验证修复

运行诊断脚本，应该看到所有检查项都通过：

```bash
./diagnose.sh
```

预期输出应包含：
- ✅ Python 环境正常
- ✅ 所有依赖已安装
- ✅ 文件结构完整
- ✅ 数据库正常
- ✅ 服务运行中
- ✅ 应用响应正常

## 防火墙设置

如果无法从外部访问，检查防火墙：

```bash
# Ubuntu/Debian
sudo ufw allow 5000

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

## 完整安装流程（新服务器）

如果是新服务器部署，执行以下步骤：

```bash
# 1. 上传项目文件到服务器
scp -r . root@47.113.204.202:/opt/webalbum/

# 2. SSH 登录到服务器
ssh root@47.113.204.202

# 3. 进入项目目录
cd /opt/webalbum

# 4. 运行安装脚本
chmod +x install.sh
./install.sh

# 5. 启动服务
sudo systemctl start webalbum

# 6. 设置开机自启
sudo systemctl enable webalbum

# 7. 检查状态
sudo systemctl status webalbum

# 8. 测试访问
curl http://localhost:5000
```

## 技术联系

如遇到问题，请提供以下信息：

1. 运行 `./diagnose.sh` 的完整输出
2. `/etc/systemd/system/webalbum.service` 的内容
3. `sudo journalctl -u webalbum -n 100` 的日志
4. `app.py` 的版本（git commit hash 或修改日期）
