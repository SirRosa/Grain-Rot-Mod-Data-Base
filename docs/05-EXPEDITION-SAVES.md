# Expedition, zapis, ostatnie piętro i zamknięta winda

## Struktury

- `HeldenGameState.GameModeType`: 1 oznacza Expedition.
- `HeldenGameState.CurrentDungeonRun`: `HeldenActiveDungeonRun` z enumem `State` (0 None, 1 ElevatorRideDown, 2 Exploring, 3 EndScreen) i `Flags` (1 Failed).
- `HeldenGameState.bExpeditionFailed` i `HeldenSaveGame.MetaData.bHasFailed` są oddzielnymi flagami.
- `HeldenSaveGame.DungeonLevel` jest zapisaną głębokością. Nie myl `CurrentSeed.Level`, `DungeonLevel` ani `CurrentElevatorDistance` — różne jednostki i etapy.
- `HeldenGameInstance.CurrentSaveGame` może być wymieniony w trakcie przejść; w poprzednich wersjach reset struktury moda powodował utratę informacji o bieżącym runie. Dlatego w v0.3+ dla tego samego slotu zachowywano stan/oczekujące respawny.
- `HeldenDungeonElevator` zna `HomeStationIdx`, `DungeonStationIdx`, `ElevatorMachine`, `InteriorCollisionBox` (z rodzica) i własne stany stacji.

## Fakty z v0.3

Gra prawidłowo wykonała `EndDungeonRunSequence_Multicast` z porażką. Stan z `Exploring=2` przeszedł do `EndScreen=3`, potem `None=0`. Mod wyzerował flagi `bExpeditionFailed`, `bHasFailed`, resetował `CurrentDungeonRun.Flags` i próbował 
`HeldenElevatorMachine:SetCanBeInteracted_Auth(true)`. Log twierdził `machine=unlocked`, lecz **gracz widział nadal „Expedition Failed” i nie mógł użyć windy**.

**Przyczyna częściowa:** w świecie istnieje Blueprint aktor **`BP_ExpeditionFailed_Actor_C`** ze swoją zmienną `bFailedExpedition` i fizycznym blokowaniem przejścia (`Box`, `SM_SM_Door_Lock`, `Cube`). Reset GameState nie zerował jego kolizji. W v0.4 dodano `UpdateCollisionSate` (pisownia oryginalna), `OnRep_bFailedExpedition`, `SetActorEnableCollision(false)`, `Box:SetCollisionEnabled(0)` oraz ukrycie zamka. Także maszyna ma `bUseInteractRequirement` obok `bInteractionLocked`.

**Ograniczenie:** użytkownik **nie testował pełnego wipe po v0.4**, ponieważ miał już respawn do windy. Nie ma więc potwierdzenia, że reset tego Blueprint zapewnia rzeczywisty ponowny zjazd w full failed state. Nie dopisuj do handoffu „windę naprawiono na pewno”.

## Jak odróżnić dwie blokady

1. Stan logiczny: `CurrentDungeonRun.State`, `Flags`, `bHasFailed`, `bExpeditionFailed`, `HeldenElevatorMachine` i `CanBeInteracted`.
2. Stan fizyczny: `BP_ExpeditionFailed_Actor_C`, jego `bFailedExpedition` i collision komponentów.
3. Stan animacji/przejazdu: `CurrentStationIdx`, `TargetStationIdx`, `HomeStationIdx`, `DungeonStationIdx`; brak odblokowania interakcji nie oznacza, że winda ma poprawny target głębokości.
4. Save slots: `GameSlot`, `MetaData.bHasFailed` i `DungeonLevel`, odczyt aktualnego obiektu `CurrentSaveGame` po zmianach sceny.

## Zasady bezpiecznej modyfikacji

- Przed modyfikacją trwałego zapisu: **kopia save** oraz log `slot`, `DungeonLevel`, `GameMode`, `CurrentDungeonRun.State`, `Flags`.
- Operacje wykonuj **tylko w Expedition i na hoście**. Nie dotykaj normalnego trybu. Obsłuż stan `EndScreen` oraz brak wcześniejszej próbki `Exploring`.
- Jeśli silnik nie pozwala ustawić UStruct przez `get(...).State=0`, zapisz strukturę na właścicielu i ponownie odczytaj — UStruct może być kopią. `OnRep` to dodatkowy callback, **nie gwarancja replikacji**.
- Nie wywołuj zjazdu na siłę, gdy winda fizycznie nie wróciła na HomeStation. Mogłoby to przenieść graczy do niepoprawnego świata.
- Po „unlocked” sprawdzaj prawdziwe wejście, otwarcie drzwi, aktywację przycisku, pozycję i trwałość stanu po ponownym wczytaniu. Jedno powodzenie `pcall` niczego nie potwierdza.

## Test do wykonania w przyszłości

1. Skopiować save, rozpocząć Expedition, zejść na znane piętro (np. 10).
2. Wyłączyć konkurencyjny Depth Keeper, pozostawić tylko testowy mod i kontrolowaną konfigurację QOL.
3. Wykonać pełny wipe w kontrolowanej sesji (jeśli mod zawsze respawnuje, potrzebne osobne testowe ustawienie wyłączające respawn, a nie destrukcyjna ingerencja w produkcyjny save).
4. Sprawdzić log `END RUN`, `RECOVERY`, `FAILURE DOOR`, `machine` oraz UI; zobaczyć czy można użyć maszyny i czy winda zjeżdża na zapisane piętro.
5. Wyjść i ponownie wczytać save, sprawdzić brak permanentnego `Expedition Failed`, brak resetu głębokości i brak nieoczekiwanych duplikacji.

W v0.5 istnieje logika naprawy, ale bez realnego testu full wipe nie podawaj jej jako potwierdzonej.
