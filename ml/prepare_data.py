"""Minimal data preparation helpers for the small sample dataset.

This script validates the JSONL file and can be extended to convert other sources.
"""
import argparse
import json


def validate(jsonl_path):
    count = 0
    with open(jsonl_path, "r") as f:
        for line in f:
            try:
                obj = json.loads(line)
            except Exception as e:
                print(f"Invalid JSON on line {count+1}: {e}")
                return False
            if "text" not in obj:
                print(f"Missing 'text' field on line {count+1}")
                return False
            count += 1
    print(f"Validated {count} examples in {jsonl_path}")
    return True


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--file", required=True)
    args = p.parse_args()
    validate(args.file)
