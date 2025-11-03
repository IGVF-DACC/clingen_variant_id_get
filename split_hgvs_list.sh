#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

# Script to split large HGVS list into smaller batch files
# Each batch contains up to 1 million lines for manageable API queries

INPUT_FILE="${1:-hgvs_list.txt}"
LINES_PER_FILE="${2:-1000000}"
OUTPUT_PREFIX="${3:-hgvs_batch_}"
OUTPUT_DIR="${4:-batches}"

echo "Splitting ${INPUT_FILE} into batches..."
echo "Lines per batch: ${LINES_PER_FILE}"
echo "Output directory: ${OUTPUT_DIR}"
echo "Output file prefix: ${OUTPUT_PREFIX}"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Split the file
# -l: lines per file
# -d: use numeric suffixes (00, 01, 02, etc.)
# -a 3: use 3-digit suffixes (allowing up to 1000 files)
split -l "${LINES_PER_FILE}" \
      -d \
      -a 3 \
      "${INPUT_FILE}" \
      "${OUTPUT_DIR}/${OUTPUT_PREFIX}"

# Add .txt extension to all batch files (BSD split doesn't support --additional-suffix)
for file in "${OUTPUT_DIR}/${OUTPUT_PREFIX}"[0-9][0-9][0-9]; do
    if [ -f "$file" ]; then
        mv "$file" "${file}.txt"
    fi
done

# Count and report results
BATCH_COUNT=$(ls -1 "${OUTPUT_DIR}/${OUTPUT_PREFIX}"*.txt | wc -l)
echo ""
echo "Split complete!"
echo "Total batch files created: ${BATCH_COUNT}"
echo "Batch files location: ${OUTPUT_DIR}/"

# Show file sizes
echo ""
echo "Batch file details:"
ls -lh "${OUTPUT_DIR}/${OUTPUT_PREFIX}"*.txt | head -5
if [ "${BATCH_COUNT}" -gt 5 ]; then
    echo "..."
    ls -lh "${OUTPUT_DIR}/${OUTPUT_PREFIX}"*.txt | tail -3
fi
