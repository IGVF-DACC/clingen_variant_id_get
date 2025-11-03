# clingen_variant_id_get
Code for pulling IDs from clingen allele registry

## Overview
This repository contains scripts for extracting ClinGen Allele Registry IDs for variants. The process follows the workflow described in the [ClinGen Allele Registry documentation](https://reg.clinicalgenome.org/redmine/projects/clingen-allele-registry/wiki/Obtaining_dbSNP_identifiers_for_CA_IDs).

## Workflow

### Step 1: Extract HGVS Notation from Input File

The input file `no_ca_ids.jsonl.gz` contains variants in JSONL format, where each line is a JSON array:
```
["NC_000001.11:100462821:T:G", "NC_000001.11:g.100462822T>G"]
```
- First element: variant key (chromosome:position:ref:alt)
- Second element: HGVS genomic notation

#### Extract HGVS values:
```bash
./extract_hgvs.sh [input_file] [output_file]
```

**Default usage:**
```bash
./extract_hgvs.sh
# Uses: no_ca_ids.jsonl.gz -> hgvs_list.txt
```

**Custom files:**
```bash
./extract_hgvs.sh my_input.jsonl.gz my_output.txt
```

This creates a plain text file with one HGVS notation per line, ready for querying the ClinGen API.

### Step 2: Split HGVS List into Batch Files

The complete HGVS list is very large (693M+ lines). To make API queries manageable, split it into smaller batch files of 1 million lines each.

#### Split into batches:
```bash
./split_hgvs_list.sh [input_file] [lines_per_file] [output_prefix] [output_directory]
```

**Default usage:**
```bash
./split_hgvs_list.sh
# Uses: hgvs_list.txt
# Lines per batch: 1,000,000
# Output: batches/hgvs_batch_000.txt, batches/hgvs_batch_001.txt, etc.
```

**Custom settings:**
```bash
./split_hgvs_list.sh my_hgvs.txt 500000 my_batch_ my_output_dir/
# Creates batches of 500K lines in my_output_dir/
```

**Parameters:**
- `input_file`: HGVS list to split (default: `hgvs_list.txt`)
- `lines_per_file`: Number of lines per batch (default: `1000000`)
- `output_prefix`: Prefix for batch files (default: `hgvs_batch_`)
- `output_directory`: Directory for batch files (default: `batches`)

This creates numbered batch files (e.g., `hgvs_batch_000.txt`, `hgvs_batch_001.txt`, ...) ready for individual API queries.

### Step 3: Query ClinGen Allele Registry API

Query the ClinGen Allele Registry API for each batch to retrieve ClinGen Allele IDs (CA IDs).

#### Process all batches:
```bash
./process_all_batches.sh [batch_directory] [output_directory] [batch_prefix]
```

**Default usage:**
```bash
./process_all_batches.sh
# Uses: batches/ -> batches/json/
# Processes all hgvs_batch_*.txt files
```

**Custom settings:**
```bash
./process_all_batches.sh my_batches/ my_output/ my_batch_
```

**What it does:**
- Processes each batch file through the ClinGen API
- Retrieves CA IDs for each HGVS variant
- Saves results as JSON files in `batches/json/`
- Skips already-processed batches (resumable)
- Includes progress tracking and error handling
- Adds 1-second pause between requests to be respectful to the API

**Manual single batch query:**
```bash
./request_with_payload.sh "http://reg.clinicalgenome.org/alleles.json?file=hgvs&fields=none+@id" \
    batches/hgvs_batch_000.txt > batches/json/hgvs_batch_000.json
```

**Response format:**
Each JSON file contains an array of allele records with CA IDs:
```json
[
  {
    "@id": "http://reg.genome.network/allele/CA341357741"
  },
  {
    "@id": "http://reg.genome.network/allele/CA341357755"
  }
]
```

### Step 4: Combine Results for Database Loading

Combine the original variant keys with the retrieved CA IDs to create the final database-ready output.

#### Combine keys and CA IDs:
```bash
./combine_results.sh [original_file] [batch_directory] [keys_file] [ca_ids_file] [output_file]
```

**Default usage:**
```bash
./combine_results.sh
# Uses: no_ca_ids.jsonl.gz + batches/json/ -> result.jsonl
```

**What it does:**
1. **Phase 1**: Extracts keys from original file (`no_ca_ids.jsonl.gz`)
2. **Phase 2**: Extracts CA IDs from batch JSON files in numeric order (CRITICAL for data integrity)
3. **Phase 3**: Combines keys and CA IDs line-by-line into JSONL format
4. **Phase 4**: Validates output integrity

**Output format:**
Each line in `result.jsonl` contains:
```json
{"_key":"NC_000001.11:100462821:T:G","ca_id":"http://reg.genome.network/allele/CA341357741"}
```

**Features:**
- Maintains strict order integrity (keys ↔ CA IDs)
- Resumable (skips completed phases)
- Progress reporting for long-running operations
- Validation checks at each phase
- Expected output: 693,602,957 records

**Processing time:** Approximately 30-40 minutes for the full dataset.

### Step 5: Verify Data Integrity (Optional)

Verify that the key-CA ID mappings are correct by checking random samples against the ClinGen API.

#### Verify sample data:
```bash
# Extract sample rows (e.g., 10 rows starting at line 10000000)
sed -n '10000000,10000009p' result.jsonl > random_sample.jsonl

# Run verification script
./verify_samples.sh
```

**What it does:**
- Reads sample entries from `random_sample.jsonl`
- For each entry, queries the ClinGen API with the CA ID
- Compares the returned HGVS notation with the original key
- Reports matches and mismatches

**Example output:**
```
✓ MATCH: NC_000002.12:178661979:A:G
  Expected: NC_000002.12:g.178661980A>G
  Actual:   NC_000002.12:g.178661980A>G
  CA ID:    http://reg.genome.network/allele/CA349489235
```

This verification step confirms that no data scrambling occurred during the combining process.

## Summary

This workflow processes 693,602,957 variants through the ClinGen Allele Registry API to obtain CA IDs:

1. **Extract** HGVS notations from input file
2. **Split** into manageable batches (1M variants each)
3. **Query** ClinGen API for each batch to retrieve CA IDs
4. **Combine** original keys with CA IDs for database loading
5. **Verify** data integrity through API cross-checking

**Final Output:** `result.jsonl` - JSONL file with `_key` and `ca_id` fields ready for database import.

**Total Processing Time:** Approximately 20-24 hours (mostly API queries running in background)

## Files Overview

**Scripts:**
- `extract_hgvs.sh` - Extract HGVS from input
- `split_hgvs_list.sh` - Split into batches
- `request_with_payload.sh` - API request helper
- `process_all_batches.sh` - Batch API processor
- `combine_results.sh` - Combine results
- `verify_samples.sh` - Verify data integrity
- `dbsnp_convert_to_hgvs.rb` - Ruby utility for dbSNP VCF conversion

**Intermediate Files:**
- `hgvs_list.txt` - Extracted HGVS values
- `batches/` - Split batch files
- `batches/json/` - API response files
- `keys.txt` - Extracted variant keys
- `ca_ids.txt` - Extracted CA IDs

**Final Output:**
- `result.jsonl` - Combined key-CA ID mappings
