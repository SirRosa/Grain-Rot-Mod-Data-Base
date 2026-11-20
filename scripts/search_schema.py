#!/usr/bin/env python3
"""Print classes/enum definitions from current-schema.json.gz (no installation)."""
import gzip
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    if len(sys.argv) < 2:
        raise SystemExit('Usage: python scripts/search_schema.py <case-insensitive-name-fragment> [--enum]')
    key = sys.argv[1].lower()
    category = 'enums' if '--enum' in sys.argv else 'structs'
    with gzip.open(ROOT/'data'/'current-schema.json.gz', 'rt', encoding='utf-8') as file:
        database = json.load(file)
    matches = [(name, payload) for name,payload in database[category].items()
               if key in name.lower()]
    print(f'{len(matches)} matches in {category}')
    for name,payload in matches[:80]:
        print(json.dumps({name:payload},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
