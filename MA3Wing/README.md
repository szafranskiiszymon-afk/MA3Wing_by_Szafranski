# MA3 Wing – fadery i klawiatura grandMA3 na iOS

Aplikacja SwiftUI (iPhone + iPad, poziomo) udająca fizyczną powierzchnię grandMA3:
fadery executorów, przyciski executorów, sekcję master (Go+/Go-/Pause, <<< >>>, Grand Master, B.O.)
oraz sekcję komend (Store, Update, Group, Cue, At, Thru, klawiatura numeryczna, Please, Oops, Clear…).
Komunikacja to **OSC po UDP**, bez zewnętrznych bibliotek (Network.framework).

## Budowanie

Opcja A – XcodeGen (najszybciej):
```bash
brew install xcodegen
cd MA3Wing
xcodegen
open MA3Wing.xcodeproj
```

Opcja B – ręcznie: Xcode → New Project → iOS App (SwiftUI), nazwa `MA3Wing`, usuń wygenerowane
`ContentView.swift` i `*App.swift`, przeciągnij wszystkie pliki z `Sources/`. W Info dodaj
`NSLocalNetworkUsageDescription` (bez tego iOS zablokuje ruch w sieci lokalnej).

Potem w Signing & Capabilities wybierz swój Team i uruchom na urządzeniu.

## Konfiguracja grandMA3 (konsola lub onPC)

1. Menu → In & Out → OSC.
2. Dodaj linię: IP = adres iPhone'a/iPada, Port = 8000 (domyślnie), Prefix = `gma3`.
3. Włącz **Receive**, **Receive Command** oraz globalnie **Enable Input**.
4. (opcjonalnie) Włącz **Send** i ustaw port 9000 – aplikacja odbiera położenie faderów.
5. W aplikacji (⚙︎) wpisz IP konsoli.

## Co wysyła aplikacja

| Element | Wiadomość OSC |
|---|---|
| Fader executora | `/gma3/Page1/Fader201 ,i 0…100` |
| Przycisk executora | `/gma3/Page1/Key201 ,i 1` (wciśnięcie) / `,i 0` (puszczenie) |
| Gałka executora 3xx/4xx | `/gma3/Page1/Fader301 ,i 0…100` (do sprawdzenia na konsoli) |
| Xkeys X1–X8 / X9–X16 | `/gma3/Page1/Key291…298` / `Key191…198` |
| Klawiatura komend | budowana lokalnie linia komend, wysyłana jako `/gma3/cmd ,s "…"` po **Please** |
| Go+/Go-/Pause/<<< >>> | `/gma3/cmd ,s "Go+"` itd. (działają na wybranej sekwencji) |
| Grand Master | `/gma3/cmd ,s "Master 2.1 At 75"` (edytowalne) |
| Highlight/Solo/Blind/Freeze/Preview | wysyłane natychmiast jako komenda |

Clear: czyści lokalną linię, a gdy jest pusta – wysyła `Clear`. Oops: cofa ostatnie słowo, a przy pustej linii wysyła `Oops`.

## Układ (jak w grandMA3)

Kolumna executora od góry: gałka + przycisk 4xx, gałka + przycisk 3xx, fader 2xx z przyciskiem
pod spodem, przycisk 1xx na dole. Kolumny są w blokach po 5. Klawiszom nadano kreski 1–4, tak jak
na konsoli. Na iPhonie w poziomie gałki są ukryte (zostają przyciski), żeby fader był wystarczająco
długi. Widok Klawiatura/Całość: Xkeys X1–X16, <<< >>> Learn, Go- Pause Go+, klawisze funkcyjne,
klawiatura numeryczna i Grand Master z B.O.

W ustawieniach: liczba faderów (np. 10 na iPhonie, 15 na iPadzie), pierwsza kolumna (bank),
rząd faderów (201) oraz rzędy przycisków nad i pod faderami (domyślnie 401,301 i 101).
Dopasuj je do swojego showfile'a / modelu konsoli.

## iPad – widok Całość

Na iPadzie widok „Całość” odwzorowuje grandMA3 onPC command wing XT: executory, Prev/Next/Set/Up/SelFix/Down,
dwa fadery master (Master 1.1 i Grand Master), Pause/Go-/Go+, 5 enkoderów, sekcję komend z Xkeys,
klawiaturę numeryczną i level wheel. Całość jest skalowana do ekranu, proporcje zostają jak na pulpicie.

Enkodery i level wheel wysyłają OSC dopiero po wpisaniu adresu w ustawieniach (w dokumentacji MA3 nie
znalazłem ich adresów – trzeba sprawdzić w In & Out → OSC na onPC). Klawisze MA i Xkeys na razie nic nie wysyłają.

## Pliki

- `OSC.swift` – enkoder/dekoder OSC + klient UDP (wysyłanie i nasłuch)
- `ConsoleState.swift` – stan, ustawienia, logika linii komend, feedback
- `Controls.swift` – przycisk chwilowy, fader z płynnym (względnym) przesuwem
- `Keys.swift` – układ klawiatury komend i kolory
- `Views.swift` – ekran główny, sekcje, ustawienia
- `WingView.swift` – układ command wing XT na iPadzie
