#!/bin/bash
# Cron job script for pet ingestion
# This can be called by Render Cron Jobs

# Get the Render service URL from environment or use default
API_URL="${RENDER_SERVICE_URL:-http://localhost:10000}"

echo "Triggering pet ingestion at $(date)"
curl -X POST "${API_URL}/api/pets/ingest" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  || echo "Error: Failed to trigger ingestion"

