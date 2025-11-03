#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

# Script to combine original keys with ClinGen CA IDs
# Maintains strict order integrity for database loading

ORIGINAL_FILE="${1:-no_ca_ids.jsonl.gz}"
BATCH_DIR="${2:-batches/json}"
KEYS_FILE="${3:-keys.txt}"
CA_IDS_FILE="${4:-ca_ids.txt}"
OUTPUT_FILE="${5:-result.jsonl}"

EXPECTED_LINES=693602957

echo "=============================================="
echo "ClinGen Data Combination Script"
echo "=============================================="
echo "Original file: ${ORIGINAL_FILE}"
echo "Batch directory: ${BATCH_DIR}"
echo "Expected lines: ${EXPECTED_LINES}"
echo ""

# ==============================================================================
# Phase 1: Extract Keys from Original File
# ==============================================================================
if [ -f "${KEYS_FILE}" ]; then
    EXISTING_KEYS=$(wc -l < "${KEYS_FILE}")
    echo "[Phase 1] SKIP: Keys file exists (${EXISTING_KEYS} lines)"
else
    echo "[Phase 1] Extracting keys from ${ORIGINAL_FILE}..."
    echo "  This will take several minutes..."
    
    # Extract first element of each JSON array (the key)
    gzip -cd "${ORIGINAL_FILE}" | jq -r '.[0]' > "${KEYS_FILE}"
    
    KEY_COUNT=$(wc -l < "${KEYS_FILE}")
    echo "[Phase 1] COMPLETE: Extracted ${KEY_COUNT} keys"
    
    if [ "${KEY_COUNT}" -ne "${EXPECTED_LINES}" ]; then
        echo "  WARNING: Key count (${KEY_COUNT}) does not match expected (${EXPECTED_LINES})"
    fi
fi
echo ""

# ==============================================================================
# Phase 2: Extract CA IDs from Batch JSON Files (ORDER-CRITICAL!)
# ==============================================================================
if [ -f "${CA_IDS_FILE}" ]; then
    EXISTING_CA_IDS=$(wc -l < "${CA_IDS_FILE}")
    echo "[Phase 2] SKIP: CA IDs file exists (${EXISTING_CA_IDS} lines)"
else
    echo "[Phase 2] Extracting CA IDs from batch JSON files..."
    echo "  Processing batches in numeric order (CRITICAL for data integrity)"
    echo "  This will take 10-20 minutes..."
    echo ""
    
    # Remove any existing partial file
    rm -f "${CA_IDS_FILE}.tmp"
    
    # Process batch files in numeric order: 000, 001, 002, ..., 693
    # CRITICAL: Must use proper numeric sort, not lexicographic
    BATCH_FILES=$(ls -1 "${BATCH_DIR}"/hgvs_batch_*.json | sort -t_ -k3 -n)
    TOTAL_BATCHES=$(echo "${BATCH_FILES}" | wc -l | tr -d ' ')
    CURRENT=0
    
    for batch_file in ${BATCH_FILES}; do
        CURRENT=$((CURRENT + 1))
        BATCH_NAME=$(basename "${batch_file}" .json)
        
        # Extract @id from each object in the JSON array
        jq -r '.[] | ."@id"' "${batch_file}" >> "${CA_IDS_FILE}.tmp"
        
        # Progress indicator every 50 batches
        if [ $((CURRENT % 50)) -eq 0 ]; then
            CURRENT_LINES=$(wc -l < "${CA_IDS_FILE}.tmp")
            echo "  [${CURRENT}/${TOTAL_BATCHES}] Processed ${BATCH_NAME} (${CURRENT_LINES} total CA IDs)"
        fi
    done
    
    # Move temp file to final location
    mv "${CA_IDS_FILE}.tmp" "${CA_IDS_FILE}"
    
    CA_ID_COUNT=$(wc -l < "${CA_IDS_FILE}")
    echo ""
    echo "[Phase 2] COMPLETE: Extracted ${CA_ID_COUNT} CA IDs"
    
    if [ "${CA_ID_COUNT}" -ne "${EXPECTED_LINES}" ]; then
        echo "  WARNING: CA ID count (${CA_ID_COUNT}) does not match expected (${EXPECTED_LINES})"
    fi
fi
echo ""

# ==============================================================================
# Phase 3: Combine Keys and CA IDs Line-by-Line
# ==============================================================================
if [ -f "${OUTPUT_FILE}" ]; then
    EXISTING_OUTPUT=$(wc -l < "${OUTPUT_FILE}")
    echo "[Phase 3] SKIP: Output file exists (${EXISTING_OUTPUT} lines)"
else
    echo "[Phase 3] Combining keys and CA IDs..."
    echo "  Creating JSONL output: ${OUTPUT_FILE}"
    echo "  This will take 10-15 minutes..."
    echo ""
    
    # Read both files line-by-line in parallel and create JSONL
    # Using paste + awk for efficiency with large files
    paste "${KEYS_FILE}" "${CA_IDS_FILE}" | \
        awk -F'\t' '{printf "{\"_key\":\"%s\",\"ca_id\":\"%s\"}\n", $1, $2}' \
        > "${OUTPUT_FILE}"
    
    OUTPUT_COUNT=$(wc -l < "${OUTPUT_FILE}")
    echo "[Phase 3] COMPLETE: Created ${OUTPUT_COUNT} records"
    
    if [ "${OUTPUT_COUNT}" -ne "${EXPECTED_LINES}" ]; then
        echo "  WARNING: Output count (${OUTPUT_COUNT}) does not match expected (${EXPECTED_LINES})"
    fi
fi
echo ""

# ==============================================================================
# Phase 4: Validation
# ==============================================================================
echo "[Phase 4] Validating results..."
echo ""

# Check line counts
KEY_COUNT=$(wc -l < "${KEYS_FILE}")
CA_ID_COUNT=$(wc -l < "${CA_IDS_FILE}")
OUTPUT_COUNT=$(wc -l < "${OUTPUT_FILE}")

echo "Line counts:"
echo "  Keys:      ${KEY_COUNT}"
echo "  CA IDs:    ${CA_ID_COUNT}"
echo "  Output:    ${OUTPUT_COUNT}"
echo "  Expected:  ${EXPECTED_LINES}"
echo ""

if [ "${KEY_COUNT}" -eq "${CA_ID_COUNT}" ] && [ "${OUTPUT_COUNT}" -eq "${EXPECTED_LINES}" ]; then
    echo "✓ Line counts match!"
else
    echo "✗ WARNING: Line count mismatch detected!"
fi
echo ""

# Sample validation - first 5 lines
echo "Sample output (first 5 lines):"
head -5 "${OUTPUT_FILE}"
echo ""

echo "Sample output (last 5 lines):"
tail -5 "${OUTPUT_FILE}"
echo ""

# Validate JSON format on sample
echo "Validating JSON format (sample check)..."
if head -100 "${OUTPUT_FILE}" | jq -e '.' > /dev/null 2>&1; then
    echo "✓ JSON format valid"
else
    echo "✗ WARNING: JSON format validation failed"
fi
echo ""

# Show file sizes
echo "File sizes:"
ls -lh "${KEYS_FILE}" "${CA_IDS_FILE}" "${OUTPUT_FILE}"
echo ""

echo "=============================================="
echo "Process Complete!"
echo "=============================================="
echo "Output file: ${OUTPUT_FILE}"
echo "Ready for database loading"
echo ""
