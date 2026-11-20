# UE4SS / USMAP / ObjectDump: techniczna mapa klas

**Pochodzenie:** odczyt lokalnego `current-schema.json` wygenerowanego z `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap`. Pełny zrzut i oba schematy są w `data/`. Refleksja potwierdza istnienie/pola, **nie** prawdziwe zachowanie natywnej implementacji.

## Format i runtime

- UE4SS w rzeczywistych logach: **v3.0.1 Beta #0**, Git SHA `1c1a1497`, gra: `Helden-Win64-Shipping.exe`, silnik UE5.7.4 wg nazwy mapowania.
- Generator mappera: F8 `DumpUSMAP()`, F9 `DumpAllObjects()`, ręcznie, bez autostartu. Nie oczekuj literalnego `Mappings.usmap`.
- USMAP to binarny format definicji reflektowanych typów; ObjectDump zawiera nazwy funkcji i obiektów UClass/UFunction. Metody C++ mogą mieć dodatkowe ograniczenia runtime.
- Liczby: obecny 2,223,017 B / **11 094 structs**, **2207 enums**; poprzedni 2,172,010 B / **10 867 structs**, **2165 enums**.

## Tryb Expedition i run

| Reflektowany typ | Kluczowe pola/metody |
|---|---|
| `EHeldenGameMode` | Default=0, **Expedition=1** |
| `EHeldenGameState` | Default=0, InDungeon=1 |
| `EHeldenDungeonRunState` | None=0, ElevatorRideDown=1, Exploring=2, EndScreen=3 |
| `EHeldenDungeonRunFlags` | None=0, Failed=1 |
| `HeldenGameState` | `GameModeType`, `bExpeditionFailed`, `CurrentDungeonRun`, `HasFailedExpedition()`, `EndDungeonRunSequence_Multicast(InStats)`, `OnRep_DungeonRunState` (z ObjectDump) |
| `HeldenActiveDungeonRun` | `State`, `Flags`, `DungeonActor`, `StartDungenRunTimeStamp` (literówka w API), `EndDungeonRunTimeStamp`, `DungeonRunParticipants` |
| `HeldenDungeonRunStats` | `DungeonLevel`, `bHaveFailed`, `Participants`, `ExtractedParticipants` |
| `HeldenGameInstance` | `CurrentSaveGame`, `ExpeditionLevel`, `StartingLevel`, `MenuLevel`, `CurrentLobbySettings` |
| `HeldenSaveGame` | `GameMode`, `GameState`, `DungeonLevel`, `CurrentLevel`, `MetaData`, `ActorSaveData`, `ItemSaveData`, `CharacterSaveData`, `SavedPlayers`, `StashMoney`, `DynamicSaveNameCounter` |
| `HeldenSaveGameMetaData` | `GameSlot`, `GameMode`, `bHasFailed`, `SaveSlotName`, `Timestamp` |

## Postacie, kontrolery, sloty

- `ECharacterState`: **Default=0, Dead=1**.
- `HeldenCharacter`: `CharacterState`, `CharacterStats`, `Money`, `EquipedItems` (pisownia z gry), `ItemSlots`, `bHasInventory`, `bCollisionAndMovementDisable`, `InteractComponent`. Reflektowane `Die_Auth(InInstigator, InDeathType)`; **realne testy v0.3 pokazały 0 callbacków**.
- `HeldenPlayerController`: `SoulCharacter`, `LastPlayerChar`, `CurrentInteractTarget`, `RespawnCharacter_Server()` (serwerowy), `OnPlayerKilled(InType)`, `OnNewPawn`, `Interact_Server` / akcje interakcji. `GetPawn()` z bazowego Controller.
- `HeldenItemtSlot` — **tak zapisano nazwę w USMAP, z literówką**; pole `CurrentItemInSlot`, `bCanPickUpItemFromSlot`, `SlotComponent`, `RequiredItemTag`.
- `HeldenEquipableItem`: `PreviousOwner`, `CurrentSlot`, `CurrentInventorySlot`, `ItemDataAsset`, `ItemDurability`, `ItemEnchantment`, `DynamicSaveName`, `bCanLeaveDungeon`, `bCanDropObject`.
- `HeldenItemSaveData`: `ItemId`, `OwningPlayer`, `OwningSlot`, `bOnPlayerCharacter`, `Durability`, `Location`, `Rotation`, `SaveFlags`, `Enchantment`.
- `HeldenMoney`: trzy inty **Scraps, Gold, Artifacts**. Waluta nie jest tożsama z tablicami itemów.

## Winda, drzwi, failure actor

- `HeldenDungeonElevator` (parent `HeldenElevator`): `ElevatorMachine`, `HomeStationIdx`, `DungeonStationIdx`, `ItemSlots`, `MainElevatorMesh`, `DoorMeshComponent`. W rodzicu: `CurrentStationIdx`, `TargetStationIdx`, `CurrentElevatorDistance`.
- `HeldenElevatorMachine` (parent `HeldenInteractableObject`): `RemainingCost`, `ReturnCost`, `WarningRequirement`, `WarningPopup`, `ValueWidgetComponent`, `ButtonComponent`, `FuseStates`; natywne metody m.in. `SetCanBeInteracted_Auth`, `OnDungeonRunStateChanged`, `OnRequirementSysUpdate_Auth` z ObjectDump.
- `HeldenInteractableObject`: `bInteractionLocked`, **`bUseInteractRequirement`**, `InteractRequirement`, `InteractComponent`, `ForwardInteractions`, `bSoulInteractable`.
- `BP_ExpeditionFailed_Actor_C`: aktor Blueprint z prawdziwego ObjectDump, `bFailedExpedition`, `Box`, `SM_SM_Door_Lock`, `Cube`, `OnRep_bFailedExpedition`, **`UpdateCollisionSate`** (taką pisownię utrzymano w oryginale). Fizyczna blokada drzwi może pozostawać mimo czystego GameState.

## Zniszczenie, loot, monety

| Typ | Ważne pola |
|---|---|
| `EHeldenConstructQuality` | Common=0, Rare=1, Epic=2, BuiltConstruct=3 |
| `HeldenPhysicsActor` | `OwningDungeon` **WeakObject**, `RootMesh`, `StatsComponent`, `StatsDataName`, `ConstructDataName`, `ConstructQuality`, `bCanSimulatePhysics`, `InitConAsset`, `SetupConstructAsset`, `ResourceDropAmount` |
| `HeldenConstructActor` | parent `HeldenPhysicsActor`; `ConstructAsset`, `DynamicSaveName`; reflected `GetConstructAsset()`/`GetConstructAssetData()` |
| `HeldenPhysTreasure` | parent `HeldenConstructActor`; często aktor Blueprint `BP_DefaultPhysTreasure_C` |
| `HeldenPhysTreasureContainer` | `Meshes`, `DefaultPhysTreasureClass`, `TreasureData` |
| `HeldenPhysActorData` | `DataName`, `Rarity`, `XP`, `Parsed_ScrapReward`, `Parsed_ResoruceDrop` (literówka gry) |
| `HeldenDataSingleton` | `PhysTreasureContainer`, `PhysActorDataTable`, `ConstructAssetDataTable`, `ItemDataTable`, `GoldCoinActorClass`, `ArtifactCoinActorClass`, `DataLootTable` |
| `HeldenPhysicsCoin` | `Money`, `InteractComponent`, `InteractEffect`, `PickUpCoinEffect`; `Interact_Auth(InCharacter)` |
| `HeldenCoinDispenser` | `CoinSpawnLocation`, `MinGoldMergeThreshold`, `MaxGoldPerCoins`, `MaxArtifactsPerCoin`, `PhysImpulseRange` |
| `HeldenScrapAreaObject` | `bIsGrinding`, `bGrinderDisabled`, `ScrappedActors`, `OverlappingActors`, `CoinDispenser`, `OnScrapAreaOverlap` |

## Praktyczne nazwy hooków oraz API UE4SS

Kod v0.5 rejestruje m.in. (przed założeniem, że działają, sprawdź obecny ObjectDump):

```lua
RegisterHook('/Script/Helden.HeldenPhysicsActor:OnHealthModifed', pre, post)
RegisterHook('/Script/Helden.HeldenPhysicsActor:PlayDestructionEffect_Mulitcast', pre, post)
RegisterHook('/Script/Helden.HeldenCharacter:Die_Auth', pre, post)
RegisterHook('/Script/Helden.HeldenCharacter:OnRep_CharacterState', pre, post)
RegisterHook('/Script/Helden.HeldenPlayerController:OnPlayerKilled', pre, post)
RegisterHook('/Script/Helden.HeldenPlayerController:OnNewPawn', pre, post)
RegisterHook('/Script/Helden.HeldenGameState:HasFailedExpedition', pre, post)
RegisterHook('/Script/Helden.HeldenGameState:EndDungeonRunSequence_Multicast', pre, post)
```

`OnHealthModifed` i `PlayDestructionEffect_Mulitcast` zawierają oryginalne literówki; **nie poprawiaj ich pisowni w kodzie**. UE4SS hook argumenty mogą wymagać dereferencji `RemoteUnrealParam` przez `:get()`, podczas gdy `OwningDungeon` to `FWeakObjectPtr` i używa `:Get()`. To **dwie różne rzeczy**. Nie utożsamiaj `pcall(...) == true` z poprawnym wynikiem metody gry.

## Szukanie właściwej definicji

- `python scripts/reassemble.py` — scala dump i kontroluje SHA.
- `python scripts/inspect_schema.py HeldenCharacter` — wyświetla wszystkie pola klasy.
- `python scripts/inspect_schema.py ECharacterState --enum` — sprawdza enum.
- `grep -i "OnHealthModifed" UE4SS-ObjectDump.txt` — konkretna sygnatura obiektu.

**Nie modyfikować GameState ani sejwa tylko dlatego, że konkretne pole istnieje.** Test z prawdziwym serwerem i reloadem zapisu jest konieczny.
