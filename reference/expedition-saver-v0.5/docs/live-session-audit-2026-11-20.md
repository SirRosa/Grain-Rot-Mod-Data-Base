# Audyt rzeczywistej sesji UE4SS — 20 listopada 2026, v0.3

Źródło: plik `UE4SS(2).log` przesłany przez użytkownika po nieudanym teście. Nie publikowano pełnego logu ani prywatnych ścieżek użytkownika. Dane poniżej to logi **faktycznie uruchomionej gry**, a nie symulacji.

## Fakty z logu

- Gra załadowała `ExpeditionSaver v0.3.0-alpha`, host był autorytatywny: `host=true`, `GameModeType=1`.
- UE4SS zarejestrował wszystkie deklarowane hooki; `HOOK ACTIVE` oznacza jedynie rejestrację, nie wywołanie callbacku.
- Przed końcem ekspedycji: `rawDeaths=0`, `deaths=0`. Ani `Die_Auth`, ani Blueprint `OnPlayerKilled` nie zostały wywołane w badanej ścieżce śmierci gracza.
- `rawDestructions=369`, `destructionEvents=34`: hooki niszczenia były wywoływane. Wiele obiektów zostało odrzuconych przez warunki nagród, część z `no coin payout`.
- Za `Radiator_01_C` mod zakolejkował `gold=39` i zalogował `DROP gold=39`. To dowód powodzenia wywołania `SpawnActor` i odczytu `Money`, **nie** dowód widoczności monety, replikacji ani możliwości podniesienia. Użytkownik nie widział monet.
- Gra wywołała `EndDungeonRunSequence_Multicast` z porażką, po czym stan runu przeszedł z `2` do `3`, następnie do `0`.
- Mod wyzerował `bExpeditionFailed` i `MetaData.bHasFailed`, a jego log zgłaszał `machine=unlocked`. Mimo tego drzwi nie otworzyły się w grze.
- Zrzut obiektów zawiera osobny **`BP_ExpeditionFailed_Actor_C`** z `bFailedExpedition`, `Box`, `SM_SM_Door_Lock`, `OnRep_bFailedExpedition`, `UpdateCollisionSate`. Ten fizyczny aktor nie był obsługiwany przez v0.3.
- W tej samej sesji były uruchomione również **`GrainRotDepthKeeper v0.3.0` oraz `GrainRotQOL v0.1.0-preview`**. QOL zaraportował `insurance delivery: 1 recorded, 1 spawned`. Jego tabele monet i XP były rzeczywiście modyfikowane przed grą.
- Jednorazowy błąd: `main.lua:797: bad argument #1 to 'tostring' (value expected)`. Przyczyną był `enum()` zwracający 0 wartości zamiast jawnego `nil` dla nierozpoznanych wartości przy początkowym ładowaniu.

## Zmiany v0.4

1. Nie polegamy tylko na niewywołanych hookach śmierci. Co 300 ms odczytujemy `HeldenPlayerController:GetPawn()`, `LastPlayerChar`, `SoulCharacter`, `HeldenCharacter.CharacterState` (`ECharacterState.Dead = 1`) i `CharacterStats.CurrentHealth`. Zachowujemy migawkę sprzętu **przed śmiercią**. Natywny serwerowy respawn pozostaje pierwszą próbą; po 3 nieudanych próbach awaryjnie próbujemy ożywić i ponownie przejąć **ten sam** istniejący aktor gracza. Ta ścieżka jest eksperymentalna i musi być sprawdzona na zapasowym sejwie.
2. W porażce poza resetem flag i maszyny wyłączamy `bFailedExpedition` oraz fizyczną kolizję aktora `BP_ExpeditionFailed_Actor_C`. Komponenty `Box` / `SM_SM_Door_Lock` / `Cube` są bezkolizyjne i ukryte. Nie niszczymy aktora.
3. Monety fizyczne powstają ~130 jednostek nad pivotem zniszczonego obiektu; kod próbuje ustawić replikację, widoczność i kolizję, a następnie loguje klasę, faktyczną lokalizację i statusy. Zwrócone przez `GetInspectData` zero nie przesłania już ewentualnej **niezerowej nagrody DataTable** po modyfikacjach QOL.
4. `enum()` zawsze zwraca jawne `nil` w przypadku nieznanej wartości, zamiast zgłaszać błąd `tostring()`.
5. Wstrzymano automatyczne klonowanie zniszczonych przedmiotów (`RestoreDestroyedItems=false`) do czasu zweryfikowania współpracy z QOL insurance i natywnym respawnem.

## Ważne ograniczenia

- Zrzut USMAP potwierdza typy oraz nazwy funkcji, ale **nie gwarantuje**, że po zakończeniu ekspedycji istniejący martwy aktor postaci nadal żyje w pamięci i pozwoli się przejąć.
- Zmiana `bFailedExpedition` i wyłączenie kolizji mogą otworzyć fizyczne drzwi, ale gra może mieć dodatkowe warunki rozpoczęcia nowego przejazdu, których jeszcze nie znamy.
- `SpawnActor` monety bez błędu nie oznacza, że moneta jest widoczna dla wszystkich graczy i zapisuje się poprawnie. Dlatego logujemy rzeczywisty stan aktora.
- Testy GitHub Actions nadal korzystają z symulacji, a nie Grain Rot UE5 ani multiplayer. Nie przedstawiać powodzenia CI jako dowodu rozwiązania zgłoszonych objawów.
