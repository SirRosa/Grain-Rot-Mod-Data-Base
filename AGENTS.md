# Instrukcje dla następnego asystenta AI (Grain Rot / Helden / UE4SS)

> Przeczytaj README.md oraz `docs/00-HANDOFF.md`, `docs/01-HISTORY-AND-FAILURES.md` i `docs/07-OPEN-QUESTIONS.md` **przed** pisaniem kolejnego moda. Ten plik nie oznacza, że wcześniejszy mod jest absolutnie bezbłędny.

## Kontekst i preferencje

- Użytkownik mówi po polsku; oczekuje konkretów, analizy, weryfikacji, gotowych plików i prawdziwych commitów, nie tylko porad. Nie deklaruj sukcesu na podstawie samego GitHub Actions.
- Nowe mody powinny mieć osobne repo i własną nazwę; ta baza wiedzy jest **repozytorium referencyjnym**, a nie folderem instalacyjnym dla gry.
- Użytkownik ma dostęp do GitHub i GitHub Actions. Sprawdź narzędzia connectora, faktycznie wprowadź zmiany, sprawdź SHA commita i stan workflow; podawaj linki.
- Gra: Grain Rot, nazwa projektu Unreal `Helden`, UE5.7 (wygenerowany mapping), UE4SS widoczny w logach **v3.0.1 Beta #0 / Git SHA #1c1a1497**. Nazwa pobranej paczki UE4SS może być inna niż runtime — log ma pierwszeństwo.
- Mod może działać tylko na hoście (GameMode autorytatywny). Testuj osobno hosta, klienta, wipe i ponowne uruchomienie zapisu.

## Porządek pracy (wymagany)

1. **Najpierw artefakty.** W `data/` jest prawdziwy `Helden*.usmap.gz`, parsowany `current-schema.json.gz` oraz pełny `UE4SS-ObjectDump.txt` w sześciu częściach. Scalenie opisano w `data/README.md`. Sprawdź dokładną klasę i poprawną literówkę nazwy metody, nigdy nie wymyślaj podpisu z intuicji.
2. **Odróżniaj dowody:** (A) struktura z USMAP/dumpu, (B) callback/saldo/aktor widziany w realnym logu, (C) obserwacja gracza, (D) test Lua mock. (D) nie zastępuje (B)+(C).
3. **Jeden mechanizm na etap:** najpierw read-only heartbeat i hook activation, potem tylko jedna modyfikacja. Włączaj diagnostykę dla pojedynczego aktora, ograniczaj spam.
4. **Host authority:** zmiany `Money`, `CurrentDungeonRun`, slotów, spawn i GameState tylko na autorytatywnym serwerze. `RegisterHook()` sukces oznacza rejestrację, nie wykonanie callbacku.
5. **Zabezpiecz save.** Przed testowaniem śmierci/permadeath powinna istnieć kopia sejwa. Nie niszcz przedmiotu oryginalnego, jeżeli nie udało się potwierdzić dostarczenia ekwiwalentu. Nie zastępuj uznanego za martwy unikalnego przedmiotu losowym nowym bez dowodu tożsamości.
6. **Brak duplikacji:** nie naliczaj nagród ponownie, gdy QOL już zmienił DataTable. Zapamiętaj identyfikator aktu (`path`) i stan transakcji. Dla graczy waluta może pozostać w miejscu śmierci — zabezpieczenie salda nowej postaci może wówczas dopuścić duplikat przy późniejszym podniesieniu.
7. **Ostateczna akceptacja gry:** widoczność, kolizja, fizyka, pickup, replikacja i trwałość po reloadzie, a nie samo zwrócenie wyniku `pcall`.
8. **Jakość:** `luac -p`, mock testy i GitHub Actions; potem koniecznie **log prawdziwej sesji** z oznaczeniem wersji, hosta, etapu i wyników.
9. **Publiczna baza:** nie dodawaj oryginalnych surowych logów z prywatnymi ścieżkami, SteamID/IP/e-mailami, zapisów graczy, tokenów, binariów gry ani cudzych paczek bez prawa redystrybucji.
10. **Dokumentuj:** każde obejście opisuj przez „widziane w logu”, „potwierdzono w grze”, „hipoteza”, „test mock”, z linkiem do commita i SHA256 artefaktów.

## Najważniejsze pułapki już napotkane

- `os.clock()` **nie jest zegarem ściennym** w Windows. W v0.2 blokował odliczanie próśb respawnu/dropów/naprawy windy. Użyj rzeczywistego timera UE4SS / liczników pętli.
- `FindFirstOf()` może zwrócić aktora ze starej sceny; upewnij się, że obiekt należy do aktywnego świata i ma `GameModeType=1`.
- Reflektowane `HeldenCharacter.Die_Auth` oraz Blueprint `OnPlayerKilled` **nie wywołały się** przy rzeczywistej śmierci v0.3. Działające obejście: polling `CharacterState.Dead`, health, controller/soul i snapshot przed śmiercią.
- Przedmioty są w `EquipedItems` **oraz** `ItemSlots[].CurrentItemInSlot`; pominięcie drugiej tablicy zostawiło tylko 1 zapisany przedmiot. `teleport` na podłogę windy ≠ zapis do ekwipunku.
- Moneta `HeldenPhysicsCoin.Money` z dobrą kwotą może wisieć bez `RootMesh:SetSimulatePhysics(true)` i `SetEnableGravity(true)`.
- Wartościowe `BP_DefaultPhysTreasure_C` mogą mieć **zerowe** construct scrap, ale niezerową wartość extraction w PhysActorData / PhysTreasureContainer. Nie kończ na pierwszym zerze.
- `GetInspectData()` nie przysługuje każdej `HeldenPhysicsActor`; `GetConstructAssetData` jest w `HeldenConstructActor`. Sprawdzaj klasę/metodę, nie używaj pcall jako zamiennika rozumienia API.
- `BP_ExpeditionFailed_Actor_C` ma osobną blokadę fizycznych drzwi. Reset flag `GameState` sam nie otwiera windy.
- USMAP automatycznie nazywa plik `Helden-5.7.4-...usmap`, a nie `Mappings.usmap`.
- Błąd Lua `bad argument #1 to 'tostring' (value expected)` pochodził z funkcji `enum()` zwracającej zero wartości, nie jawne `nil`.

## Jak kontynuować

Przykładowa wiadomość użytkownika: „Przeczytaj AGENTS.md oraz komplet `docs/`, odbuduj dump według `scripts/reassemble.py`, sprawdź obecny build UE4SS, a dopiero potem projektuj nowy mod. Każdą zmianę wykonaj w repo i potwierdź commitem oraz workflow. Nie myl mocków z testami w grze”.
