# Offline dumps (generated 2026-11-20)

Archive contains actual generated UE4SS mapping and full object dump, not just sample excerpts. No game executable or proprietary UE4SS engine binaries.

- `Helden-UE5.7-current.usmap.gz`: 2,223,017 bytes after decompress, sha256 `c3f70cd4f7c9189d9b1581648ade1b18cce2bbf5f8cf5cf31ccb6ad1ccd598af`.
- `Helden-UE5.7-previous.usmap.gz`: 2,172,010 bytes, sha256 `e72f8448745249fe3e522efa6af3edb7efe4415d454563447061fce39f648456`.
- `current-schema.json.gz`: extracted full parsed class/enum schema (6,400,472 bytes), sha256 `4e60969a115114b6060355763e30a29557bb4c384028e4608953827eedf2e2cd`.
- `previous-schema.json.gz`: older parsed schema (6,249,451 bytes), sha256 `31fafe5d8a23886b0a4eba595517afcc67096a32b45417b45949225489c773d7`.
- The full `UE4SS-ObjectDump.txt` had 32,060,324 bytes and 182,447 lines (count from source audit), sha256 `cf9d1a9357998905f57c21ac3e2e7848fedd8686f25715e537b0c8570c35821d`. Its gzip (3,320,532 bytes, sha256 `752f2799a5db91413dd8a7d72ccda30cb639399f978482d15e756dbf4e87bb6b`) is stored as `part01`–`part06`, because the connector rejects a single >4 MB request.

## Reassemble

Linux/macOS:
```sh
cat data/UE4SS-ObjectDump.txt.gz.part* > UE4SS-ObjectDump.txt.gz
gzip -d -k UE4SS-ObjectDump.txt.gz
gzip -d -k data/current-schema.json.gz
gzip -d -k data/Helden-UE5.7-current.usmap.gz
sha256sum UE4SS-ObjectDump.txt
```

Windows PowerShell:
```powershell
$parts = Get-ChildItem data\UE4SS-ObjectDump.txt.gz.part* | Sort-Object Name
$dst = [IO.File]::Create('UE4SS-ObjectDump.txt.gz')
try { foreach ($p in $parts) { $src=[IO.File]::OpenRead($p.FullName); try {$src.CopyTo($dst)} finally {$src.Dispose()} } } finally {$dst.Dispose()}
[IO.Compression.GZipStream] # load library; use scripts/reassemble.py for a one-command cross-platform alternative
python scripts/reassemble.py
```

**Do not treat the schema JSON as native UE4SS .usmap**; it is a convenient derived searchable index. For a newer game patch regenerate both from actual running game. USMAP only proves reflected types, not call timing.
