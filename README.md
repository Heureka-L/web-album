# Flask 网页相册

一个基于 Flask 的安全网页相册系统，支持浏览、预览和下载服务器上的图片、视频和文档文件。

## 功能特性

- 文件浏览：浏览服务器上的文件夹和文件
- 图片预览：在线预览图片文件
- 视频播放：支持视频文件流媒体播放
- 文件下载：安全的文件下载功能
- 用户认证：登录认证系统
- 用户管理：管理员可添加/删除用户
- 后台运行：支持后台运行，关闭终端不影响服务
- 开机自启：配置 systemd 服务，开机自动启动

## 文件分类支持

- 图片：.jpg, .jpeg, .png, .gif, .bmp, .webp, .svg
- 视频：.mp4, .avi, .mov, .mkv, .wmv, .flv, .webm
- 文档：.pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt
- 其他：.zip, .rar, .7z, .tar, .gz

## 系统要求

- Python 3.7 或更高版本
- Linux 操作系统（支持 systemd）
- sudo 权限（用于安装 systemd 服务）

## 快速开始

### 1. 安装

运行自动安装脚本：

```bash
chmod +x install.sh
./install.sh
```

安装脚本会自动完成以下操作：
- 创建 Python 虚拟环境
- 安装所有依赖包
- 配置 systemd 服务
- 设置开机自启动

### 2. 启动服务

```bash
sudo systemctl start webalbum
```

### 3. 访问应用

打开浏览器访问：`http://localhost:5000`

### 4. 首次使用

首次访问会显示初始化页面，创建管理员账号。

## 使用指南

### 服务管理

使用 systemd 管理服务：

```bash
# 启动服务
sudo systemctl start webalbum

# 停止服务  
sudo systemctl stop webalbum

# 重启服务
sudo systemctl restart webalbum

# 查看服务状态
sudo systemctl status webalbum

# 查看日志
sudo journalctl -u webalbum -f

# 禁用开机自启
sudo systemctl disable webalbum

# 启用开机自启
sudo systemctl enable webalbum
```

### 手动运行（不使用 systemd）

如果不想使用 systemd，可以使用 run.sh 脚本：

```bash
# 启动（后台运行）
./run.sh start

# 停止
./run.sh stop

# 重启
./run.sh restart

# 查看状态
./run.sh status

# 查看日志
./run.sh logs
```

### 添加文件

将需要展示的文件和文件夹放入 `uploads` 目录中，系统会自动识别和显示。

## 用户管理

### 管理员功能

只有管理员账号可以访问用户管理页面（首页右上角点击"用户管理"）。

### 添加用户

管理员可以添加新用户：
- 输入用户名和密码
- 选择是否授予管理员权限

### 删除用户

管理员可以删除普通用户，但不能删除自己。

## 安全说明

- 所有页面都需要登录认证才能访问
- 密码使用 werkzeug 安全哈希存储
- 首次运行需要创建管理员账号
- 只有管理员可以管理用户

## 项目结构

```
.
├── app.py           # Flask 主应用文件
├── requirements.txt # Python 依赖
├── install.sh       # 自动安装脚本
├── run.sh          # 手动运行脚本
├── templates/      # HTML 模板
│   ├── index.html  # 主页面
│   ├── login.html  # 登录页面
│   ├── setup.html  # 初始化页面
│   └── users.html  # 用户管理页面
├── static/         # 静态文件
│   └── style.css   # 样式文件
├── uploads/        # 文件存储目录
├── logs/           # 日志目录
└── users.db        # 用户数据库（首次运行自动创建）
```

## 常见问题

### 端口被占用

如果 5000 端口被占用，修改 `app.py` 中的端口号：

```python
app.run(host='0.0.0.0', port=5001, debug=False)
```

### 无法访问

检查防火墙设置：

```bash
# 开放 5000 端口
sudo ufw allow 5000
```

### 重置密码

删除 `users.db` 文件，重启服务后重新创建管理员：

```bash
rm users.db
sudo systemctl restart webalbum
```

## 技术栈

- Backend: Flask, Flask-Login
- Database: SQLite
- Authentication: Werkzeug security
- Deployment: systemd

## 许可证

MIT License
