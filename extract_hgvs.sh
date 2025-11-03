#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

# Script to extract HGVS notation from JSONL file
# Input: no_ca_ids.jsonl.gz (format: [key, hgvs])
# Output: hgvs_list.txt (plain text, one HGVS per line)

INPUT_FILE="${1:-no_ca_ids.jsonl.gz}"
OUTPUT_FILE="${2:-hgvs_list.txt}"

echo "Extracting HGVS values from ${INPUT_FILE}..."
echo "Output will be written to ${OUTPUT_FILE}"

# Decompress, parse JSON, extract second element (HGVS)
gzip -cd "${INPUT_FILE}" | jq -r '.[1]' > "${OUTPUT_FILE}"

# Count lines and report
LINE_COUNT=$(wc -l < "${OUTPUT_FILE}")
echo "Extraction complete!"
echo "Total HGVS entries extracted: ${LINE_COUNT}"
