# Handoff techniczny: wszystko, co ustaliliśmy o Grain Rot

**Data:** 2026-11-20, Europa/Warszawa. **Źródło:** rzeczywisty USMAP, ObjectDump, logi UE4SS z prób v0.3 i v0.4, kod w `SirRosa/Expedition-Saver`, raporty kolejnych testów użytkownika.

## Stan końcowy (nie nadinterpretować)

- **Expedition Saver v0.5.0-alpha** to ostatnia przygotowana wersja: kod, 45 mock testów, paczka z GitHub Actions, SHA commita `092834f06de11466f1505acaef4944e5f343f0c9`.
- Po tej wersji użytkownik napisał: **„ok na tym etapie jest sukces”**. To potwierdza ogólną satysfakcję z etapu; **nie dostaliśmy nowego UE4SS.log v0.5 ani testu stanu Expedition Failed**, więc osobne funkcje są niezweryfikowane w szczegółach.
- W **v0.4** faktycznie udał się **respawn w windzie**. Wciąż ginęły itemy i waluta, wartościowy loot nie wypadał, monety wisiały. W **v0.3** nie działały praktycznie wszystkie główne funkcje.
- Prawdziwe środowisko UE4SS raportowało **v3.0.1 Beta #0, Git SHA 1c1a1497**, mimo że użytkownik dostarczył archiwum UE4SS z inną nazwą wersji. Gra to Shipping Win64, projekt `Helden`, zrzut `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap`.

## Zawartość bazy

- `data/` — USMAP (obecny i starszy), pełny `current-schema.json.gz` (11094 structów, 2207 enumów), poprzedni schema, ObjectDump (182447 linii / ~32 MB) skompresowany i podzielony.
- `logs/` — redacted real-session UE4SS logs: mapper, v0.3, v0.4.
- `reference/expedition-saver-v0.5/` — kopia dokładnego kodu mod Lua, narzędzia ExpeditionMapper, testów, CI i raportów z oryginalnego repo, plus link do repo żywego projektu.
- `reference/other-mods/` — źródła Depth Keeper i GrainRotQOL autorstwa projektu, **referencje do kompatybilności**, NIE instaluj ich razem bez weryfikacji.
- `scripts/` — funkcje rozpakowania, kontroli SHA256, przeglądu schematów i logów.

## Od użytkownika: wymagania, które przyczyniły się do projektu

1. Gra w trybie **Expedition**: po zgonie ma następować ponowne odrodzenie w windzie i utrzymanie głębokości piętra zamiast restartu od pierwszego.
2. Gracz **nie może tracić żadnych przedmiotów ani walut**. Fizyczne przesunięcie rzeczy na podłogę, brak w slotach czy trwała utrata części sprzętu to błąd, nie „sukces”.
3. Po zniszczeniu każdego przedmiotu mają wypadać wszelkie należne wartości extraction, oprócz zwykłych resource scrapów, które gra obsługuje już sama. W szczególności **Gold i Artifact Coins** jako **fizyczne podnoszone przedmioty** na ziemi.
4. Zniszczenie ma działać **automatycznie**, bez F7 i innych klawiszy.
5. Liczby mają uwzględniać **GrainRotQOL**, bez nałożenia mnożnika dwa razy. Wartości liczymy ze **zmodowanych runtime danych**, nie wyłącznie z vanilla tabel.
6. Host/multiplayer i bezpieczeństwo sejwów są krytyczne. Wynik mocków sam nie wystarcza.

## Architektura w skrócie

- `HeldenGameState` i `HeldenGameInstance.CurrentSaveGame` odczytują tryb, fazę runu, stan porażki i `DungeonLevel`; `HeldenGameMode` / `GameModeBase` rozróżnia serwer.
- Pętla `LoopInGameThreadWithDelay(300, ...)` zachowuje bieżące obserwacje i spróbuje naprawić run, monety, gracza. Nie uzależniaj kluczowej logiki od `os.clock()`.
- `HeldenPlayerController:GetPawn()`, `SoulCharacter`, `LastPlayerChar`, `HeldenCharacter.CharacterState`, `CharacterStats.CurrentHealth` pozwalają wykryć śmierć nawet gdy **hooki śmierci nie są wywoływane**.
- Snapshot wyposażenia z `EquipedItems` + `ItemSlots` + `PreviousOwner` oraz `Money` przed śmiercią. Po respawnie natywne `Interact`/`Interact_Server` próbuje odtworzyć sloty; nierozpoznane resztki mają pozostać w świecie, nigdy znikać bez śladu.
- Dla fizycznych monet: `HeldenDataSingleton.GoldCoinActorClass` / `ArtifactCoinActorClass`, spawn autorytatywny, ustaw `HeldenPhysicsCoin.Money`, włącz sim/gravity `RootMesh`, sprawdź `Interact_Auth` faktycznie przy podnoszeniu.
- Obiekty wartościowe: `BP_DefaultPhysTreasure_C`, `HeldenPhysTreasureContainer.TreasureData`, `HeldenPhysActorData.Parsed_ScrapReward`; zerowy odczyt z `GetConstructAssetData()` nie oznacza braku extraction reward.
- Failure elevator: `HeldenElevatorMachine` plus osobny Blueprint `BP_ExpeditionFailed_Actor_C`, flagi/kolizje. Przedmiotowa kombinacja w v0.4 **nie przeszła jeszcze niezależnego testu full wipe**.

## Wiarygodność ustaleń

| Poziom | Przykład | Interpretacja |
|---|---|---|
| Realny log | v0.4: `PLAYER DEATH queued`, `EQUIPMENT native=0 moved=1` | Dowód wywołania kodu i niepełnego odzysku |
| Obserwacja użytkownika | „odrodziłem się w windzie” (v0.4) | Dowód rzeczywistego respawnu, nie dowód zachowania itemów |
| USMAP / ObjectDump | `ECharacterState.Dead=1`, `Money.Artifacts` | Dowód istnienia pola, nie cyklu życia |
| Test mock Lua | 45/45 PASS | Dowód zgodności kodu z modelem testowym, nie z grą |
| Hipoteza | `Interact()` odtwarza item w realnym slocie we wszystkich sytuacjach | Wymaga testu w działającej grze |

## Repo źródłowe / checkpoint

- https://github.com/SirRosa/Expedition-Saver
- https://github.com/SirRosa/Expedition-Saver/commit/092834f06de11466f1505acaef4944e5f343f0c9
- https://github.com/SirRosa/Expedition-Saver/actions/runs/44761406133 (PASS, 45 mocków)

**To jest baza wiedzy do kolejnych modów, a nie potwierdzenie idealnej poprawności Expedition Saver.**
