# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier festgehalten.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
die Versionierung an [Semantic Versioning](https://semver.org/lang/de/).

## [Unveröffentlicht]

## [1.0.0] — 2026-09-01

Erste öffentliche Version.

### Enthalten

- `auth` — API-Token im macOS-Keychain ablegen (`set-token`, interaktiv oder über
  stdin), Authentifizierung prüfen (`check`), Vorhandensein abfragen ohne den Token
  auszugeben (`status`) und ihn wieder entfernen (`delete`).
- `projects list` und `tasks list` zum Nachschlagen von Projekten und Aufgaben.
- `entries list`, `entries add` und `entries delete` für Zeiteinträge. `add` löst
  vor dem Schreiben Kunde, Projekt und Aufgabe auf und fragt nach; `--force`
  überspringt die Rückfrage für Skripte.
- `timer start`, `status`, `stop` und `cancel` für einen lokalen Timer, der beim
  Stoppen zu einem Zeiteintrag wird.
- `config show` und `config set` für die Benutzerkonfiguration.
- Projektkonfiguration über eine `.pkram`-Datei, die vom aktuellen Verzeichnis bis
  zur umschließenden Git-Wurzel gesucht wird.
- Benannte Aufgaben: unter `tasks` hinterlegte Namen sind überall dort verwendbar,
  wo eine Aufgabe erwartet wird, also `--task tickets` statt `--task 4`.
- Manpage `pkram(1)`, installiert von `make man` und `make install`.
- `PapierkramCore` als eigenständige Bibliothek, damit später eine Menubar-App
  dieselbe Logik verwenden kann.

### Sicherheit

- Der API-Token liegt ausschließlich im macOS-Keychain (Service
  `papierkram-api-key`, Account gleich Subdomain, Zugriffsklasse
  `kSecAttrAccessibleAfterFirstUnlock`) und wird von `pkram` nie auf Platte
  geschrieben.
- Die interaktive Token-Eingabe schaltet das Terminal-Echo ab und schreibt den
  Prompt auf stderr, damit der Token weder sichtbar wird noch in eine Pipe gerät.
- Es gibt keine eingebaute Standard-Subdomain. Ohne konfigurierte Subdomain bricht
  `pkram` mit einer Meldung ab, statt gegen ein fremdes Konto zu sprechen.

### Bekannte Einschränkungen

- Nur macOS, weil die Token-Ablage auf dem System-Keychain aufsetzt.
- `entries list` übernimmt `task_id` bewusst **nicht** aus `.pkram`. Eine auf eine
  einzelne Aufgabe verengte Liste ist von „an dem Tag wurde nichts gebucht" nicht zu
  unterscheiden. Der Projektfilter wird übernommen und meldet sich auf stderr.

[Unveröffentlicht]: https://github.com/mickeyl/pkram/compare/1.0.0...HEAD
[1.0.0]: https://github.com/mickeyl/pkram/releases/tag/1.0.0
