#!/usr/bin/env bash
# ==============================================================================
# Production Deployment Script for Darb Navigation & Live Traffic Platform
# Targets Ubuntu Server with Docker Engine & Docker Compose
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

cd "${ROOT_DIR}"

echo "========================================================"
echo " [Darb Platform] Production Deployment Starting"
echo " Target: Ubuntu Server (Baghdad Navigation Stack)"
echo "========================================================"

# Check Docker and Docker Compose
command -v docker >/dev/null 2>&1 || { echo "Error: docker is required but not installed."; exit 1; }

# Check OSRM data availability
if [ ! -f "server/data/osrm/iraq-latest.osrm" ]; then
    echo ">> OSRM routing data not found. Running OSRM pipeline first..."
    bash server/scripts/setup-osrm.sh
fi

echo ">> Pulling / building Docker images..."
docker compose build --pull

echo ">> Starting database and backend services..."
docker compose up -d

echo ">> Waiting for API and database health check..."
sleep 5

MAX_RETRIES=15
COUNTER=0
HEALTHY=false

while [ $COUNTER -lt $MAX_RETRIES ]; do
    if curl -s http://127.0.0.1:5000/health | grep -q "Healthy"; then
        HEALTHY=true
        break
    fi
    echo "Waiting for services to become healthy ($((COUNTER+1))/$MAX_RETRIES)..."
    sleep 3
    COUNTER=$((COUNTER+1))
done

if [ "$HEALTHY" = true ]; then
    echo "========================================================"
    echo " [Darb Platform] DEPLOYMENT SUCCESSFUL!"
    echo " API:         http://localhost:5000"
    echo " Tile Server: http://localhost:8080/tile/{z}/{x}/{y}.png"
    echo " Health:      http://localhost:5000/health"
    echo "========================================================"
else
    echo ">> Deployment completed, but health status is still initializing."
    echo ">> Check logs with: docker compose logs -f"
fi
