# Ekonomia, loot, grinder, extraction, QOL, Artifact Coins

## Cel użytkownika

Po zniszczeniu dowolnego przedmiotu w Expedition (również białego, niebieskiego i fioletowego) otrzymać **niezależnie od scrapów** to, co przedmiot zapewniłby na extraction, w takich samych ilościach: Gold i Artifact Coins jako fizyczne podnoszone monety. Bez klawisza F7. Obecne zasady gry dotyczące zwykłego scrapu/resource dropów pozostają nietknięte. Gdy QOL zmieni nagrody, użyć jego **ostatecznych wartości runtime**, nie nakładać drugiego mnożnika.

## Wykrywanie niszczenia

- Rejestracja `HeldenPhysicsActor:OnHealthModifed` (oryginalna literówka) i `PlayDestructionEffect_Mulitcast` (oryginalna literówka).
- Nie polegaj wyłącznie na pierwszym pre-hook: przy `OnHealthModifed` HP może wynosić jeszcze >0; można też obserwować post-hook. Multicast może odpowiadać za wizualny efekt bez faktycznej utraty zdrowia.
- Musi istnieć **serwerowy autorytet**; unikaj naliczenia tego samego obiektu z dwóch hooków (idempotencja per `path(actor)` i kontrola zniszczenia). Unikaj rekurencji przez coins/pickups i przedmiotów questowych.
- W v0.4 501 zdarzeń callbacku i 35 zaakceptowanych rewardów; wiele callbacków dotyczyło rzeczy, które nie powinny płacić monet, stąd filtrowanie jest potrzebne.

## Źródła wartości (kolejność, ważne zera)

1. Wariant konstrukcji: `HeldenConstructActor:GetConstructAssetData()` oraz ewentualnie `GetConstructAsset()`; sprawdź `Parsed_ScrapValue_Common`, `_Rare`, `_Epic`, zależnie od enumu `EHeldenConstructQuality` (0/1/2). **Nie używaj nieistniejącego pola `ConstructAsset` na generycznej klasie PhysicsActor** — prawdziwe pole jest właściwe podklasie.
2. Niezerowa `GetInspectData().Value` z klasy, która rzeczywiście ją implementuje.
3. `HeldenDataSingleton.PhysActorDataTable` -> `HeldenPhysActorData.Parsed_ScrapReward` po kluczu `StatsDataName`, `ConstructDataName`, `InitConAsset`, `SetupConstructAsset` itp. `PhysActorDataTable` QOL modyfikuje podczas ładowania.
4. Dla `BP_DefaultPhysTreasure_C`: `HeldenDataSingleton.PhysTreasureContainer.TreasureData`, dopasowanie `RootMesh.StaticMesh` do `TreasureData.StaticMesh`, a następnie `TreasureData.DataName` -> wiersz `PhysActorDataTable`. W v0.4 `GetConstructAssetData()` często zwracało **zero**, lecz skarb miał realną wartość extraction.
5. Jeśli brak danych, **nie wymyślać wartości**. Loguj `TREASURE REWARD UNRESOLVED` z klasą, DataName i meshem (bez prywatnych ścieżek systemowych).

## QOL — fakty z rzeczywistego testu

Mod GrainRotQOL v0.1.0-preview (źródła w `reference/other-mods/GrainRotQOL/`) zmieniał runtime DataTables. Log v0.4 wykazał **63** wiersze `ConstructAssetData`, **62** `PhysActorData`, **44** `ItemData`. W pliku domyślne mnożniki m.in. `LootGoldMult=3`, `JunkGoldMult=15` dla niektórych kategorii. Monety Gold x9 / x15 / x45 za zniszczone meble pochodziły z tabel po zmianie przez QOL; użytkownik miał wątpliwości, czy ilości są zgodne z extraction. **Nie potwierdzono jeszcze porównania 1:1 każdej kategorii**.

**Reguła:** modyfikacja tabel przez QOL -> odczyt już zmodyfikowanej liczby -> payout fizycznej monety. Nie wykonywać kolejnego `value * LootGoldMult`, bo użytkownik dostanie podwójny mnożnik. Jeżeli QOL wykonuje swoją zmianę później niż nasz mod, można poczekać na zakończenie inicjalizacji i sprawdzić rzeczywistą wartość wiersza.

## Monety i fizyka

`HeldenDataSingleton.GoldCoinActorClass` oraz `ArtifactCoinActorClass` są klasami do `SpawnActor` na hoście. Nowemu `HeldenPhysicsCoin` przypisuj tylko odpowiednie pole struktury `Money={Gold,Artifacts,Scraps}`. Sprawdź odczyt `coin.Money` po przypisaniu — może to być proxy/kopia UStruct, w v0.3 była wymagana kontrola. Po poprawnym spawnie: replikacja aktora, widoczność, kolizja, **fizyka** `RootMesh:SetSimulatePhysics(true)`, `RootMesh:SetEnableGravity(true)`, `RootMesh:WakeAllRigidBodies()`.

- **Błąd v0.4:** aktor monety miał `meshVisible=true`, `collision=true`, lecz wisiał w powietrzu, bo `SimulatePhysics` i grawitacja nie były włączone na komponencie.
- Pojedynczy fizyczny aktor może reprezentować `Money.Gold=45`, a nie jedną sztukę waluty. Nie szacować wartości po liczbie meshów na ziemi; sprawdzić `Money` albo faktyczny przyrost konta po pickupie.
- Spawnowanie nad posadzką musi unikać umieszczenia monety we wnętrzu mebla lub geometrii. Grawitacja powinna ją opuścić na ziemię. Zbyt wysoki spawn (`Z+130`) oraz brak fizyki prowadziły do zawieszonych monet; v0.5 obniża do `Z+55` i włącza sim.
- `HeldenPhysicsCoin.Interact_Auth(InCharacter)` to natywna ścieżka pickup; sprawdzić podczas testu, że moneta jest fizycznie podnoszona oraz powiększa odpowiedni typ waluty **raz**.
- `HeldenCoinDispenser` ma `MaxGoldPerCoins`, `MaxArtifactsPerCoin`, `MinGoldMergeThreshold`, `PhysImpulseRange`. Można go użyć jako wzorca, ale w USMAP nie ma gwarancji funkcji publicznego spawnu; nie zakładaj, że `SetReplicates(true)` zastąpi całe inicjalizowanie coin dispensers.

## Wymagane testy dla nowego moda ekonomicznego

1. Każdy kolor/quality: biały/common, niebieski/rare, fioletowy/epic i zwykły złom. Minimum po 3 różne obiekty kategorii.
2. Porównaj dokładnie wartość nagrody po **faktycznej extraction** z nagrodą po zniszczeniu tego samego rodzaju w tej samej konfiguracji QOL (na zapasowych sejwach). Licz Gold/Artifacts, nie tylko mesh monet.
3. Sprawdź host i klienta: moneta widoczna, spada na podłogę, da się podnieść, saldo jest replikowane, brak nagrody podwójnie za dwa hooki.
4. Wyłącz QOL: vanilla DataTable; włącz QOL: aktualne mnożniki; zmień mnożniki: porównaj ponownie bez patchowania Expedition Saver.
5. Oddziel test `bIsQuestObjective`, obiektów kupionych/built i dropów native resource, aby nie drukować waluty ze stawianych własnych mebli.

**Stan dowodów:** v0.4 miał prawdziwe wypłaty Gold za meble, ale bez fizyki; wartościowe treasure nie płaciły. v0.5 zawiera naprawę i użytkownik ogólnie potwierdził sukces. **Brak końcowego logu potwierdzającego osobno każdą nagrodę.**
