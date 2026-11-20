#!/usr/bin/env python3
"""Parse Grain Rot UE4SS .usmap (observed version 4 / large-enums layout).

Source adapted from the parser used on the 2026-11-20 Helden dump.
Not a generic validator for arbitrary engine versions or USMAP revisions.
Example: python scripts/parse_usmap.py restored/Helden-UE5.7-current.usmap /tmp/current-schema.json
"""
import argparse
import json
import struct
from pathlib import Path

TYPES = [
    'Byte','Bool','Int','Float','Object','Name','Delegate','Double','Array',
    'Struct','Str','Text','Interface','Multicast','WeakObject','LazyObject',
    'AssetObject','SoftObject','UInt64','UInt32','UInt16','Int64','Int16','Int8',
    'Map','Set','Enum','FieldPath','Optional','Utf8Str','AnsiStr','Class',
    'MulticastInlineDelegate','SoftClass','VerseString','VerseDynamic','VerseFunction'
]


def parse_usmap(blob):
    p = 16  # Magic + header for this observed .usmap format
    def read(fmt):
        nonlocal p
        n=struct.calcsize(fmt)
        values=struct.unpack_from('<'+fmt,blob,p)
        p+=n
        return values[0] if len(values)==1 else values
    count=read('I')
    names=[]
    for _ in range(count):
        length=read('H')
        names.append(blob[p:p+length].decode('utf8','replace'))
        p+=length
    def name():
        index=read('i')
        if index < 0: return None
        if index >= len(names): raise IndexError('Name index out of bounds')
        return names[index]
    enums={}
    for _ in range(read('I')):
        enum_name=name()
        values=read('H')
        enums[enum_name]={read('Q'):name() for _ in range(values)}
    def prop():
        kind=read('B')
        value={'type':TYPES[kind] if kind<len(TYPES) else str(kind)}
        if kind==26:
            value['inner']=prop();value['enum']=name()
        elif kind==9:
            value['struct']=name()
        elif kind in (8,25,28):
            value['inner']=prop()
        elif kind==24:
            value['key']=prop();value['value']=prop()
        return value
    structs={}
    for _ in range(read('I')):
        struct_name=name(); parent=name()
        inherited=read('H'); properties=read('H')
        values=[]
        for _ in range(properties):
            index=read('H');dimensions=read('B');property_name=name()
            values.append({'index':index,'name':property_name,'dim':dimensions,**prop()})
        structs[struct_name]={'parent':parent,'propCount':inherited,'properties':values}
    # This UE4SS USMAP contains an extra trailing region not decoded by the
    # original parser. Do not claim it is understood; preserve the raw file.
    # Parsed structs/enums have been cross-checked against the 2026-11-20 JSON.
    return {'structs':structs,'enums':enums}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('input',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    data=parse_usmap(args.input.read_bytes())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(data,ensure_ascii=False,indent=1),encoding='utf8')
    print('Parsed structs',len(data['structs']),'enums',len(data['enums']))


if __name__=='__main__':
    main()
