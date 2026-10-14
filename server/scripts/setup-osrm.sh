#!/usr/bin/env bash
# ==============================================================================
# OSRM Data Pre-Processing Pipeline for Iraq / Baghdad (MLD Algorithm)
# Zero-Paid-API Setup for Darb Platform
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data/osrm"

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

OSM_FILE="iraq-latest.osm.pbf"
DOWNLOAD_URL="https://download.geofabrik.de/asia/${OSM_FILE}"

echo "========================================================"
echo " [Darb Platform] Starting OSRM Data Ingestion for Iraq"
echo "========================================================"

if [ ! -f "${OSM_FILE}" ]; then
    echo ">> Downloading Geofabrik Iraq extract..."
    wget -c "${DOWNLOAD_URL}" -O "${OSM_FILE}"
else
    echo ">> Iraq extract already exists: ${OSM_FILE}"
fi

echo ">> Extracting road graph with car profile..."
docker run --rm -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:v5.27.1 \
    osrm-extract -p /opt/car.lua "/data/${OSM_FILE}"

echo ">> Partitioning graph for Multi-Level Dijkstra (MLD)..."
docker run --rm -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:v5.27.1 \
    osrm-partition "/data/iraq-latest.osrm"

echo ">> Customizing graph cells..."
docker run --rm -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:v5.27.1 \
    osrm-customize "/data/iraq-latest.osrm"

echo "========================================================"
echo " [Darb Platform] OSRM Multi-Level Dijkstra preparation complete!"
echo " Graph files ready in: ${DATA_DIR}"
echo "========================================================"
