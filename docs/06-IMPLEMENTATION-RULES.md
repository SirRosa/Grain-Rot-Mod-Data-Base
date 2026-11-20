# Podręcznik budowania kolejnych modów UE4SS dla Grain Rot

## 1. Pierwsze 15 minut: dochodzenie, nie kodowanie

1. Otwórz `AGENTS.md`, `docs/00-HANDOFF.md`, `docs/01-HISTORY-AND-FAILURES.md`, `docs/02-UE4SS-REFLECTION.md`, `docs/07-OPEN-QUESTIONS.md`.
2. Odzyskaj `data/UE4SS-ObjectDump.txt` z sześciu części (`python scripts/restore_assets.py`) i `data/current-schema.json`. Zweryfikuj SHA256 wyjściowych plików.
3. Znajdź *konkretną* klasę aktora lub komponent i reflektowaną funkcję, jej owner, parametry, typy pól, alternatywy Blueprint/C++ i literówki. W kodzie nie wymyślaj `On...`/`Get...` na podstawie intuicji.
4. Dla nowego moda ustal: czy działa on tylko u hosta, w lobby, w Expedition czy poza nim? Który poziom/mapa? Jakie mody towarzyszące i jakie wersje UE4SS?
5. Przygotuj **read-only** prototyp: `RegisterHook` i/lub timer na wątku gry, log co kilka sekund, pojedyncze parametry aktora. Nie ingeruj na tym etapie w sejw.

## 2. Cykl diagnozy oparty na realnym runtime

**Poziomy wiarygodności:** `DUMP` = sygnatura istnieje; `MOCK` = modelowa funkcja Lua zachowuje się w teście; `LOG` = callback rzeczywiście wywołał się w grze; `USER` = gracz widział efekt; `RELOAD/NETWORK` = zachował się po save/load i u klientów. Nie stawiaj znaku równości między poziomami.

`RegisterHook()` może zwrócić identyfikatory i wypisać `HOOK ACTIVE`, ale **silnik może nigdy nie wywołać tego UFunction** w badanej ścieżce (śmierć z v0.3!). Monitoring zachowania actor/state daje niekiedy lepsze dane od hooka, choć sam również może pominąć krótkie stany.

Timer z UE4SS v3: sprawdź dostępność `LoopAsync` + `ExecuteInGameThread` albo `LoopInGameThreadWithDelay`. **Nie dotykaj UObject z wątku worker**. Dla callbacku regularnego stosuj liczniki ticków/scheduler, *nie `os.clock()` do wall-time* (na Windows mierzy CPU time). Każdy UI keybind, który wykonuje niebezpieczne operacje na aktorach, przekazuj na game thread.

Na hookach korzystaj z `pcall` z jawnie zalogowanym błędem; `RemoteUnrealParam` może wymagać `:get()`, `FWeakObjectPtr` może wymagać `:Get()`. Obie formy są **różnymi mechanizmami**. Zweryfikuj na realnym obiekcie zamiast bezmyślnie wywoływać jedną metodę dla wszystkich.

**Lua edge case:** `return` bez argumentu zwraca *zero wartości*, co może rzucać `bad argument #1 to 'tostring' (value expected)` w `tostring(enum(...))`. Zawsze jawnie `return nil` w gałęzi domyślnej enumów. Różnice między reprezentacją enum (liczba, userdata, string) wyraźnie normalizuj; brak wartości to nie `0`.

## 3. Bezpieczne mutacje stanów i transakcje

- Kryterium hosta: sprawdź obecność prawdziwego `HeldenGameMode` / `GameModeBase`, nie `Default__` CDO, a także aktywny `HeldenGameState.GameModeType` i save slot. Po transferze mapy cached actor może być nieaktualny; odczytaj go ponownie.
- Pełen wipe i respawn: `EHeldenDungeonRunState` nie jest tym samym co flagi `MetaData.bHasFailed`. Wizualne drzwi mogą mieć własny `BP_ExpeditionFailed_Actor_C` i niezależny stan kolizji.
- Ekwipunek: *najpierw snapshot* itemów i `Money`, potem native respawn, potem reconcile native inventory. **Nie nazywaj sukcesem teleportu itemu na ziemię.** Potwierdź `ItemSlots`, właściciela i salda; również po reloadzie.
- Unikaj duplikacji: pojawienie się nowego pawna nie znaczy, że jego `Money=0` należy bezwarunkowo nadpisać. Gra może zostawić death drops w świecie, a QOL może robić `InsuranceOnWipe`; jeden item może występować w obu miejscach.
- Wypłaty: sprawdź, czy native grinder już nie nalicza złota/Artifact Coins; nie rób drugiej wypłaty. Przedmioty typu `BP_DefaultPhysTreasure_C` mają osobne mapowanie do `TreasureData` i nie muszą mieć niezerowej wartości w `GetConstructAssetData()`.
- Fizyczne monety: spawn w autorytatywnym `World` + waluta w `HeldenPhysicsCoin.Money` to **początek**, nie koniec. Właściwy komponent `RootMesh`: ruchomy, sim physics, gravity, collision, replicates. Potwierdź na ekranie, że opada i można podnieść. `SetActorEnableCollision(true)` bez `SetSimulatePhysics` dawało wiszące monety.
- Jeżeli nie uda się transakcja pickup/restore: pozostaw istniejący item, ogranicz retry, wypisz jednoznaczny warning. Nie sprzątaj aktora, którego jedyną kopię gracz może utracić.

## 4. Jak projektować testy

- `lua5.4` i `luac5.4 -p` we workflow.
- Mocki powinny zawierać: użycie host/client, zwykłą grę vs Expedition, obiekty `Default__`, opóźnienie/tick, `CurrentDungeonRun.Flags`, zmianę `CurrentSaveGame`, istnienie 2 itemów *tej samej klasy*, przedmiot tylko w `ItemSlots`, nieobecny actor po death, `Money` 3 walut, 0-value premium loot, `PhysTreasureContainer` z meshem, spawnowanie/kolizje, błąd native pickup, brak klasy monet i antyduplikację.
- Zawsze testuj *odrzucenie* `pcall`/natywnej interakcji, a nie tylko sukces. **To mock**, nie silnik.
- Na host multiplayer zrób testy w mało wartościowym sejwie i osobno z klientem. Sprawdź save/reload; przy przedmiotach z danymi enchant/durability trzeba potwierdzić te atrybuty, nie tylko klasę.
- Przed kolejnym buildem sprawdź rzeczywiste pliki w repo i historię oraz ostatni udany workflow; commit SHA + run ID są dowodem wykonanej operacji GitHub, *nie jakości zachowania moda w grze*.

## 5. Zalecana organizacja repo nowego moda

`ue4ss/Mods/<ModName>/Scripts/main.lua`, `enabled.txt`, `tests/test_*.lua`, `.github/workflows/ci.yml`, `README.md` z wymogami, kompatybilnością, ryzykami i scenariuszem weryfikacji. W oddzielnym repo `mod-data-base` przechowuj tylko uogólnione ustalenia, sanitized logs i schematy, nie cały roboczy sejw.

## 6. Gotowe antywzorce z naszych iteracji

| Niewłaściwe | Dlaczego zawiodło | Lepsza metoda |
|---|---|---|
| `HOOK ACTIVE` = „działa” | Hooki śmierci nie wywołały się w realnym runie | Rejestracja + `RAW` callback + polling + test gracza |
| Respawn tylko po `Die_Auth` | Realna śmierć szła inną drogą | Monitor `CharacterState`, HP, Pawn, Soul |
| `CurrentDungeonRun.State=0` otworzy windę | Istnieje niezależny Blueprint blokady | Logika stanu + `BP_ExpeditionFailed_Actor_C` |
| `K2_TeleportTo(item, lift)` = odzyskano item | Item pozostał na ziemi i był tracony | `Interact`, `ItemSlots`, native owner, output outcome |
| `EquipedItems` = cały ekwipunek | Log pokazał `retained=1` | Także wszystkie `ItemSlots`, snapshot przed śmiercią |
| `SpawnActor` = widoczna moneta | W v0.3 nie było jej widać, w v0.4 wisiała | `RootMesh` physics, gravity, world position, actual pickup |
| `0` w `GetConstructAssetData` = brak wartości | Cenny treasure miał osobny reward row | `PhysTreasureContainer` + `PhysActorDataTable` |
| `os.clock()` do cooldown | Czas CPU, a nie zegarowy | Tick/real-time game scheduler |
| QOL mnożnik zastosowany jeszcze raz | Możliwe podwójne wypłaty | Aktualny `DataTable` runtime po QOL |
| Raport „45 testów: mod gotowy” | Mock nie odtwarza natywnego UE5 | Status `MOCK OK / GAME PENDING` |
