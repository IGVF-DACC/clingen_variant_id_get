import gzip
import json
import sys
from rocksdict import Rdict, Options, WriteBatch
from argparse import ArgumentParser

def db_options():
    options = Options()
    options.create_if_missing(True)
    options.set_write_buffer_size(128 * 1024 * 1024)  # 128MB
    options.set_max_open_files(1000)
    return options

def main():
    parser = ArgumentParser()
    parser.add_argument("--input", type=str, required=True)
    parser.add_argument("--output", type=str, required=True)
    parser.add_argument("--batch-size", type=int, default=100000, help="Batch size for writing")
    args = parser.parse_args()

    options = db_options()
    db = Rdict(args.output, options)
    
    # Batch configuration
    batch = WriteBatch()
    batch_size = args.batch_size
    current_batch_count = 0
    
    log_interval = 100000000

    print(f"Starting load from {args.input} to {args.output}")

    try:
        with gzip.open(args.input, 'rt') as f:
            for idx, line in enumerate(f):
                # Feedback interval
                if idx > 0 and idx % log_interval == 0:
                    print(f"Processing line {idx}", flush=True)

                try:
                    item = json.loads(line)
                    hgvs = item.get('hgvs')
                    if not hgvs:
                        continue
                    
                    hgvs = hgvs.strip()
                    
                    ca_id = item.get('ca_id')
                    if ca_id:
                        ca_id = ca_id.strip()
                        if not ca_id:
                            ca_id = "NULL"
                    else:
                        ca_id = "NULL"

                    # Add to batch
                    batch.put(hgvs, ca_id)
                    current_batch_count += 1

                    # Flush batch if full
                    if current_batch_count >= batch_size:
                        db.write(batch)
                        batch = WriteBatch()
                        current_batch_count = 0

                except (json.JSONDecodeError, AttributeError) as e:
                    continue

            # Write any remaining items in the final batch
            if current_batch_count > 0:
                db.write(batch)

        print(f"Finished processing {idx + 1} lines.")

    finally:
        db.close()

if __name__ == '__main__':
    main()
