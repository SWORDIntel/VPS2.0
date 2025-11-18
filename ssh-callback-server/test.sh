#!/bin/bash
# Quick test script for SSH Callback Server

SERVER=${1:-http://localhost:5000}
API_KEY=${2:-test-key}

echo "Testing SSH Callback Server"
echo "Server: $SERVER"
echo "=========================================="

# Test 1: Health Check
echo ""
echo "[1] Testing health endpoint..."
HEALTH=$(curl -s "$SERVER/health")
if echo "$HEALTH" | grep -q "healthy"; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    echo "Response: $HEALTH"
fi

# Test 2: Register Callback
echo ""
echo "[2] Testing callback registration..."
CALLBACK=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"$API_KEY\",
    \"hostname\": \"test-server-$(date +%s)\",
    \"username\": \"root\",
    \"ssh_port\": 22,
    \"os_type\": \"linux\",
    \"os_version\": \"Ubuntu 22.04\",
    \"architecture\": \"x86_64\",
    \"environment\": \"test\",
    \"init_system\": \"systemd\",
    \"ssh_implementation\": \"openssh\",
    \"persistence_methods\": [\"systemd_service\", \"cron_job\"]
  }" \
  "$SERVER/api/register")

if echo "$CALLBACK" | grep -q "success"; then
    echo "✓ Callback registration passed"
    echo "Callback ID: $(echo $CALLBACK | grep -o '"callback_id":[0-9]*' | cut -d: -f2)"
else
    echo "✗ Callback registration failed"
    echo "Response: $CALLBACK"
fi

# Test 3: Heartbeat
echo ""
echo "[3] Testing heartbeat..."
HEARTBEAT=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"$API_KEY\",
    \"hostname\": \"test-server\"
  }" \
  "$SERVER/api/heartbeat")

if echo "$HEARTBEAT" | grep -q "success\|warning"; then
    echo "✓ Heartbeat passed"
else
    echo "✗ Heartbeat failed"
    echo "Response: $HEARTBEAT"
fi

# Test 4: Get Stats
echo ""
echo "[4] Testing stats endpoint..."
STATS=$(curl -s -H "X-API-Key: $API_KEY" "$SERVER/api/stats")

if echo "$STATS" | grep -q "total_callbacks"; then
    echo "✓ Stats endpoint passed"
    echo "Total callbacks: $(echo $STATS | grep -o '"total_callbacks":[0-9]*' | cut -d: -f2)"
else
    echo "✗ Stats endpoint failed"
    echo "Response: $STATS"
fi

# Test 5: Get Callbacks
echo ""
echo "[5] Testing callbacks endpoint..."
CALLBACKS=$(curl -s -H "X-API-Key: $API_KEY" "$SERVER/api/callbacks?limit=5")

if echo "$CALLBACKS" | grep -q "callbacks"; then
    echo "✓ Callbacks endpoint passed"
    COUNT=$(echo $CALLBACKS | grep -o '"count":[0-9]*' | cut -d: -f2)
    echo "Callback count: $COUNT"
else
    echo "✗ Callbacks endpoint failed"
    echo "Response: $CALLBACKS"
fi

echo ""
echo "=========================================="
echo "Testing complete!"
echo ""
echo "Dashboard: $SERVER/"
echo "API Key: $API_KEY"
