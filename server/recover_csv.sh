#!/bin/bash
# Script to recover pets.csv when API comes back online
# This will keep retrying until the API is available

API_URL="https://petfinder-database-distributor.onrender.com/pets.csv"
API_KEY="3h4hdfbhdfesnfsd2439DSFNUIFGSDBJHF"
CSV_PATH="../pets.csv"
MAX_RETRIES=10
RETRY_DELAY=30

echo "Attempting to recover pets.csv from API..."
echo "This script will retry up to $MAX_RETRIES times with $RETRY_DELAY second delays"

for i in $(seq 1 $MAX_RETRIES); do
    echo ""
    echo "Attempt $i of $MAX_RETRIES..."
    
    # Try to download the CSV
    HTTP_CODE=$(curl -s -o "$CSV_PATH" -w "%{http_code}" \
        -H "X-API-Key: $API_KEY" \
        "$API_URL")
    
    if [ "$HTTP_CODE" = "200" ]; then
        LINE_COUNT=$(wc -l < "$CSV_PATH" | tr -d ' ')
        echo "✓ Success! Downloaded CSV with $LINE_COUNT lines"
        echo "File saved to: $CSV_PATH"
        exit 0
    else
        echo "✗ Failed with HTTP code: $HTTP_CODE"
        if [ "$i" -lt "$MAX_RETRIES" ]; then
            echo "Waiting $RETRY_DELAY seconds before retry..."
            sleep $RETRY_DELAY
        fi
    fi
done

echo ""
echo "Failed to recover CSV after $MAX_RETRIES attempts"
echo "The API may still be down. Try again later."
exit 1

