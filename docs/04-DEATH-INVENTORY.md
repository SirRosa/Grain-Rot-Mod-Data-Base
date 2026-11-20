# Śmierć, respawn, ekwipunek, waluta — analiza ryzyka utraty i duplikacji

## Dlaczego poprzednie implementacje przegrywały

- W v0.3 `HeldenCharacter.Die_Auth` i `HeldenPlayerController.OnPlayerKilled` nie wywołały hooka podczas faktycznej śmierci; `HOOK ACTIVE` to tylko rejestracja. Dlatego konieczny był **polling żywej postaci przed śmiercią** i osobne zdarzenie `OnRep_CharacterState`.
- W v0.4 faktycznie udał się respawn, ale log `retained=1` oznaczał snapshot tylko jednego przedmiotu — `EquipedItems` nie obejmowało kompletnych `ItemSlots`. Następnie `EQUIPMENT native=0 moved=1` oznaczało **fizyczne przesunięcie** itemu, a nie przypisanie do inwentarza. Użytkownik utracił resztę wyposażenia i pieniędzy.
- W v0.4 w ogóle nie rejestrowano pola `HeldenCharacter.Money`, więc nawet idealny respawn pawna nie chronił Gold, Artifacts i Scraps.

## Cykl v0.5 (źródło: `reference/expedition-saver-v0.5/`)

1. **Przed śmiercią:** każda iteracja gry (pętla ok. 300ms) sprawdza hosta, fazę runu, `PlayerController:GetPawn()`, `LastPlayerChar`, `SoulCharacter`, `CharacterState`, `CharacterStats.CurrentHealth` i migawkę sprzętu/walut. Pamiętaj, że interwał 300ms jest tylko deklarowanym opóźnieniem timera, nie twardą gwarancją fazy silnika.
2. **Wykrycie:** `Dead=1`, HP<=0, kontroler przeniesiony do SoulCharacter, albo state `EndScreen Failed` przy uprzednio żywym tracked playerze. `OnRep_CharacterState` zwiększa szansę. Wymagaj prawdziwego PlayerController, nie NPC.
3. **Zapis stanu:** `gearOf(char)` identyfikuje itemy z `EquipedItems`, wszystkich `ItemSlots[].CurrentItemInSlot` i z ważnym `PreviousOwner`/`CurrentSlot`; pola `ItemDataAsset`, `ItemDurability`, `ItemEnchantment`, `DynamicSaveName`, `CurrentInventorySlot`. `snapshotMoney()` zapisuje `Money.Gold`, `.Artifacts`, `.Scraps`. Wszelkie brakujące pola loguj jawnie.
4. **Natywny respawn na hoście:** `pc:RespawnCharacter_Server()` i maksymalnie kilka prób, ponieważ gra może przełączyć się w EndScreen. `OnNewPawn` i polling rozpoznają prawdziwego nowego player pawna, nie SoulCharacter.
5. **Po odrodzeniu:** przemieścić nowego pawna do środka `HeldenDungeonElevator.InteriorCollisionBox`, ustawić zdrowie, a dopiero potem rekoncyliować ekwipunek oraz waluty.
6. **Ekwipunek:** najpierw sprawdzenie, czy gra sama już umieściła item w slocie; dopiero dla brakującego aktora próby `item:Interact(pawn)` i ewentualnie `PlayerController:Interact_Server` (z prawidłowym komponentem). Nie zakładaj sukcesu z samego `pcall`: trzeba potwierdzić `pawn.ItemSlots` / `EquipedItems` i właściciela.
7. **Zniszczone przedmioty:** pojedyncza próba spawn tej samej klasy/assetu + trwałość + enchant, ale unikatowe ID przedmiotu może być generowane natywnie. Nie wolno klonować go w nieskończonej pętli ani dopisywać do slotów bez identyfikacji natywnego API.
8. **Waluty:** `recoverMoney` ustawia u nowej postaci co najmniej saldo ze snapshotu. Wartości zastane większe nie są obniżane. **Ryzyko:** jeśli oryginalne Gold/Artifacts/Scraps są nadal w miejscu śmierci, późniejszy pickup może dać drugą kopię. Do pełnej poprawności potrzebna semantyka native death drop.
9. **Potwierdzenie:** oczekuj `INVENTORY RESULT inventory=N floor_or_missing=0 fullyRestored=true`, `MONEY RESTORE`, plus wzrokowa kontrola wszystkich slotów, tego samego itemu, waluty i stanu po reloadzie.

## Model identyfikacji i antyduplikacji

- Tożsamość aktora: `GetFullName`/`path` w sesji; po odtworzeniu gra może dać nowe UObject path, więc to nie trwały GUID.
- `DynamicSaveName` może pomóc skojarzyć odbudowany natywny item; nie traktuj dwóch itemów tej samej klasy jako jednego.
- `CurrentInventorySlot` / `ItemSlots` są specyficzne dla gracza. Jeśli item ma ten sam typ, ale inną tożsamość i siedzi w innym slocie, nie powinien automatycznie „pokryć” utraconego itemu bez dodatkowego dowodu.
- W `HeldenSaveGame.ItemSaveData` są `OwningPlayer`, `OwningSlot`, `ItemId`, `bOnPlayerCharacter`, `Durability`, `Enchantment`. To potencjalnie lepsza droga trwałego ratowania przedmiotów, ale **jeszcze nie została zweryfikowana** do wprowadzania zmian bezpośrednio w save.
- Nigdy nie zniszczaj ostatniego oryginalnego obiektu, gdy `Interact` zawiedzie. Zostaw go na podłodze windy (z logiem niepełnego odzysku), zamiast ryzykować całkowite skasowanie przedmiotu.

## Współdziałanie z QOL i Depth Keeper

- QOL v0.1.0-preview ma opcję `InsuranceOnWipe` i w realnym logu v0.3 zgłosił `insurance delivery: 1 recorded, 1 spawned`. Jeśli jednocześnie odtwarzamy item, możemy stworzyć **duplikat**. Na testach zabezpieczania ekwipunku ustaw `InsuranceOnWipe=false`.
- Depth Keeper v0.3.0 może jednocześnie zmieniać stan zapisów/ekspedycji. Podczas testów Expedition Saver **wyłączyć Depth Keeper**, aby nie zacierać źródła zmian. To nie jest dowód, że konkretny bug wynikał z Depth Keeper.
- Użytkownik testował w single-host / z innymi modami; pełna replikacja i test osobnego klienta nadal są niezależnym wymaganiem.

## Macierz testów śmierci dla następnego moda

| Test | Sprawdzaj |
|---|---|
| 1 przedmiot wyposażony | ten sam item w slocie po respawn |
| 4–8 itemów różnych typów | wszystkie sloty, także puste i ekwipowane |
| 2 itemy identycznej klasy | oba zachowane jako osobne instancje |
| Przedmiot enchant / durability | wartości niezmienione po regen |
| Gold, Artifacts, Scraps | trzy salda na starej i nowej postaci |
| Wallet natywnie częściowo odzyskany | brak dodatkowego duplikowania większej kwoty |
| Zabicie i odrodzenie przy SoulCharacter | duch nie uznany za nowego gracza |
| Full team wipe | brak nieplanowanego EndScreen/permadeath, status windy |
| Klient i host | zgodność slotów, pieniędzy i fizycznych itemów |
| Save/reload po respawn | identyczna zawartość i unikalność itemów |

**Stan:** v0.5 ogólnie uznana przez użytkownika za sukces; niezależna, szczegółowa weryfikacja replikacji, dopasowania itemów i trwałości po reloadzie nadal nie jest udokumentowana.
