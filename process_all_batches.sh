#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

# Script to process all HGVS batch files through ClinGen API
# Queries the ClinGen Allele Registry and retrieves CA IDs

BATCH_DIR="${1:-batches}"
OUTPUT_DIR="${2:-batches/json}"
BATCH_PREFIX="${3:-hgvs_batch_}"
API_URL="http://reg.clinicalgenome.org/alleles.json?file=hgvs&fields=none+@id"

echo "=========================================="
echo "ClinGen Allele Registry Batch Processing"
echo "=========================================="
echo "Batch directory: ${BATCH_DIR}"
echo "Output directory: ${OUTPUT_DIR}"
echo "API endpoint: ${API_URL}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Count total batch files
TOTAL_BATCHES=$(ls -1 "${BATCH_DIR}/${BATCH_PREFIX}"*.txt 2>/dev/null | wc -l)
echo "Total batch files to process: ${TOTAL_BATCHES}"
echo ""

# Process each batch file
CURRENT=0
FAILED=0
SUCCESS=0

for batch_file in "${BATCH_DIR}/${BATCH_PREFIX}"*.txt; do
    CURRENT=$((CURRENT + 1))
    
    # Extract batch number from filename
    BASENAME=$(basename "${batch_file}" .txt)
    OUTPUT_FILE="${OUTPUT_DIR}/${BASENAME}.json"
    
    # Skip if output already exists
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "[${CURRENT}/${TOTAL_BATCHES}] SKIP: ${BASENAME} (already exists)"
        SUCCESS=$((SUCCESS + 1))
        continue
    fi
    
    echo "[${CURRENT}/${TOTAL_BATCHES}] Processing: ${BASENAME}..."
    
    # Make API request
    if ./request_with_payload.sh "${API_URL}" "${batch_file}" > "${OUTPUT_FILE}" 2>/dev/null; then
        # Verify the output is valid JSON and not empty
        if jq -e 'length > 0' "${OUTPUT_FILE}" > /dev/null 2>&1; then
            RECORD_COUNT=$(jq 'length' "${OUTPUT_FILE}")
            echo "[${CURRENT}/${TOTAL_BATCHES}] SUCCESS: ${BASENAME} (${RECORD_COUNT} records)"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "[${CURRENT}/${TOTAL_BATCHES}] FAILED: ${BASENAME} (invalid/empty response)"
            rm -f "${OUTPUT_FILE}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "[${CURRENT}/${TOTAL_BATCHES}] FAILED: ${BASENAME} (API error)"
        rm -f "${OUTPUT_FILE}"
        FAILED=$((FAILED + 1))
    fi
    
    # Brief pause to avoid overwhelming the API
    sleep 1
done

echo ""
echo "=========================================="
echo "Processing Complete!"
echo "=========================================="
echo "Total batches: ${TOTAL_BATCHES}"
echo "Successful: ${SUCCESS}"
echo "Failed: ${FAILED}"
echo "Output location: ${OUTPUT_DIR}/"
echo ""
