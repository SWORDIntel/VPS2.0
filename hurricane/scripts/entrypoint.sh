#!/bin/bash
set -e

# HURRICANE Entrypoint Script
# Initializes the HURRICANE IPv6 tunnel daemon

echo "[HURRICANE] Starting initialization..."

# Configuration directory
CONFIG_DIR="/etc/hurricane"
CRED_DIR="${CONFIG_DIR}/credentials"
DATA_DIR="/var/lib/hurricane"
LOG_DIR="/var/log/hurricane"

# Generate configuration from templates if not exists
if [ ! -f "${CONFIG_DIR}/hurricane.conf" ]; then
    echo "[HURRICANE] Generating configuration from template..."
    envsubst < "${CONFIG_DIR}/hurricane.conf.template" > "${CONFIG_DIR}/hurricane.conf"
fi

if [ ! -f "${CONFIG_DIR}/tunnels.conf" ]; then
    echo "[HURRICANE] Generating tunnels configuration from template..."
    envsubst < "${CONFIG_DIR}/tunnels.conf.template" > "${CONFIG_DIR}/tunnels.conf"
fi

# Setup Hurricane Electric tunnel if enabled
if [ "${HE_ENABLED}" = "true" ]; then
    echo "[HURRICANE] Configuring Hurricane Electric tunnel..."

    if [ -z "${HE_USERNAME}" ] || [ -z "${HE_PASSWORD}" ] || [ -z "${HE_TUNNEL_ID}" ]; then
        echo "[HURRICANE] ERROR: HE_USERNAME, HE_PASSWORD, and HE_TUNNEL_ID must be set when HE_ENABLED=true"
        exit 1
    fi

    # Encrypt credentials
    echo -n "${HE_PASSWORD}" | openssl enc -aes-256-cbc -salt -out "${CRED_DIR}/he_password.enc" -pass pass:"$(hostname)"

    cat >> "${CONFIG_DIR}/tunnels.conf" <<EOF

[tunnel.he]
type = "hurricaneelectric"
username = "${HE_USERNAME}"
password_file = "${CRED_DIR}/he_password.enc"
tunnel_id = "${HE_TUNNEL_ID}"
enabled = true
priority = 100
EOF
fi

# Setup Mullvad VPN if enabled
if [ "${MULLVAD_ENABLED}" = "true" ]; then
    echo "[HURRICANE] Configuring Mullvad VPN tunnel..."

    if [ -z "${MULLVAD_ACCOUNT}" ]; then
        echo "[HURRICANE] ERROR: MULLVAD_ACCOUNT must be set when MULLVAD_ENABLED=true"
        exit 1
    fi

    cat >> "${CONFIG_DIR}/tunnels.conf" <<EOF

[tunnel.mullvad]
type = "mullvad"
account = "${MULLVAD_ACCOUNT}"
enabled = true
priority = 90
EOF
fi

# Setup WireGuard if enabled
if [ "${WG_ENABLED}" = "true" ]; then
    echo "[HURRICANE] Configuring WireGuard tunnel..."

    if [ ! -d "${CONFIG_DIR}/wireguard" ] || [ -z "$(ls -A ${CONFIG_DIR}/wireguard/*.conf 2>/dev/null)" ]; then
        echo "[HURRICANE] WARNING: WireGuard enabled but no config files found in ${CONFIG_DIR}/wireguard/"
    else
        for wg_conf in "${CONFIG_DIR}/wireguard"/*.conf; do
            wg_name=$(basename "${wg_conf}" .conf)
            echo "[HURRICANE] Adding WireGuard tunnel: ${wg_name}"

            cat >> "${CONFIG_DIR}/tunnels.conf" <<EOF

[tunnel.${wg_name}]
type = "wireguard"
config_file = "${wg_conf}"
enabled = true
priority = 80
EOF
        done
    fi
fi

# Enable IPv6 forwarding
echo "[HURRICANE] Enabling IPv6 forwarding..."
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding || echo "[HURRICANE] WARNING: Could not enable IPv6 forwarding (may need host sysctl)"
echo 1 > /proc/sys/net/ipv4/ip_forward || echo "[HURRICANE] WARNING: Could not enable IPv4 forwarding (may need host sysctl)"

# Set up iptables rules for NAT
echo "[HURRICANE] Configuring NAT rules..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE || echo "[HURRICANE] WARNING: Could not set up NAT (may need additional capabilities)"

# Create PID directory
mkdir -p /var/run/hurricane
chown hurricane:hurricane /var/run/hurricane

echo "[HURRICANE] Configuration complete. Starting daemon..."
echo "[HURRICANE] API will be available on port ${HURRICANE_API_PORT:-8080}"
echo "[HURRICANE] Web UI will be available on port ${HURRICANE_WEB_UI_PORT:-8081}"
echo "[HURRICANE] SOCKS5 proxy will be available on port ${HURRICANE_SOCKS5_PORT:-1080}"

if [ "${PROMETHEUS_ENABLED}" = "true" ]; then
    echo "[HURRICANE] Prometheus metrics will be available on port ${PROMETHEUS_PORT:-9090}"
fi

# Execute the command
exec "$@"
