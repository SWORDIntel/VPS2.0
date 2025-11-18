#!/bin/bash

# HURRICANE Health Check Script
# Verifies that the HURRICANE daemon is running and responding

API_PORT="${HURRICANE_API_PORT:-8080}"
HEALTH_ENDPOINT="http://localhost:${API_PORT}/api/health"

# Check if the API is responding
if curl -sf "${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
    echo "[HEALTHCHECK] HURRICANE is healthy"
    exit 0
else
    echo "[HEALTHCHECK] HURRICANE is unhealthy - API not responding"
    exit 1
fi
