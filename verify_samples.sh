#!/bin/bash
set -e

echo "Verifying sample data integrity..."
echo "===================================="
echo ""

cat random_sample.jsonl | while IFS= read -r line; do
    # Extract _key and ca_id from the JSON line
    KEY=$(echo "$line" | jq -r '._key')
    CA_ID=$(echo "$line" | jq -r '.ca_id')
    
    # Parse the key: NC_000002.12:178661979:A:G
    CHR=$(echo "$KEY" | cut -d: -f1)
    POS=$(echo "$KEY" | cut -d: -f2)
    REF=$(echo "$KEY" | cut -d: -f3)
    ALT=$(echo "$KEY" | cut -d: -f4)
    
    # Convert 0-based to 1-based position for HGVS
    HGVS_POS=$((POS + 1))
    EXPECTED_HGVS="${CHR}:g.${HGVS_POS}${REF}>${ALT}"
    
    # Query the CA ID from the API
    ACTUAL_HGVS=$(curl -s "$CA_ID" | jq -r '.genomicAlleles[] | select(.referenceGenome == "GRCh38") | .hgvs[0]')
    
    # Compare
    if [ "$EXPECTED_HGVS" = "$ACTUAL_HGVS" ]; then
        echo "✓ MATCH: $KEY"
        echo "  Expected: $EXPECTED_HGVS"
        echo "  Actual:   $ACTUAL_HGVS"
        echo "  CA ID:    $CA_ID"
    else
        echo "✗ MISMATCH: $KEY"
        echo "  Expected: $EXPECTED_HGVS"
        echo "  Actual:   $ACTUAL_HGVS"
        echo "  CA ID:    $CA_ID"
    fi
    echo ""
done

echo "===================================="
echo "Verification complete!"
