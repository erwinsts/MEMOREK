# MEMOREK

Darmowy program dla Windows do rozmowy z agentem Codex i przechowywania historii lokalnie.
Autor: rWin.

## Pobierz gotowy program

Otwórz [wydania MEMORKA](https://github.com/erwinsts/MEMOREK/releases) i pobierz załącznik
**MEMOREK-klient-0.5.74.zip**. Rozpakuj cały ZIP do zapisywalnego folderu i uruchom `MEMOREK.exe`.

Paczka wydania zawiera wymagany backend Codexa. Kompilator nie jest potrzebny.
Zaloguj się w programie na własne konto i wybierz dostępny model.
Do rozmowy potrzebny jest internet oraz dostęp do usług dostawcy modeli.
Darmowy program nie oznacza darmowego dostępu do usług AI.

## Ważne pliki

- `native-data` powstaje przy uruchomieniu i zawiera prywatną historię, ustawienia oraz profil logowania.
- `workspace` jest folderem roboczym agenta.
- `tools/codex` zawiera backend; jest dostarczany w załączniku ZIP w sekcji Releases.
- Informacje licencyjne składników zewnętrznych znajdują się w `licenses` w paczce.

Zachowaj kopię danych przed aktualizacją. Nie publikuj używanego katalogu `native-data`.
Domyślnie pracuj w trybie tylko do odczytu. Dostęp do systemu umożliwia agentowi wykonywanie działań na Twoim komputerze.

## Wersja 0.5.74

Usunięto ikonę banknotu i kwotę kosztu przy odpowiedziach.
Zachowano zbiorczy szacunkowy licznik kosztów na górnym pasku.

To repozytorium dystrybucyjne. Pliki w katalogu wersji nie są kompletną instalacją bez backendu.
Do uruchomienia pobierz załącznik wydania, zamiast automatycznego archiwum „Source code”.
