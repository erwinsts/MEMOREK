# Aktualizacje z GitHub Releases (od MEMOREK 0.5.80)

Program sprawdza https://api.github.com/repos/erwinsts/MEMOREK/releases/latest przy uruchomieniu i co godzinę. Nie wysyła rozmów ani logowania do GitHuba. Brak połączenia jest obsługiwany w tle; ponowna próba nastąpi po godzinie.

## Przygotowanie wydania dla użytkowników

1. Ustaw nową wersję w version.hpp i release_notes.json.
2. Zbuduj program i paczkę przez build.ps1 oraz package_client.ps1. Zachowaj dołączony package-manifest.json.
3. Spakuj cały folder MEMOREK do **MEMOREK-klient-X.Y.Z.zip**.
4. Na GitHubie utwórz publiczne wydanie z tagiem **vX.Y.Z**. Dodaj ZIP jako załącznik wydania (Assets), a nie plik w repozytorium. Opublikuj zwykłe wydanie, bez Draft i Pre-release.
5. GitHub wylicza SHA-256 załącznika i udostępnia ją jako `digest` w API. Memorek wymaga tej sumy oraz kompletnej paczki; nie oferuje niepełnego wydania.

Przykład: tag v0.5.81, załącznik MEMOREK-klient-0.5.81.zip. Numer w kodzie, tagu i nazwie ZIP-a musi być ten sam. Po publikacji nie podmieniaj pliku tej samej wersji — opublikuj wyższy numer.

ZIP musi zawierać MEMOREK.exe, narzędzia Codex, skrypty aktualizatora (w tym update_remote.ps1), licencje i package-manifest.json. Nie dołączaj native-data ani workspace.

## Działanie u użytkownika

Po znalezieniu nowszej wersji pojawia się przycisk Aktualizuj. Kliknięcie otwiera pobieranie i instalację. Do tego momentu pobierane są tylko metadane wydania. Okno pozostaje responsywne podczas pobierania; można anulować przed zamknięciem Memorka.

Przed podmianą sprawdzane są suma ZIP-a, zawartość i sumy plików. Aktualizator czeka na zapis rozmowy i zamknięcie programu, robi kopię plików, aktualizuje program i uruchamia go ponownie. Dane użytkownika nie są nadpisywane. Błąd podmiany lub uruchomienia powoduje próbę przywrócenia poprzednich plików. Kopie i pobrane pliki są zachowane w build.

Pierwszą paczkę 0.5.80 trzeba dostarczyć osobom używającym starszych wersji ręcznie. Nadal działa lokalny mechanizm build/update.json dla wersji deweloperskiej.

API GitHuba i pole digest: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
