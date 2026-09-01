<p align="center">
  <img src="Assets/pkram-logo.png" alt="" width="160">
</p>

<h1 align="center">pkram</h1>

<p align="center">
  Arbeitszeiten in Papierkram erfassen, ohne die Weboberfläche zu öffnen.
</p>

<p align="center">
  <a href="https://github.com/mickeyl/pkram/actions/workflows/ci.yml"><img src="https://github.com/mickeyl/pkram/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"></a>
</p>

`pkram` erfasst Arbeitszeiten in Papierkram ohne Weboberfläche: Projekte, Aufgaben, Zeiteinträge und ein lokaler Timer, alles von der Kommandozeile. Die Logik steckt in einer eigenständigen Bibliothek `PapierkramCore`, damit später eine leichtgewichtige macOS-Menubar-App dieselbe Basis nutzen kann.

> **Inoffizielles Drittanbieter-Werkzeug.** Dieses Projekt steht in keiner Verbindung
> zu den Machern von Papierkram, wird von ihnen weder betrieben noch unterstützt.
> „Papierkram" ist die Marke ihres Anbieters und wird hier nur benutzt, um zu
> beschreiben, womit das Werkzeug spricht.
>
> `pkram` schreibt echte Zeiteinträge in dein Papierkram-Konto. Für die Richtigkeit
> deiner Zeiterfassung bist du selbst verantwortlich — prüfe, was du buchst. Die
> Software kommt ohne Gewährleistung, siehe [LICENSE](LICENSE).

Der Fokus liegt auf einem schnellen Alltagsfluss:

- im Projektordner stehen und `.pkram`-Metadaten nutzen
- Zeit mit einem kurzen Befehl erfassen
- vor dem Schreiben eine klare Zusammenfassung sehen
- mit Return bestätigen oder mit beliebigem Text abbrechen
- für Skripte bewusst `--force` verwenden

## Installation

Voraussetzungen:

- macOS
- Swift 6 / Xcode Command Line Tools
- Papierkram-API-Key

Bauen und testen:

```sh
make build
make test
```

Installieren:

```sh
make install
```

Das installiert `pkram` nach `~/.local/bin/pkram` und legt `pk` als kurzen Symlink-Alias an.

## Authentifizierung

`pkram` liest den Papierkram-API-Key aus dem macOS-Keychain. Standardwerte:

- Keychain-Service: `papierkram-api-key`
- Keychain-Account: die konfigurierte Subdomain

Es gibt bewusst **keine eingebaute Standard-Subdomain**. Ohne konfigurierte
Subdomain bricht `pkram` mit einer Meldung ab, statt gegen ein fremdes Konto
zu sprechen.

Token interaktiv speichern:

```sh
pk auth set-token
```

Token aus stdin speichern:

```sh
op read 'op://Private/Papierkram/token' | pk auth set-token --stdin
```

Authentifizierung prüfen:

```sh
pk auth check
```

Prüfen, *ob* ein Token hinterlegt ist, ohne ihn auszugeben:

```sh
pk auth status
```

Token wieder entfernen:

```sh
pk auth delete
```

## Schnellstart

Alle Projekte anzeigen:

```sh
pk projects list --all
```

Projektaufgaben anzeigen:

```sh
pk tasks list --project 2
```

Heutige Einträge anzeigen:

```sh
pk entries list --from today --to today
```

Vier Stunden buchen:

```sh
pk entries add --start 09:00 --end 13:00 --comment "Release vorbereitet"
```

Vor dem Schreiben löst `pkram` Kunde, Projekt und Aufgabe auf und fragt zusammenfassend nach:

```text
Create time entry: Kunde Mystic GmbH, Projekt Mystic App, Aufgabe Wartung, am 2026-07-11 von 09:00 bis 13:00 = 4 h für "Release vorbereitet".
Press Return to create this entry, or type anything else to cancel:
```

In interaktiven Terminals werden die Metadaten farbig hervorgehoben. Mit `NO_COLOR=1` lassen sich ANSI-Farben deaktivieren.

Für Skripte oder nicht-interaktive Aufrufe:

```sh
pk entries add --start 09:00 --end 13:00 --comment "..." --force
```

## Projektkonfiguration

`pkram` liest optional eine `.pkram`-Datei im aktuellen Projektordner. Beispiel:

```json
{
  "subdomain": "your-subdomain",
  "company_id": 1,
  "project_id": 2,
  "task_id": 3,
  "tasks": {
    "tickets": 4,
    "maintenance": 3
  },
  "user_id": 1
}
```

Damit können Befehle kurz bleiben:

```sh
pk tasks list
pk entries list --from today --to today
pk entries add --start 09:00 --end 10:30 --comment "Feature umgesetzt"
pk timer start --comment "Menubar-App"
```

### Benannte Aufgaben

`task_id` bleibt der Default für `entries add` und `timer start`. Wer regelmäßig auf
mehrere Aufgaben desselben Projekts bucht, hinterlegt sie unter `tasks` und spricht sie
per Name an, statt IDs nachzuschlagen:

```sh
pk entries add -t tickets --start 09:00 --end 10:30 --comment "Ticket 123 umgesetzt"
pk entries list -t tickets --from 2026-08-01 --to 2026-08-31
pk timer start -t maintenance
```

`--task` nimmt weiterhin auch eine numerische ID. Ein unbekannter Name bricht mit einer
Fehlermeldung ab, die die hinterlegten Namen auflistet.

`entries list` übernimmt `task_id` bewusst **nicht** als Default: eine auf eine einzelne
Aufgabe verengte Liste ist von "an dem Tag wurde nichts gebucht" nicht zu unterscheiden.
Der Projektfilter wird weiterhin übernommen, meldet sich aber auf stderr.

Suchlogik für `.pkram`:

- zuerst wird nur das aktuelle Verzeichnis geprüft
- wenn der aktuelle Pfad innerhalb eines Git-Repositories liegt, wird nur wenige Ebenen bis zum nächsten `.git`-Root hochgesucht
- es wird nicht weiter Richtung Home-Verzeichnis oder Dateisystemwurzel gesucht

Präzedenz:

```text
CLI-Flag > PAPIERKRAM_* Environment > .pkram > User-Config > eingebauter Default
```

User-Config anzeigen:

```sh
pk config show
```

Subdomain setzen:

```sh
pk config set subdomain your-subdomain
```

## Timer

Lokalen Timer starten:

```sh
pk timer start --comment "Wartung"
```

Status anzeigen:

```sh
pk timer status
```

Timer stoppen und Eintrag erzeugen:

```sh
pk timer stop
```

Timer ohne Schreiben abbrechen:

```sh
pk timer cancel
```

## Wichtige Make-Targets

```sh
make help
make build
make test
make install
make man
make smoke
```

## Entwicklung

Für Schreibtests empfiehlt sich ein eigener Wegwerf-Kunde mit eigenem Projekt und
eigener Aufgabe im Papierkram-Backend, damit nie in echte Mandantendaten geschrieben
wird. Die entsprechenden Make-Targets erwarten die IDs aus der Umgebung und brechen
ohne sie ab, statt einen Default zu raten:

```sh
TEST_PROJECT_ID=2 TEST_TASK_ID=3 make list-test-data
TEST_TASK_ID=3 make entries-today
TEST_TASK_ID=3 make timer-example
```

Manueller Schreibtest:

```sh
pk entries add --task 3 --date today --start 12:00 --end 12:01 --comment "smoke test" --unbillable
pk entries delete <created-id> --force
```

`make smoke` führt nur nicht-destruktive Prüfungen aus (Tests plus Auth-Check). Ein
echter Schreibtest bleibt absichtlich manuell, weil er einen realen Zeiteintrag erzeugt.

## Manpage

```sh
make man
man pkram
```

`make install` installiert die Manpage automatisch mit.

## Mitwirken

Fehlerberichte und Vorschläge: https://github.com/mickeyl/pkram/issues

## Änderungen

Siehe [CHANGELOG.md](CHANGELOG.md).

## Lizenz

MIT. Siehe [LICENSE](LICENSE).
