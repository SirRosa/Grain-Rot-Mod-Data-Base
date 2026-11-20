#!/usr/bin/env python3
"""Restore original USMAP/schema/ObjectDump from gz assets; verify SHA256.

Run from repository root: python scripts/restore_assets.py --output /tmp/grainrot-restored
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', default='restored', help='Output directory, ignored by Git')
    args = p.parse_args()
    target = Path(args.output).resolve()
    target.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((BASE / 'data' / 'asset-manifest.json').read_text('utf-8'))
    for name, meta in manifest.items():
        if not meta.get('compressed_sha256'):
            continue
        if name == 'UE4SS-ObjectDump.txt.gz':
            paths = [BASE/'data'/f'{name}.part{i:02d}' for i in range(1, 7)]
            for path in paths:
                if not path.is_file():
                    raise FileNotFoundError(path)
            packed = b''.join(path.read_bytes() for path in paths)
        else:
            path = BASE / ('logs' if name.startswith('UE4SS-') else 'data') / name
            if not path.is_file():
                raise FileNotFoundError(path)
            packed = path.read_bytes()
        if sha256(packed) != meta['compressed_sha256']:
            raise ValueError('compressed SHA256 mismatch: '+name)
        data = gzip.decompress(packed)
        if sha256(data) != meta['source_sha256']:
            raise ValueError('decompressed SHA256 mismatch: '+name)
        suffix = name[:-3] if name.endswith('.gz') else name
        final = target/suffix
        final.write_bytes(data)
        print(f'OK {name}: {len(packed)} bytes -> {len(data)} bytes, {final}')
    print('All restored files passed SHA256 verification.')


if __name__ == '__main__':
    main()
