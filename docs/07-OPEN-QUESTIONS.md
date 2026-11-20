# Status wiedzy, rzeczy niepotwierdzone i plan badań

## Macierz potwierdzenia

| Element | DUMP / kod | Log silnika | Gracz | Wniosek |
|---|---|---|---|---|
| UE4SS v3 i generator USMAP F8/F9 | Tak | Tak | Tak | **Potwierdzony** |
| `Helden`/UE5.7.4 według nazwy mapowania | Tak | Tak | — | **Potwierdzony build dumpu**, nie aktualność gry w przyszłości |
| Expedition `GameModeType=1` | Tak | Tak | Tak | **Potwierdzony w testowanej sesji** |
| `RegisterHook` dla śmierci | Tak | `HOOK ACTIVE`, lecz brak callbacków v0.3 | Śmierć bez respawnu | **Nie wystarczy** |
| Polling `CharacterState/HP/Soul` | Tak | Działał w v0.4 | Respawn w windzie zadziałał | **Potwierdzony scenariusz v0.4** |
| Utrzymanie całego wyposażenia | Kod v0.5, 45 mock testów | Brak logu v0.5 | „na tym etapie sukces”, bez listy szczegółów | **Częściowo potwierdzone, niezweryfikowane ilości/sloty** |
| Utrzymanie Gold/Artifacts/Scraps po śmierci | v0.5 snapshot Money | Brak logu v0.5 | Bez szczegółów | **Wymaga testu i antyduplikacji** |
| Fizyczne Gold za meble | Tak | Log v0.4 pokazał spawn Gold x9,15,45 | Gracz widział monety, ale wisiały | **Działał spawn; fizyka v0.5 niepotwierdzona oddzielnie** |
| Gold + Artifact Coins za premium loot | Kod v0.5 + mesh→table | v0.4 brak | v0.4 nie działało; v0.5 ogólny sukces | **Potrzebny test 1:1 extraction** |
| Zgodność wartości z QOL | Runtime DataTable, QOL log | Zmiany QOL potwierdzone | Wątpliwości co do ilości | **Tabele czytane, prawidłowe wartości 1:1 niepotwierdzone** |
| Status Expedition Failed / ponowny zjazd | Kod naprawy aktywnego aktora | v0.3 reset flag nie otwierał windy | Brak testu wipe po v0.4 | **NIE POTWIERDZONE** |
| Multiplayer drugi klient | Autorytet hosta w kodzie | Brak logu z 2 klientów | Brak raportu szczegółowego | **Niezweryfikowane** |
| Trwałość po reloadzie | Save API odbite w USMAP | Brak porównania po reloadzie | Brak | **Niezweryfikowane** |

## Zagrożenia kolejnych zmian

1. **Wielokrotne snapshoty i duplikaty itemów.** Dwa przedmioty tej samej klasy mogą mieć różne identyfikatory, stan enchant/durability i miejsca w slotach. Sama `classPath` nie gwarantuje rozróżnienia. Natychmiastowy pickup może pojawić się po kilku tickach, zanim native updater zakończy replikację.
2. **Dublowanie waluty.** Zwrócenie minimum sprzed śmierci może pozostawić w świecie oryginalne fizyczne death drops; późniejsze podniesienie obu monet daje więcej niż przed śmiercią. Potrzebne porównanie: saldo przed śmiercią, po native death, po respawn, po powrocie na miejsce i po reloadzie.
3. **Powrót do windy nie oznacza zachowania rzeczywistej głębokości.** Test: zjazd po pełnym wipe, faktyczne piętro, interakcja, generator seeda, stan save po wyjściu/ponownym uruchomieniu gry.
4. **Wartościowe treasure**: match `RootMesh.StaticMesh` może być niejednoznaczny; `TreasureData` może nadawać różny reward w zależności od poziomu/quality lub native extraction calculation. Samo DataTable `Parsed_ScrapReward` to hipoteza równoważności. Potrzeba testu dokładnej jednostki Gold/Artifacts między zniszczeniem i extraction na identycznym typie przedmiotu.
5. **Fizyka i replikacja monet**: czy `RootMesh:SetSimulatePhysics(true)` poprawnie działa z jej native body setup, czy moneta ma prawidłowy collision channel i `Interact_Auth`, czy drugi klient ją widzi, czy nie wpada pod ziemię? Wymaga gry.
6. **UE4SS v3 vs v4 dokumentacja**: składnia hooków, parametry instancji i `RegisterHook` pre/post muszą być zgodne z runtime, nie latest docs bez porównania.
7. **Konflikty modów**: QOL `InsuranceOnWipe`, DepthKeeper i ExpeditionSaver jednocześnie modyfikują bardzo zbliżone stany. Na początku testuj sam jeden mod; dokładanie QOL po teście bazowym.
8. **Save serializacja**: `HeldenSaveGame` może zachować trwałe `bHasFailed` przed wyczyszczeniem. Test atomowy: death→quit/reload, odczyt SaveGame i meta.

## Najważniejsze kolejne testy

- Niski poziom ryzyka: zwykły przedmiot i premium treasure tego samego typu przed/po extraction; monetę podnieść, zmierzyć dokładny balans, zweryfikować grawitację.
- Średni: postać z 2 identycznymi itemami, jednym enchanted, innym damaged, i zapisaną walutą. Test śmierci + reload.
- Wysoki: pełne wipe oraz respawn całej drużyny, zamknięcie/otwarcie windy, głębokość, load na dedykowanym serwerze i listen host.

**Nie zakładaj, że nowa gra ma identyczny build jak zrzut 2026-11-20**. Wygeneruj nowe mappingi po aktualizacji i porównaj statystyki; pliki o identycznej nazwie mogą różnić się skanowaną listą obiektów.
