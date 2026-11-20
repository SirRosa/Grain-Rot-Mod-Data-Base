# Analiza mapowań Grain Rot — 2026-11-20

## Materiał źródłowy

Otrzymano zrzut z uruchomionej gry:
- `Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap` (2 223 017 bajtów, SHA-256: `c3f70cd4f7c9189d9b1581648ade1b18cce2bbf5f8cf5cf31ccb6ad1ccd598af`).
- `UE4SS_ObjectDump.txt` — pełna lista refleksji z uruchomionego procesu gry (182 447 linii).
- `UE4SS(1).log` — 2026-11-20 13:40:04: `Mappings Generation Completed Successfully!`, `Output file: Helden-5.7.4-51494982+++UE5+Release-5.7-1c1a1497.usmap`; dump obiektów również zakończony sukcesem.

UE4SS nazywa plik USMAP na podstawie informacji o buildzie. Nie tworzy pliku dosłownie nazwanego `Mappings.usmap`. Pierwsza wersja mappera błędnie sugerowała taką nazwę.

## Porównanie ze starszym plikiem

| | Poprzedni USMAP | Nowy USMAP |
|---|---:|---:|
| Rozmiar | 2 172 010 B | 2 223 017 B |
| Odczytane definicje UStruct | 10 867 | 11 094 |
| Odczytane enumy | 2 165 | 2 207 |

Nowy plik ma **227 dodatkowych unikalnych nazw struktur** i **42 dodatkowe enumy**, bez usunięcia istniejących definicji. Informacje o buildzie w nazwach są jednak identyczne: to **nie dowodzi**, że tytuł/wersja gry zmieniła się między zrzutami. Różnice mogą wynikać z zestawu załadowanych obiektów.

## Kluczowe pola i funkcje potrzebne do Expedition Saver

**Identyfikacja trybu:**
- `EHeldenGameMode.Default = 0`, `Expedition = 1`.
- `HeldenSaveGame.GameMode` oraz `HeldenSaveGame.GameState`.
- `HeldenGameState.GameModeType`, `bExpeditionFailed` oraz `HasFailedExpedition()`.
- `HeldenSaveGame.MetaData.bHasFailed` i `HeldenSaveGame.MetaData.GameMode`.
- `HeldenGameInstance.ExpeditionLevel` (Nazwa mapy).
- `HeldenSaveGame.CurrentLevel` i `DungeonLevel`.

**Śmierć i odrodzenie:**
- `HeldenCharacter.Die_Auth(InInstigator, InDeathType)`.
- `HeldenPlayerController.RespawnCharacter_Server()` (bez parametrów w zrzucie refleksji).
- `HeldenPlayerController.ResetPlayerLocation()` oraz `OnPlayerKilled(InType)`.
- `HeldenCharacter.EquipedItems`, `ItemSlots`; `HeldenSaveGame.ItemSaveData` i `CharacterSaveData`.
- `HeldenItemSaveData`: `ItemId`, `OwningPlayer`, `OwningSlot`, `bOnPlayerCharacter`, `Durability`, `Location`, `Rotation`, `SaveFlags`, `Enchantment`.
- `HeldenDungeonElevator.ItemSlots` — położenie bezpiecznego respawnu należy ustalić na podstawie aktora windy w grze.

**Zachowanie ekspedycji:**
- `HeldenGameState.CurrentDungeonRun.State` i `Flags`; `EHeldenDungeonRunFlags.Failed = 1`.
- `HeldenGameState.EndDungeonRunSequence_Multicast(InStats)`; `HeldenDungeonRunStats.bHaveFailed`, `DungeonLevel`.
- `HeldenSaveGame.MetaData.bHasFailed` może odpowiadać za trwałe oznaczenie porażki. Nie wolno jej zmieniać bez testu skutków ubocznych w serializacji.

**Fizyczne Artifact Coins:**
- `HeldenDataSingleton.ArtifactCoinActorClass`.
- `HeldenPhysicsCoin.Money` -> `HeldenMoney.Artifacts` (liczba żetonów), plus `Gold`, `Scraps`.
- `HeldenPhysicsCoin.Interact_Auth(InCharacter)` — natywne podnoszenie monety na hoście.
- `HeldenCoinDispenser.MaxArtifactsPerCoin`, `CoinSpawnLocation`.
- `HeldenScrapAreaObject` i istniejące zdarzenia grindera.

## Bezpieczeństwo i ograniczenia

Te informacje to **nazwy pól i sygnatury API**, a nie zweryfikowany cykl działania silnika. Zrzut nie określa, kiedy gra wywołuje `RespawnCharacter_Server`, czy może to zrobić w stanie `EndScreen`, ani jak silnik zapisuje zakończoną porażką ekspedycję.

Dalsze prace powinny rozpocząć się od **read-only logowania zdarzeń** dla tylko trybu Expedition na hoście; następnie dodawanie zmian w śmierci, zapisie i konwersji loot→żetony pojedynczo. Nie wolno niszczyć fioletowego lootu, zanim fizyczne monety zostaną poprawnie zespawnowane i zainicjalizowane w autorytatywnym świecie. Nie wolno dodawać złota/żetonów bez potwierdzenia, że natywna gra nie zrobiła tego już za ten sam przedmiot.

## Prywatność

Dokument zawiera jedynie nazwy odczytanych klas i statystyki mapowania. Pełnych zrzutów użytkownika i logów nie dodawano do publicznego repozytorium.
