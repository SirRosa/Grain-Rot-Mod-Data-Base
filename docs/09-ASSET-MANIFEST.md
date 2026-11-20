# Komplet materiałów, rozpakowanie i suma kontrolna

Wszystkie pliki w `data/` i `logs/` pochodzą z sesji/plików użytkownika z 20.11.2026. Nie dodawaj ich jako nowej wersji silnika bez ponownego sprawdzenia buildu. **Dane są z właściwego UE4SS; surowy USMAP to nie gotowy mod.**

## Jak odzyskać materiały

Po sklonowaniu repo:

```bash
python scripts/restore_assets.py --output restored
python scripts/search_schema.py HeldenPlayerController
python scripts/search_schema.py EHeldenDungeonRunState --enum
```

Skrypt weryfikuje **SHA256 skompresowanych i oryginalnych plików**, nie tylko długość; wartości w [data/asset-manifest.json](../data/asset-manifest.json). Po poprawnym odtworzeniu otrzymasz:

- `restored/Helden-UE5.7-current.usmap` — **aktualny** USMAP z nazwy `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap` (2,223,017 B).
- `restored/Helden-UE5.7-previous.usmap` — starszy plik `Helden.usmap` (2,172,010 B), ten sam build w nazwie.
- `restored/current-schema.json` — 11,094 UStruct definitions i 2,207 enum definitions; wygodny do wyszukiwania.
- `restored/previous-schema.json` — 10,867 UStruct definitions i 2,165 enumów.
- `restored/UE4SS-ObjectDump.txt` — pełny zrzut refleksji **182,447 linii / 32,060,324 B**.
- `restored/UE4SS-mapper-redacted.log`, `restored/UE4SS-v0.3-redacted.log`, `restored/UE4SS-v0.4-redacted.log` — logi do analizy, z usuniętymi prywatnymi ścieżkami; sumy kontrolne i rozmiary odnoszą się do **zanonimizowanego** tekstu.

**Uwaga:** ObjectDump został podzielony na dokładnie 6 fragmentów z przyczyn limitu transferu. Łącz **bajty gzip** w kolejności `.part01`…`.part06` bez pustych separatorów, a potem rozpakuj gzip. Nie rozpakowuj każdej części osobno (nie są niezależnymi archiwami gzip).

## Szczegóły pochodzenia

| Plik GitHub | Źródło | Rozmiar po rozpakowaniu |
|---|---|---:|
| `data/Helden-UE5.7-current.usmap.gz` | `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap` | 2,223,017 B |
| `data/Helden-UE5.7-previous.usmap.gz` | starszy `Helden.usmap` | 2,172,010 B |
| `data/current-schema.json.gz` | parser bieżącego USMAP | 6,400,472 B |
| `data/previous-schema.json.gz` | parser starszego USMAP | 6,249,451 B |
| `data/UE4SS-ObjectDump.txt.gz.part01..06` | `UE4SS_ObjectDump.txt` | 32,060,324 B |
| `logs/UE4SS-mapper-redacted.log.gz` | `UE4SS(1).log` | 156,094 B |
| `logs/UE4SS-v0.3-redacted.log.gz` | `UE4SS(2).log` | 171,976 B |
| `logs/UE4SS-v0.4-redacted.log.gz` | `UE4SS(4).log` | 217,487 B |

## Czego celowo nie publikowano

- Pełnych **niezanonimizowanych** logów, surowych sejwów i plików osobistych użytkownika.
- Binarnej paczki UE4SS, cudzej paczki GrainRotMinimap, pełnych plików gry Unreal — użytkownik powinien pobrać swoje własne wersje zgodnie z licencjami.
- `UE4SS(3).log` nie jest częścią potwierdzonej osi testowej v0.3/v0.4. Jeśli okaże się użyteczny, trzeba go osobno przypisać do wersji i zanonimizować.
- Pełnego `CurrentSaveGame` użytkownika; informacje o typach struktur zapisano w schematach.

## Źródła kodu

W `reference/expedition-saver-v0.5` zachowano aktualny na dzień handoffa snapshot (kod, tests, ci, mapper). Żywa historia wersji pozostaje w [SirRosa/Expedition-Saver](https://github.com/SirRosa/Expedition-Saver). `reference/other-mods` zawiera sam kod Lua Depth Keeper i QOL; **to tylko referencje kompatybilności**, nie polecane jednoczesne instalacje.
