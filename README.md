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
- `combine_results.sh` - Combine results (variant keys with CA IDs)
- `combine_hgvs_results.sh` - Combine results (HGVS notations with CA IDs)
- `verify_samples.sh` - Verify data integrity
- `dbsnp_convert_to_hgvs.rb` - Ruby utility for dbSNP VCF conversion

**Intermediate Files:**
- `hgvs_list.txt` - Extracted HGVS values
- `batches/` - Split batch files
- `batches/json/` - API response files
- `keys.txt` - Extracted variant keys
- `ca_ids.txt` - Extracted CA IDs
- `hgvs_ca_ids.txt` - Extracted CA IDs (for HGVS workflow)

**Final Output:**
- `result.jsonl` - Combined key-CA ID mappings (from variant keys)
- `hgvs_caid_combined.jsonl` - Combined HGVS-CAID mappings (direct HGVS workflow)

---

## Alternative Workflow: Direct HGVS-to-CAID Mapping

This is an alternative workflow when you already have a list of HGVS notations (without variant keys) and their corresponding CA IDs from the ClinGen API.

### Use Case

When you have:
- A text file with HGVS notations (one per line)
- Batch JSON response files from the ClinGen API in the exact same order

### Input Data Format

**HGVS Input File** (`hgvs_list_spaced_spaces_removed.txt`):
```
NC_000010.11:g.79347326_79347330delinsCTCAG
NC_000010.11:g.79347306_79347310delinsAGCCA
NC_000010.11:g.79347301_79347305delinsCCCTT
NC_000001.11:g.1297166_1297167insACGGG
NC_000001.11:g.119088438_119088439insTG
```

Each line contains a single HGVS genomic notation.

**Batch JSON Results Directory** (`hgvs_spaces_removed_batches_results/`):

The directory should contain numbered JSON files with CA ID responses:

```
hgvs_spaces_removed_000.json
hgvs_spaces_removed_001.json
hgvs_spaces_removed_002.json
...
hgvs_spaces_removed_050.json
```

**JSON Response Format:**

Each JSON file contains an array of CA ID objects in the exact same order as the HGVS input:

```json
[
  {
    "@id": "http://reg.genome.network/allele/CA997678297"
  },
  {
    "@id": "_:CA"
  },
  {
    "@id": "http://reg.genome.network/allele/CA2697045003"
  }
]
```

- `"http://reg.genome.network/allele/CA..."` - Valid CA ID found
- `"_:CA"` - Placeholder when no CA ID was found for that HGVS notation

### Combining HGVS with CA IDs

Use the `combine_hgvs_results.sh` script to merge HGVS notations with their corresponding CA IDs:

```bash
./combine_hgvs_results.sh [hgvs_file] [batch_directory] [ca_ids_file] [output_file]
```

**Default usage:**
```bash
./combine_hgvs_results.sh
# Uses: hgvs_list_spaced_spaces_removed.txt + hgvs_spaces_removed_batches_results/
# Output: hgvs_caid_combined.jsonl
```

**Custom files:**
```bash
./combine_hgvs_results.sh my_hgvs.txt my_batches/ ca_ids.txt output.jsonl
```

**Parameters:**
- `hgvs_file`: HGVS input file (default: `hgvs_list_spaced_spaces_removed.txt`)
- `batch_directory`: Directory containing batch JSON files (default: `hgvs_spaces_removed_batches_results`)
- `ca_ids_file`: Intermediate file for extracted CA IDs (default: `hgvs_ca_ids.txt`)
- `output_file`: Final JSONL output (default: `hgvs_caid_combined.jsonl`)

### Script Workflow

The script operates in three phases:

**Phase 1: Extract CA IDs**
- Processes all batch JSON files in strict numeric order
- Extracts the `@id` field from each CA ID object
- Writes all CA IDs to intermediate file (one per line)
- **Critical:** Order must be preserved to match HGVS input

**Phase 2: Combine Data**
- Reads HGVS file and CA IDs file line-by-line simultaneously
- Validates that line counts match
- Creates JSONL output with paired data
- Each HGVS notation is matched with its corresponding CA ID

**Phase 3: Validation**
- Verifies line counts match across all files
- Displays sample entries from beginning and end
- Confirms data integrity

### Output Format

The script produces a JSONL file (`hgvs_caid_combined.jsonl`) where each line contains:

**With valid CA ID:**
```json
{"hgvs":"NC_000001.11:g.1297166_1297167insACGGG","ca_id":"http://reg.genome.network/allele/CA997678297"}
```

**Without CA ID (not found):**
```json
{"hgvs":"NC_000010.11:g.79347326_79347330delinsCTCAG","ca_id":"_:CA"}
```

### Features

- **Resumable:** Skips already-completed phases when re-run
- **Order Integrity:** Maintains strict 1:1 correspondence between HGVS and CA IDs
- **Progress Tracking:** Reports progress for each batch file processed
- **Validation:** Multiple checkpoints ensure data integrity
- **Color-coded Output:** Clear visual feedback for each phase

### Example Run

```bash
$ ./combine_hgvs_results.sh

============================================
HGVS-CAID Combination Script
============================================

Configuration:
  HGVS file:     hgvs_list_spaced_spaces_removed.txt
  Batch dir:     hgvs_spaces_removed_batches_results
  CA IDs file:   hgvs_ca_ids.txt
  Output file:   hgvs_caid_combined.jsonl

Found 51 batch files

Phase 1: Extracting CA IDs from batch JSON files
  Processing 51 files...
  Processing: hgvs_spaces_removed_000.json
    Extracted entries so far: 1000000
  Processing: hgvs_spaces_removed_001.json
    Extracted entries so far: 2000000
  ...
  Processing: hgvs_spaces_removed_050.json
    Extracted entries so far: 50511694

✓ Phase 1 Complete
  Total CA IDs extracted: 50511694

Phase 2: Combining HGVS notations with CA IDs
  HGVS entries: 50511694
  CA IDs:       50511694
✓ Line counts match
  Creating JSONL output...
✓ Phase 2 Complete

Phase 3: Validation
  HGVS input:   50511694 lines
  JSONL output: 50511694 lines
✓ Line counts match perfectly

Sample output (first 5 entries):
  {"hgvs":"NC_000010.11:g.79347326_79347330delinsCTCAG","ca_id":"_:CA"}
  {"hgvs":"NC_000010.11:g.79347306_79347310delinsAGCCA","ca_id":"_:CA"}
  ...

============================================
✓ ALL PHASES COMPLETE
============================================

Output file: hgvs_caid_combined.jsonl
Total records: 50511694
```

### Generated Files

**Intermediate:**
- `hgvs_ca_ids.txt` - Extracted CA IDs (one per line)

**Final Output:**
- `hgvs_caid_combined.jsonl` - Combined HGVS-CAID mappings in JSONL format

### Processing Time

For 50+ million records:
- Phase 1 (Extract CA IDs): ~2-3 minutes
- Phase 2 (Combine): ~1-2 minutes
- Phase 3 (Validation): < 1 minute
- **Total:** Approximately 3-5 minutes
