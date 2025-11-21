#!/bin/bash

# combine_hgvs_results.sh
# Combines HGVS notations with CA IDs from batch JSON results
# Usage: ./combine_hgvs_results.sh [hgvs_file] [batch_directory] [ca_ids_file] [output_file]

set -e  # Exit on error

# Default parameters
HGVS_FILE="${1:-hgvs_list_spaced_spaces_removed.txt}"
BATCH_DIR="${2:-hgvs_spaces_removed_batches_results}"
CA_IDS_FILE="${3:-hgvs_ca_ids.txt}"
OUTPUT_FILE="${4:-hgvs_caid_combined.jsonl}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}HGVS-CAID Combination Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Configuration:"
echo "  HGVS file:     $HGVS_FILE"
echo "  Batch dir:     $BATCH_DIR"
echo "  CA IDs file:   $CA_IDS_FILE"
echo "  Output file:   $OUTPUT_FILE"
echo ""

# Verify input files exist
if [ ! -f "$HGVS_FILE" ]; then
    echo -e "${RED}ERROR: HGVS file not found: $HGVS_FILE${NC}"
    exit 1
fi

if [ ! -d "$BATCH_DIR" ]; then
    echo -e "${RED}ERROR: Batch directory not found: $BATCH_DIR${NC}"
    exit 1
fi

# Count batch files
BATCH_COUNT=$(ls "$BATCH_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
if [ "$BATCH_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR: No JSON files found in $BATCH_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}Found $BATCH_COUNT batch files${NC}"
echo ""

# ============================================
# PHASE 1: Extract CA IDs from batch JSON files
# ============================================
if [ -f "$CA_IDS_FILE" ]; then
    echo -e "${YELLOW}Phase 1: CA IDs file already exists, skipping extraction${NC}"
    echo "  File: $CA_IDS_FILE"
else
    echo -e "${BLUE}Phase 1: Extracting CA IDs from batch JSON files${NC}"
    echo "  Processing $BATCH_COUNT files..."
    echo ""
    
    # Create temporary file
    TEMP_CA_IDS="${CA_IDS_FILE}.tmp"
    > "$TEMP_CA_IDS"
    
    # Process each batch file in numeric order
    for json_file in $(ls "$BATCH_DIR"/*.json | sort -V); do
        filename=$(basename "$json_file")
        echo -e "  Processing: ${BLUE}$filename${NC}"
        
        # Extract @id field from each JSON object
        # This handles both "http://..." and "_:CA" entries
        jq -r '.[]."@id"' "$json_file" >> "$TEMP_CA_IDS"
        
        # Show progress
        current_lines=$(wc -l < "$TEMP_CA_IDS" | tr -d ' ')
        echo "    Extracted entries so far: $current_lines"
    done
    
    # Move temp file to final location
    mv "$TEMP_CA_IDS" "$CA_IDS_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Phase 1 Complete${NC}"
    
    # Validation
    CA_COUNT=$(wc -l < "$CA_IDS_FILE" | tr -d ' ')
    echo "  Total CA IDs extracted: $CA_COUNT"
    echo ""
fi

# ============================================
# PHASE 2: Combine HGVS with CA IDs
# ============================================
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Phase 2: Output file already exists, skipping combination${NC}"
    echo "  File: $OUTPUT_FILE"
else
    echo -e "${BLUE}Phase 2: Combining HGVS notations with CA IDs${NC}"
    echo ""
    
    # Verify CA IDs file exists
    if [ ! -f "$CA_IDS_FILE" ]; then
        echo -e "${RED}ERROR: CA IDs file not found: $CA_IDS_FILE${NC}"
        exit 1
    fi
    
    # Count lines
    HGVS_COUNT=$(wc -l < "$HGVS_FILE" | tr -d ' ')
    CA_COUNT=$(wc -l < "$CA_IDS_FILE" | tr -d ' ')
    
    echo "  HGVS entries: $HGVS_COUNT"
    echo "  CA IDs:       $CA_COUNT"
    
    if [ "$HGVS_COUNT" -ne "$CA_COUNT" ]; then
        echo -e "${RED}ERROR: Line count mismatch!${NC}"
        echo "  HGVS file has $HGVS_COUNT lines"
        echo "  CA IDs file has $CA_COUNT lines"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Line counts match${NC}"
    echo ""
    echo "  Creating JSONL output..."
    
    # Create temporary output file
    TEMP_OUTPUT="${OUTPUT_FILE}.tmp"
    > "$TEMP_OUTPUT"
    
    # Combine line by line
    # Read both files simultaneously and create JSONL
    paste "$HGVS_FILE" "$CA_IDS_FILE" | \
    awk -F'\t' '{
        # Escape any special characters in HGVS
        gsub(/"/, "\\\"", $1);
        gsub(/"/, "\\\"", $2);
        printf "{\"hgvs\":\"%s\",\"ca_id\":\"%s\"}\n", $1, $2;
    }' > "$TEMP_OUTPUT"
    
    # Move temp file to final location
    mv "$TEMP_OUTPUT" "$OUTPUT_FILE"
    
    echo -e "${GREEN}✓ Phase 2 Complete${NC}"
    echo ""
fi

# ============================================
# PHASE 3: Validation
# ============================================
echo -e "${BLUE}Phase 3: Validation${NC}"
echo ""

# Count output lines
OUTPUT_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
HGVS_COUNT=$(wc -l < "$HGVS_FILE" | tr -d ' ')

echo "  HGVS input:   $HGVS_COUNT lines"
echo "  JSONL output: $OUTPUT_COUNT lines"

if [ "$OUTPUT_COUNT" -eq "$HGVS_COUNT" ]; then
    echo -e "${GREEN}✓ Line counts match perfectly${NC}"
else
    echo -e "${RED}✗ Line count mismatch!${NC}"
    exit 1
fi

# Sample validation - show first few entries
echo ""
echo "Sample output (first 5 entries):"
head -5 "$OUTPUT_FILE" | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo "Sample output (last 5 entries):"
tail -5 "$OUTPUT_FILE" | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ ALL PHASES COMPLETE${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo "Total records: $OUTPUT_COUNT"
echo ""
