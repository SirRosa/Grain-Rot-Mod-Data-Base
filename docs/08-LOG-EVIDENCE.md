# Dowody z realnych sesji: co dokładnie widzieliśmy

W `logs/` są skompresowane **zanonimizowane** logi (mogą być długie, oryginalne ścieżki systemowe usunięte). Opisy poniżej są wyciągnięte z wcześniejszych analiz faktycznych plików oraz obserwacji użytkownika. Pełne logi przefiltruj `zgrep ExpeditionSaver logs/*.gz` po rozpakowaniu plików z repo.

## Mapper: `UE4SS(1).log`

- `Mappings Generation Completed Successfully!`
- Generator wypisał rzeczywistą nazwę `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap`.
- F8/F9 działały, ObjectDump wygenerowany. Błędna początkowa instrukcja oczekiwania `Mappings.usmap` była niepoprawna.

## Expedition Saver v0.3: `UE4SS(2).log`

- Host `true`, `GameModeType=1`, faza aktywna `2`.
- `HOOK ACTIVE` dla hooków śmierci, lecz licznik **`rawDeaths=0`, `deaths=0`** podczas rzeczywistego zgonu.
- **`rawDestructions=369`, `destructionEvents=34`**; część z `no coin payout`.
- Log wypłaty z mebla `Radiator_01_C`: `gold=39` oraz `DROP gold=39`, ale użytkownik żadnych monet nie widział. Zatem ta fraza to wyłącznie informacja o wykonaniu kodu, a nie widzialna fizyczna moneta.
- `EndDungeonRunSequence_Multicast` z porażką; state 2→3→0. Winda mimo `machine=unlocked` pozostawała zamknięta na ekranie `Expedition Failed`.
- `main.lua:797: bad argument #1 to 'tostring' (value expected)` — naprawiono jawnie zwracając `nil` z normalizatora enum.
- Działały równolegle Depth Keeper v0.3 oraz QOL v0.1-preview. QOL logował `insurance delivery: 1 recorded, 1 spawned`.

## Expedition Saver v0.4: `UE4SS(4).log`

- Host `true`, Expedition aktywne; hooki physics wywoływane.
- **501 zdarzeń niszczenia**, **35 zaakceptowanych rewardów**; wypłaty Gold x9 / x15 / x45 za meble. Brak potwierdzonego Artifact Coin w tym teście.
- `BP_DefaultPhysTreasure_C` często miało `no coin payout` mimo faktycznego premiowego lootu; kod nie sprawdzał właściwej tabeli wartości.
- Moneta `BP_Coin_Gold_01_C`, `meshVisible=true`, ale gracz zgłosił unoszenie się w powietrzu — brak native simulate physics/gravity.
- `1` zgon, natywny respawn zadziałał; log: `retained=1`, a po nim `EQUIPMENT native=0 moved=1 recreated=0 unavailable=0`. To nie była odbudowa slotów.
- **Żadnego snapshotu `Money`** w v0.4 — pieniądze i itemy traciły się.
- QOL wykazał zmiany **63 ConstructAssetData**, **62 PhysActorData**, **44 ItemData**; jego mnożniki z lokalnych ustawień mogły być 3× i 15× zależnie od klasy. Nie nakładaj drugiego mnożnika.
- DepthKeeper i QOL nadal załadowane jednocześnie — to możliwy czynnik konfliktowy, nie jedyne wyjaśnienie błędów.

## v0.5

- Zmiany: `ItemSlots`, `EquipedItems`, `Money`, native `Interact`, fallback spawn, treasure mapping, gravity + physics.
- **45 mock testów** i poprawny workflow Actions 44761406133.
- **Użytkownik napisał: „ok na tym etapie jest sukces”**. Brak nowego logu v0.5. Nie nadinterpretuj: nie wiemy jeszcze, czy każda rzecz/fizyka/replikacja/wipe zostały oddzielnie sprawdzone.

## Wybrane frazy do grep

`HOOK ACTIVE`, `HEARTBEAT`, `PLAYER STATE`, `PLAYER DEATH queued`, `NATIVE RESPAWN`, `REVIVE FALLBACK`, `INVENTORY RECOVERY`, `INVENTORY RESULT`, `MONEY RESTORE`, `DESTRUCTION`, `TREASURE REWARD UNRESOLVED`, `COIN PHYSICAL`, `COIN PHYSICS ERROR`, `DROP gold`, `DROP artifacts`, `RECOVERY`, `FAILURE DOOR`, `Expedition Failed`, `poll error`.

**Zasada:** wynik `pcall=true` znaczy tylko brak wyjątku. Dla stanu gry potrzebujesz potwierdzenia po `OnRep`, w świecie, na drugim kliencie i w zapisie.
