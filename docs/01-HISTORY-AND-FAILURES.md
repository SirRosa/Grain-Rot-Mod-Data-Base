# Historia projektu, błędów, hipotez i napraw

## Etap 0 — narzędzie diagnostyczne ExpeditionMapper

Zaczęto od read-only moda `ExpeditionMapper` na UE4SS, który uruchamia `DumpUSMAP()` przez **F8** oraz `DumpAllObjects()` przez **F9**. Narzędzie działało, wygenerowało nowy USMAP i ObjectDump, nie dotykało rozgrywki. Instrukcje początkowo sugerowały plik `Mappings.usmap`; **to było błędne**. Runtime wygenerował `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap`. UE4SS w logu potwierdza `Mappings Generation Completed Successfully!`.

Starszy USMAP: 2 172 010 B, 10 867 struktur, 2165 enumów. Nowy: 2 223 017 B, 11094 struktur, 2207 enumów. +227 typów i +42 enumy to **nie jest dowód aktualizacji gry** — build w nazwie bez zmian, różnice mogą zależeć od załadowanych obiektów.

## v0.1.0-alpha — zbyt optymistyczna implementacja

Pierwsza wersja gameplay była zbudowana na odczytanych podpisach, ale bez prawdziwych callbacków, a konwersja wartościowego lootu opierała się na **F7** (wbrew oczekiwaniom użytkownika, który chciał automatycznego niszczenia). Respawn nie działał, winda po porażce zamknięta, Artifact Coins nie wypadały. Samo rejestrowanie hooków nie wykazało, czy engine je wywołuje.

## v0.2.0-alpha — przejście na automatyczne niszczenie, nadal brak działania

Wprowadzono automatyczne hooki `HeldenPhysicsActor:OnHealthModifed` oraz `PlayDestructionEffect_Mulitcast` (pisownia jest taka w reflected API), usunięto F7, dodano `HeldenPhysicsCoin.Money`, zresetowanie run state i interakcję maszyny windy. Wywołanie `GetInspectData` na ogólnej `HeldenPhysicsActor`, użycie nieistniejącego pola `ConstructAsset` oraz błędne odczyty słabej referencji `OwningDungeon` blokowały część wypłat. Metody i pola trzeba sprawdzać na **konkretnej klasie**, nie na domniemanym rodzicu.

Inny istotny błąd: `os.clock()` na Windows to **czas CPU**, nie ścienny. Opóźnienia (respawn, payout, retries, heartbeat) mogły wykonywać się znacznie później niż zamierzono. Zmieniono je na liczniki ticków pętli gry.

## v0.3.0-alpha — log prawdziwej gry obala założenia

W realnej sesji `UE4SS(2).log`:

- UE4SS poprawnie załadował mod; host=true, Expedition mode=1.
- 0 wywołań callbacków `HeldenCharacter.Die_Auth` i `HeldenPlayerController.OnPlayerKilled` podczas faktycznej śmierci.
- 369 zdarzeń niszczenia, 34 zaakceptowane jako rzeczywiste obiekty, ale tylko jedna potwierdzona przez log monetą wypłata **Gold=39** za `Radiator_01_C`. Nie jest to dowód, że użytkownik widział/podniósł monetę.
- Realny `EndDungeonRunSequence_Multicast` z porażką. Mod resetował `GameState` i ustawiało się `machine=unlocked`, lecz ekran i fizyczna brama nadal mówiły **Expedition Failed**.
- Jednorazowy Lua runtime error: `bad argument #1 to 'tostring' (value expected)` z `enum()` zwracającym zero wartości; naprawa: jawne `return nil`.
- `GrainRotDepthKeeper v0.3.0` i `GrainRotQOL v0.1.0-preview` były włączone równolegle — ich wpływ na stan ekspedycji i ekwipunek trzeba izolować.

## v0.4.0-alpha — pierwszy udany respawn, ale niszczenie ekwipunku

Rozwiązanie: polling gracza 300 ms, `ECharacterState.Dead=1`, `CharacterStats.CurrentHealth`, `SoulCharacter`, `LastPlayerChar`; snapshot poprzedniej żywej postaci i jej itemów przed śmiercią. Dodano `BP_ExpeditionFailed_Actor_C` fizycznie blokujący windę. Po nieudanym RPC fallback przywracania istniejącego pawna. Dodano wizualizację fizycznych monet nad przedmiotem.

W **realnym** `UE4SS(4).log` i w obserwacji użytkownika:

- **Odrodził się w windzie.** To pierwsze potwierdzenie w grze.
- Jednak `retained=1` (zapisano tylko 1 item), `EQUIPMENT native=0 moved=1 recreated=0 unavailable=0` — item po prostu **teleportowano na podłogę**, zamiast dodać go do slotu.
- Brak jakiegokolwiek snapshotu `HeldenCharacter.Money`. Użytkownik stracił Gold/Artifacts/Scraps oraz część itemów bezpowrotnie.
- 501 zdarzeń niszczenia, 35 zaakceptowanych nagród; Gold x9/x15/x45 za meble, brak pewnego Artifact Coin z wartościowego lootu; `BP_DefaultPhysTreasure_C` miało `no coin payout`.
- **Gold monety wisiały w powietrzu**, bo kod ustawił widoczność/kolizję, ale nie włączył symulacji fizyki `RootMesh` ani grawitacji.
- `Expedition Failed` **nie został przetestowany** w tym konkretnym runie — bo gracz wrócił do windy przed pełnym wipe.

## v0.5.0-alpha — iteracja uznana ogólnie za sukces przez użytkownika

- Snapshot rozszerzony o `EquipedItems`, **wszystkie** `ItemSlots[].CurrentItemInSlot`, `PreviousOwner` + `CurrentSlot`, klasy, identyfikatory i sloty. Nie zakładaj, że wszystkie itemy są w `EquipedItems`.
- Snapshot i uzupełnianie `Character.Money`: Gold, Artifacts, Scraps. Nie obniża większych sald już na nowej postaci. Uwaga na możliwą duplikację jeśli loot pozostał w miejscu śmierci.
- Natywne `Interact(InCharacter)` i awaryjne `Interact_Server` do ponownego podniesienia / zapisania itemu; rygorystyczne sprawdzanie, czy jest w slocie. Jeśli się nie powiedzie, zostawić bezpiecznie w windzie i logować brak pełnego przywrócenia.
- `RestoreDestroyedItems=true` — jednorazowa próba stworzenia przedmiotu z tej samej klasy / assetu / durability / enchant. Ryzyko unikalnych ID wymaga dalszej weryfikacji.
- Gold/Artifact Coins: moneta spawn bliżej punktu zniszczenia; `RootMesh:SetSimulatePhysics(true)`, `SetEnableGravity(true)`, `WakeAllRigidBodies`.
- `BP_DefaultPhysTreasure_C`: zerowa wartość construct nie kończy lookupu; `HeldenPhysTreasureContainer.TreasureData` mapowane po `StaticMesh` -> `DataName` -> `PhysActorDataTable.Parsed_ScrapReward`. QOL runtime data są źródłem prawdy.
- 45/45 scenariuszy w Lua CI PASS. **Nie mamy logu v0.5.** Użytkownik powiedział tylko „na tym etapie jest sukces”, co zapisujemy jako ogólne potwierdzenie postępu, nie gwarancję całej logiki.

## Lista błędnych założeń, których nie powtarzać

| Błędne założenie | Co dowiodła praktyka |
|---|---|
| `RegisterHook()` bez erroru = funkcja działa | Callback może mieć 0 wywołań w realnym runie |
| `HasFailedExpedition() = false` odblokuje windę | Istnieje osobny Blueprint `BP_ExpeditionFailed_Actor_C` |
| `OnPlayerKilled` wywoła się przy każdej śmierci | W v0.3 nie wywołał się ani razu |
| `GetInspectData` jest metodą dowolnego fizycznego obiektu | Zależy od klasy; odczyt trzeba oprzeć o refleksję |
| Zwrócone 0 z pierwszego pola = przedmiot bez wartości | Skarb ma alternatywne DataTable / treasure mesh |
| Spawn monety i kolizja = fizyka działa | Potrzebna grawitacja i `SimulatePhysics` na primitive RootMesh |
| Teleport itemu do windy = item w inwentarzu | Fizycznie leży na podłodze, gracz nadal go nie ma |
| Przechwycenie jednej listy = kompletny ekwipunek | `EquipedItems` + `ItemSlots`, a pieniądze osobno |
| Mocki CI = skuteczny mod | 40 mocków przechodziło przed realnym sukcesem |
| `os.clock()` można użyć jako 300ms timer | Nie na Windows; to czas CPU |
