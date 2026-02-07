#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Heureka Album - 网页相册应用
支持浏览、预览和下载服务器上的图片、视频和其他文件
包含用户登录系统和个性化相册路径设置
"""

import os
from flask import Flask, render_template, send_from_directory, request, jsonify, redirect, url_for, flash, send_file
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps
from pathlib import Path
import sqlite3
import datetime

app = Flask(__name__)
app.secret_key = 'your-secret-key-change-this-in-production'
app.config['UPLOAD_FOLDER'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
app.config['DATABASE'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'users.db')
app.config['THUMBNAIL_FOLDER'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'thumbnails', 'cache')

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
login_manager.login_message = '请先登录'

ALLOWED_EXTENSIONS = {
    '图片': {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'},
    '视频': {'.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm'},
    '文档': {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'},
    '其他': {'.zip', '.rar', '.7z', '.tar', '.gz'}
}

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'thumbnails'), exist_ok=True)
os.makedirs(app.config['THUMBNAIL_FOLDER'], exist_ok=True)


# ==================== 用户系统 ====================

class User(UserMixin):
    def __init__(self, id, username, is_admin=False, album_path=None):
        self.id = id
        self.username = username
        self.is_admin = is_admin
        self.album_path = album_path

    @staticmethod
    def get(user_id):
        conn = get_db()
        user = conn.execute('SELECT * FROM users WHERE id = ?', (user_id,)).fetchone()
        conn.close()
        if user:
            album_path = user['album_path'] if 'album_path' in user.keys() else None
            return User(user['id'], user['username'], user['is_admin'], album_path)
        return None


@login_manager.user_loader
def load_user(user_id):
    return User.get(user_id)


def get_db():
    conn = sqlite3.connect(app.config['DATABASE'])
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()

    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            is_admin INTEGER DEFAULT 0,
            album_path TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    try:
        columns = conn.execute("PRAGMA table_info(users)").fetchall()
        column_names = [col[1] for col in columns]

        if 'album_path' not in column_names:
            conn.execute('ALTER TABLE users ADD COLUMN album_path TEXT')
            conn.commit()
            print("数据库迁移完成：已添加 album_path 列")
    except Exception as e:
        print(f"数据库迁移警告: {e}")

    conn.close()


def has_admin():
    conn = get_db()
    count = conn.execute('SELECT COUNT(*) as count FROM users WHERE is_admin = 1').fetchone()['count']
    conn.close()
    return count > 0


def require_admin(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated:
            return redirect(url_for('login'))
        if not current_user.is_admin:
            flash('需要管理员权限', 'error')
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated_function


def get_user_upload_folder(user_id):
    conn = get_db()
    user = conn.execute('SELECT album_path FROM users WHERE id = ?', (user_id,)).fetchone()
    conn.close()

    if user and user['album_path']:
        album_path = user['album_path']
        if os.path.isabs(album_path):
            return album_path
        else:
            return os.path.join(os.path.dirname(os.path.abspath(__file__)), album_path)
    else:
        return app.config['UPLOAD_FOLDER']


# ==================== 文件管理 ====================

def get_file_info(file_path, base_folder):
    try:
        stat = os.stat(file_path)
        size = stat.st_size
        mtime = stat.st_mtime
        return {
            'name': os.path.basename(file_path),
            'path': os.path.relpath(file_path, base_folder),
            'size': size,
            'size_mb': round(size / (1024 * 1024), 2),
            'modified': mtime,
            'modified_formatted': datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S'),
            'is_dir': os.path.isdir(file_path)
        }
    except Exception as e:
        print(f"获取文件信息错误: {e}")
        return None


def classify_file(filename):
    ext = os.path.splitext(filename)[1].lower()
    for category, extensions in ALLOWED_EXTENSIONS.items():
        if ext in extensions:
            return category
    return '其他'


def format_size(size_bytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"


def list_files(relative_path='', user_id=None):
    if user_id:
        upload_folder = get_user_upload_folder(user_id)
    else:
        upload_folder = app.config['UPLOAD_FOLDER']

    target_path = os.path.join(upload_folder, relative_path)

    if not os.path.exists(target_path):
        return [], []

    if not os.path.isdir(target_path):
        return [], []

    try:
        entries = os.listdir(target_path)
        entries.sort(key=lambda x: x.lower())

        dirs = []
        files = []

        for entry in entries:
            full_path = os.path.join(target_path, entry)
            info = get_file_info(full_path, upload_folder)
            if info:
                if info['is_dir']:
                    dirs.append(info)
                else:
                    info['category'] = classify_file(entry)
                    info['size_formatted'] = format_size(info['size'])
                    files.append(info)

        return dirs, files
    except PermissionError:
        return [], []


def get_breadcrumb(relative_path):
    parts = relative_path.split(os.sep) if relative_path else []
    breadcrumb = [{'name': '根目录', 'path': ''}]
    current_path = ''
    for part in parts:
        if part:
            current_path = os.path.join(current_path, part) if current_path else part
            breadcrumb.append({'name': part, 'path': current_path})
    return breadcrumb


# ==================== 路由 ====================

@app.route('/')
@login_required
def index():
    base_path = request.args.get('path', '')
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 100, type=int)
    
    dirs, files = list_files(base_path, current_user.id)
    breadcrumb = get_breadcrumb(base_path)
    
    groups = {'图片': [], '视频': [], '文档': [], '其他': []}
    for file in files:
        if file['category'] in groups:
            groups[file['category']].append(file)
    
    images = groups['图片']
    videos = groups['视频']
    other_files = groups['文档'] + groups['其他']
    
    images_per_page = 100
    videos_per_page = 40
    
    image_total_pages = max(1, (len(images) + images_per_page - 1) // images_per_page)
    video_total_pages = max(1, (len(videos) + videos_per_page - 1) // videos_per_page)
    
    all_files = images + videos + other_files
    total_files = len(all_files)
    total_pages = max(1, (total_files + per_page - 1) // per_page)
    
    start_idx = (page - 1) * per_page
    end_idx = start_idx + per_page
    
    paginated_files = all_files[start_idx:end_idx]
    display_end = min(end_idx, total_files)
    display_start = start_idx + 1 if total_files > 0 else 0
    
    return render_template('index.html',
                         dirs=dirs,
                         files=paginated_files,
                         groups=groups,
                         current_path=base_path,
                         breadcrumb=breadcrumb,
                         page=page,
                         per_page=per_page,
                         total_pages=total_pages,
                         total_files=total_files,
                         image_count=len(images),
                         video_count=len(videos),
                         display_start=display_start,
                         display_end=display_end)


@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    if not has_admin():
        return render_template('setup.html')

    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        if not username or not password:
            flash('用户名和密码不能为空', 'error')
            return render_template('login.html')

        conn = get_db()
        user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()

        if user and check_password_hash(user['password'], password):
            album_path = user['album_path'] if 'album_path' in user.keys() else None
            user_obj = User(user['id'], user['username'], user['is_admin'], album_path)
            login_user(user_obj)
            flash(f'欢迎回来，{username}！', 'success')
            return redirect(url_for('index'))
        else:
            flash('用户名或密码错误', 'error')

    return render_template('login.html')


@app.route('/setup', methods=['POST'])
def setup():
    if has_admin():
        return redirect(url_for('login'))

    username = request.form.get('username')
    password = request.form.get('password')
    confirm_password = request.form.get('confirm_password')

    if not username or not password:
        flash('用户名和密码不能为空', 'error')
        return render_template('setup.html')

    if password != confirm_password:
        flash('两次输入的密码不一致', 'error')
        return render_template('setup.html')

    if len(password) < 6:
        flash('密码至少需要6个字符', 'error')
        return render_template('setup.html')

    try:
        conn = get_db()
        conn.execute(
            'INSERT INTO users (username, password, is_admin) VALUES (?, ?, 1)',
            (username, generate_password_hash(password))
        )
        conn.commit()
        conn.close()

        flash('管理员账户创建成功，请登录', 'success')
        return redirect(url_for('login'))
    except sqlite3.IntegrityError:
        flash('用户名已存在', 'error')
        return render_template('setup.html')


@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('已成功登出', 'info')
    return redirect(url_for('login'))


@app.route('/users')
@login_required
@require_admin
def users():
    conn = get_db()
    users = conn.execute('SELECT * FROM users ORDER BY created_at DESC').fetchall()
    conn.close()
    return render_template('users.html', users=users)


@app.route('/users/add', methods=['POST'])
@login_required
@require_admin
def add_user():
    username = request.form.get('username')
    password = request.form.get('password')
    is_admin = request.form.get('is_admin') == 'on'

    if not username or not password:
        flash('用户名和密码不能为空', 'error')
        return redirect(url_for('users'))

    if len(password) < 6:
        flash('密码至少需要6个字符', 'error')
        return redirect(url_for('users'))

    try:
        conn = get_db()
        conn.execute(
            'INSERT INTO users (username, password, is_admin) VALUES (?, ?, ?)',
            (username, generate_password_hash(password), 1 if is_admin else 0)
        )
        conn.commit()
        conn.close()
        flash(f'用户 {username} 添加成功', 'success')
    except sqlite3.IntegrityError:
        flash('用户名已存在', 'error')

    return redirect(url_for('users'))


@app.route('/users/<int:user_id>/delete', methods=['POST'])
@login_required
@require_admin
def delete_user(user_id):
    if user_id == current_user.id:
        flash('不能删除自己', 'error')
        return redirect(url_for('users'))

    conn = get_db()
    conn.execute('DELETE FROM users WHERE id = ?', (user_id,))
    conn.commit()
    conn.close()
    flash('用户删除成功', 'success')
    return redirect(url_for('users'))


@app.route('/settings', methods=['GET', 'POST'])
@login_required
def settings():
    if request.method == 'POST':
        album_path = request.form.get('album_path', '').strip()

        if album_path:
            if os.path.isabs(album_path):
                target_path = album_path
            else:
                target_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), album_path)

            if not os.path.exists(target_path):
                flash('指定的路径不存在', 'error')
                return redirect(url_for('settings'))

            if not os.path.isdir(target_path):
                flash('指定的路径不是一个文件夹', 'error')
                return redirect(url_for('settings'))

        conn = get_db()
        conn.execute('UPDATE users SET album_path = ? WHERE id = ?', (album_path or None, current_user.id))
        conn.commit()
        conn.close()

        flash('设置保存成功', 'success')
        return redirect(url_for('settings'))

    return render_template('settings.html')


@app.route('/view/<path:filename>')
@login_required
def view_file(filename):
    base_path = os.path.dirname(filename) if os.sep in filename else ''
    file_name = os.path.basename(filename)
    
    upload_folder = get_user_upload_folder(current_user.id)
    target_path = os.path.join(upload_folder, filename)

    if not os.path.exists(target_path):
        target_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)

    if not os.path.exists(target_path):
        return "文件不存在", 404

    file_ext = os.path.splitext(file_name)[1].lower()
    content_type = 'application/octet-stream'
    
    if file_ext in {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}:
        content_type = 'image/jpeg'
    elif file_ext == '.svg':
        content_type = 'image/svg+xml'
    elif file_ext in {'.mp4', '.avi', '.mov', '.mkv', '.webm'}:
        content_type = 'video/mp4'

    return send_from_directory(os.path.dirname(target_path), os.path.basename(target_path), mimetype=content_type)


@app.route('/download/<path:filename>')
@login_required
def download_file(filename):
    upload_folder = get_user_upload_folder(current_user.id)
    target_path = os.path.join(upload_folder, filename)

    if not os.path.exists(target_path):
        target_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)

    if not os.path.exists(target_path):
        return "文件不存在", 404

    return send_from_directory(os.path.dirname(target_path), os.path.basename(target_path), as_attachment=True)


@app.route('/thumbnail/<path:filename>')
@login_required
def get_thumbnail(filename):
    ext = os.path.splitext(filename)[1].lower()
    
    safe_filename = filename.replace(os.sep, '_').replace('/', '_').replace('\\', '_')
    
    if ext in ALLOWED_EXTENSIONS['图片']:
        thumbnail_filename = os.path.splitext(safe_filename)[0] + '_thumb.jpg'
        thumbnail_size = (300, 300)
    elif ext in ALLOWED_EXTENSIONS['视频']:
        thumbnail_filename = os.path.splitext(safe_filename)[0] + '_video.jpg'
        thumbnail_size = (320, 200)
    else:
        return redirect(url_for('static', filename='style.css'))
    
    thumbnail_path = os.path.join(app.config['THUMBNAIL_FOLDER'], thumbnail_filename)
    
    if os.path.exists(thumbnail_path) and os.path.getsize(thumbnail_path) > 0:
        return send_file(thumbnail_path, mimetype='image/jpeg')
    
    upload_folder = get_user_upload_folder(current_user.id)
    source_path = os.path.join(upload_folder, filename)
    
    if not os.path.exists(source_path):
        source_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    if not os.path.exists(source_path):
        print(f"源文件不存在: {source_path}")
        return redirect(url_for('static', filename='style.css'))
    
    if not os.access(source_path, os.R_OK):
        print(f"源文件无法读取: {source_path}")
        return redirect(url_for('static', filename='style.css'))
    
    try:
        import cv2
        
        print(f"开始生成缩略图: {source_path} -> {thumbnail_path}")
        
        cap = cv2.VideoCapture(source_path)
        
        if not cap.isOpened():
            print(f"无法打开视频: {source_path}")
            cap.release()
            return redirect(url_for('static', filename='style.css'))
        
        ret, frame = cap.read()
        
        if not ret:
            print(f"无法读取视频帧: {source_path}")
            cap.release()
            return redirect(url_for('static', filename='style.css'))
        
        resized = cv2.resize(frame, thumbnail_size, interpolation=cv2.INTER_AREA)
        cv2.imwrite(thumbnail_path, resized)
        
        cap.release()
        
        if os.path.exists(thumbnail_path) and os.path.getsize(thumbnail_path) > 0:
            print(f"缩略图生成成功: {thumbnail_path} ({os.path.getsize(thumbnail_path)} bytes)")
            return send_file(thumbnail_path, mimetype='image/jpeg')
        else:
            print(f"缩略图生成失败: {thumbnail_path}")
            return redirect(url_for('static', filename='style.css'))
            
    except Exception as e:
        print(f"生成缩略图失败 {filename}: {e}")
        import traceback
        traceback.print_exc()
        
        if os.path.exists(thumbnail_path):
            os.remove(thumbnail_path)
        
        return redirect(url_for('static', filename='style.css'))


@app.route('/api/files')
@login_required
def api_files():
    base_path = request.args.get('path', '')
    dirs, files = list_files(base_path, current_user.id)
    return jsonify({
        'dirs': dirs,
        'files': files,
        'current_path': base_path
    })


@app.route('/api/stats')
@login_required
def api_stats():
    upload_folder = get_user_upload_folder(current_user.id)
    total_files = sum(1 for root, dirs, files in os.walk(upload_folder) for file in files)
    total_dirs = sum(1 for root, dirs, files in os.walk(upload_folder) for dir in dirs)
    total_size = sum(os.path.getsize(os.path.join(root, file)) for root, dirs, files in os.walk(upload_folder) for file in files)
    return jsonify({
        'total_files': total_files,
        'total_dirs': total_dirs,
        'total_size': total_size,
        'total_size_formatted': format_size(total_size)
    })


if __name__ == '__main__':
    init_db()

    print("=" * 60)
    print("Heureka Album - 网页相册应用")
    print("=" * 60)
    print(f"上传目录: {app.config['UPLOAD_FOLDER']}")
    print(f"数据库: {app.config['DATABASE']}")
    print("访问地址: http://localhost:5000")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=False)
