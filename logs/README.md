# Logs — sanitized

Logs were created from user-supplied UE4SS sessions on 2026-11-20. Absolute Windows paths, IPv4 addresses, SteamID64 values and email addresses were replaced with redaction placeholders. Logs were gzip-compressed.

- `UE4SS-mapper-redacted.log.gz`: generated USMAP/ObjectDump.
- `UE4SS-v0.3-redacted.log.gz`: hook registration but 0 detected deaths; failed elevator, first gold spawn.
- `UE4SS-v0.4-redacted.log.gz`: working respawn; gear left on lift floor; floating coins; treasures skipped.

No v0.5 runtime log was supplied. Do not invent such evidence. Logs may still include benign game object names, timestamps and class names.

Search with `gzip -dc logs/UE4SS-v0.4-redacted.log.gz | grep ExpeditionSaver`.
