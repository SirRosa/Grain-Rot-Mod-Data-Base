# Grain Rot — Modding Knowledge Base / Handoff (20.11.2026)

> **START HERE:** Baza wiedzy dla kolejnego chatu GPT tworzącego mody do Grain Rot (Helden / UE5). To nie jest mod instalacyjny.
>
> **Status:** użytkownik potwierdził po v0.5.0-alpha: „na tym etapie jest sukces”. Brak końcowego logu v0.5 i oddzielnych potwierdzeń każdej funkcji. 45/45 zaliczonych testów GitHub Actions to **testy symulacyjne Lua**, a nie uruchomiona gra.

## Nawigacja

| Plik | Cel |
|---|---|
| [AGENTS.md](AGENTS.md) | Zasady pracy dla kolejnego asystenta |
| [docs/00-HANDOFF.md](docs/00-HANDOFF.md) | Kompletne wprowadzenie i fakty techniczne |
| [docs/01-HISTORY-AND-FAILURES.md](docs/01-HISTORY-AND-FAILURES.md) | Chronologia wersji i błędów |
| [docs/02-UE4SS-REFLECTION.md](docs/02-UE4SS-REFLECTION.md) | Klasy, hooki, pola, enumy, mapowanie |
| [docs/03-LOOT-ECONOMY.md](docs/03-LOOT-ECONOMY.md) | Waluta, QOL, fizyka monet i wartościowy loot |
| [docs/04-DEATH-INVENTORY.md](docs/04-DEATH-INVENTORY.md) | Respawn, ekwipunek, sloty, ryzyko duplikatów |
| [docs/05-EXPEDITION-SAVES.md](docs/05-EXPEDITION-SAVES.md) | Piętra, koniec ekspedycji, winda, save |
| [docs/06-IMPLEMENTATION-RULES.md](docs/06-IMPLEMENTATION-RULES.md) | Metoda tworzenia kolejnych modów |
| [docs/07-OPEN-QUESTIONS.md](docs/07-OPEN-QUESTIONS.md) | Niewiadome i ograniczenia dowodów |
| [docs/08-LOG-EVIDENCE.md](docs/08-LOG-EVIDENCE.md) | Wyniki realnych testów i cytowane wpisy |
| [docs/09-ASSET-MANIFEST.md](docs/09-ASSET-MANIFEST.md) | Materiały, kompresja, checksumy |
| [reference/](reference/) | Kopie kodu i testów z oryginalnego repo |
| [data/](data/) | Skompresowane zrzuty mapowań i refleksji |
| [logs/](logs/) | Logi tylko po anonimizacji |
| [scripts/](scripts/) | Narzędzia analizy |

## Źródła

- [SirRosa/Expedition-Saver](https://github.com/SirRosa/Expedition-Saver) — źródło v0.5, historia commitów, kod i testy.
- [CI v0.5 PASS](https://github.com/SirRosa/Expedition-Saver/actions/runs/44761406133) — składnia + 45 mock testów + instalacyjny ZIP; nie jest testem w grze.

## Reguły krytyczne

1. Realne obserwacje i logi UE4SS ważniejsze niż mock CI; wcześniejsze wersje przechodziły testy mimo braku działania.
2. Respawn bez **całego** ekwipunku i walut w slotach nie jest pełnym sukcesem.
3. Mody QOL zmieniają runtime DataTable. Nie mnożyć nagród podwójnie.
4. Zmiany ekonomii i stanu gracza wykonuje host; klientów i replikację testować osobno.
5. Zrzuty w data są skompresowane gzip. Rozpakować przed analizą.
6. **Publiczne repozytorium:** usuwać prywatne ścieżki/ID z logów; nie dodawać całych sejwów, obcych binariów ani sekretów.
7. Nie zgadywać API po nazwie. Sprawdzać dump, mapowanie i faktyczne wywołania.
