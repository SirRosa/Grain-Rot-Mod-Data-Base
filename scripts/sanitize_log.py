#!/usr/bin/env python3
"""Conservative anonymizer before publishing a new log. Review output manually!"""
import argparse
import re
from pathlib import Path


def sanitize(data):
    # The general path pattern must precede Windows drive-letter replacement.
    data = re.sub(r'(?i)[A-Z]:\\Users\\[^\\\r\n]+', r'C:\\Users\\<REDACTED>', data)
    data = re.sub(r'(?i)[A-Z]:\\[^\r\n ]+', '<LOCAL_PATH>', data)
    data = re.sub(r'(?i)/home/[^/\r\n\s]+/[^\r\n\s]+', '/home/<REDACTED>', data)
    data = re.sub(r'[\w.\-+]+@[\w.\-]+\.[A-Za-z]{2,}', '<EMAIL>', data)
    data = re.sub(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', '<IP_ADDRESS>', data)
    data = re.sub(r'\b7656119\d{10}\b', '<STEAM_ID>', data)
    data = re.sub(r'(?im)(api[_-]?key|token|authorization|secret|password)(\s*[:=]\s*)[^\s\r\n]+', r'\1\2<REDACTED>', data)
    return data


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('--output', required=True)
    args=parser.parse_args()
    inp,out=Path(args.input),Path(args.output)
    text=sanitize(inp.read_text(encoding='utf-8',errors='replace'))
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(text,encoding='utf-8')
    print(f'Sanitized: {inp.name} -> {out}; manually review before publishing')


if __name__ == '__main__':
    main()
