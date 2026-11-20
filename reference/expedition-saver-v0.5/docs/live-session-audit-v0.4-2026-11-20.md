# Audyt v0.4 → plan napraw v0.5, 20 listopada 2026

Źródło: osobisty log `UE4SS(4).log` z prawdziwej sesji. Nie dodano do repozytorium pełnego logu ani ścieżek użytkownika.

## Fakty

- Host prawidłowo uruchomił `ExpeditionSaver v0.4.0-alpha` w trybie Expedition (`mode=1`, `phase=2`).
- Wykryto **501** zdarzeń niszczenia, **35** zaakceptowanych wypłat, w tym Gold x9, x15 i x45 za meble. Nie odnaleziono potwierdzonej wypłaty Artifact Coins w tej sesji.
- Moneta Gold była tworzona jako `BP_Coin_Gold_01_C`; log v0.4 potwierdzał `meshVisible=true`, ale **nie włączał symulacji fizyki** — stąd monety unosiły się w powietrzu.
- Kilka `BP_DefaultPhysTreasure_C` (rzeczywiste przedmioty z lootem) miało `DESTRUCTION ... (no coin payout)`. Trasa odczytu wartości kończyła się na zerowych polach konstrukcji i nie dochodziła do tabeli TreasureData / PhysActorData.
- Zarejestrowano **1 śmierć** postaci i udane natywne `RespawnCharacter_Server`. Kod zapisał `retained=1` oraz `EQUIPMENT native=0 moved=1 recreated=0 unavailable=0`: przeniósł tylko jeden przedmiot **na podłogę windy**, a nie do slotów gracza.
- W kodzie v0.4 nie było żadnego snapshotu `HeldenCharacter.Money`, więc Gold / Artifacts / Scraps były tracone przy śmierci, nawet przy udanym respawnie.
- W sesji nadal działały **GrainRotDepthKeeper v0.3.0** i **GrainRotQOL v0.1.0-preview**. QOL poprawnie zmodyfikował 63 wiersze ConstructAssetData, 62 PhysActorData oraz 44 ItemData. Konfiguracja QOL w paczce: `LootGoldMult=3`, `JunkGoldMult=15` przy bazowym złocie 1. Wartości x9, x15 i x45 nie powinny być mnożone przez ExpeditionSaver ponownie.

## Zmiany v0.5

1. **Pełniejszy snapshot ekwipunku:** `EquipedItems`, wszystkie `ItemSlots[].CurrentItemInSlot` i przedmioty z `PreviousOwner` + `CurrentSlot`. Unikatowe identyfikatory `DynamicSaveName` i numer slotu zmniejszają ryzyko utracenia dwóch itemów tej samej klasy.
2. **Prawdziwe podnoszenie zamiast teleportacji:** po respawnie mod kilkakrotnie wywołuje natywne `item:Interact(pawn)`, a gdy potrzeba `PlayerController:Interact_Server(pawn, InteractComponent)`. Sprawdza obecność w rzeczywistych slotach. Jeżeli metoda gry nie zadziała, przedmiot pozostaje dostępny w windzie i log nie zgłasza fałszywego sukcesu.
3. **Przedmioty zniszczone przez silnik:** pojedyncza, ograniczona próba ich odtworzenia z zapamiętanej klasy, assetu, trwałości i enchantmentu; brak cyklicznego duplikowania. Nie usuwa oryginału ani innych aktorów.
4. **Pieniądze:** snapshot `Character.Money` przed śmiercią. Po respawnie kod uzupełnia tylko brakujące wartości Gold, Artifacts, Scraps; nie obniża większych sald zastanych na nowej postaci. **Uwaga:** wymaga testu, czy gra pozostawiła walutę w miejscu śmierci — potencjalne duplikaty należy wyeliminować na podstawie nowego logu.
5. **Fizyka monet:** `SetSimulatePhysics(true)`, `SetEnableGravity(true)`, `WakeAllRigidBodies` na `RootMesh`; spawn bliżej punktu zniszczenia i osobny log stanów symulacji oraz grawitacji.
6. **Skarby:** zerowa `Parsed_ScrapValue_*` z `GetConstructAssetData` nie kończy obliczeń. Mod próbuje aktualne wiersze `PhysActorDataTable` po kluczach DataName oraz mapowanie `PhysTreasureContainer.TreasureData` według faktycznego mesha obiektu, co pozwala odczytać nagrody zmodyfikowane wcześniej przez QOL.

## Ograniczenia / ryzyka

- Nie da się jeszcze stwierdzić, czy `Interact` faktycznie wyposażający przedmiot zadziała na tym buildzie Grain Rot. Dopiero log `INVENTORY RESULT inventory=N floor_or_missing=0` i wizualna kontrola slotów potwierdzą sukces.
- Jeżeli native pickup nie zadziała, nie wykonujemy niezweryfikowanych bezpośrednich zapisów do wewnętrznych tablic UObject. Utrzymujemy item fizycznie w windzie jako bezpieczniejszą alternatywę dla usunięcia.
- Nie wszystkie `BP_DefaultPhysTreasure` muszą mieć dopasowany rekord mesha. Niewyjaśnione `TREASURE REWARD UNRESOLVED` wymagają logu z v0.5, a nie wymyślania mnożników.
- Testy GitHub Actions są symulacyjne. Stany inventory, physics i multiplayer muszą zostać potwierdzone na kopii zapisu.
- **Na testach wyłączyć GrainRotDepthKeeper.** W QOL wyłączyć `InsuranceOnWipe`, gdyż ubezpieczenie QOL może osobno odtworzyć ten sam sprzęt przy wipe.

