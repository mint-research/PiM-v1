# PiM-Manager

## Übersicht
PiM-Manager ist ein modulares PowerShell-basiertes Management-Tool, das auf den Grundprinzipien von Einfachheit, Stabilität und Modularität basiert. Das Tool ist so konzipiert, dass es leicht erweiterbar ist und konsistente Benutzererfahrungen über alle Funktionen hinweg bietet.

## Grundprinzipien
- **Einfachheit**: Wähle immer die einfachste Lösung.
- **Stabilität**: Stabilität ist oberstes Gebot.
- **Modularität**: Jede Funktion wird, soweit sinnvoll, in ein eigenes Script ausgelagert.
- **Proaktives Feedback**: Das System weist auf Potenziale und Probleme hin, auch wenn nicht explizit erfragt.

## Projektstruktur

```
PiM-Manager/
│
├── PiM-Manager.ps1             # Hauptscript mit Menüstruktur
├── config/                     # Konfigurationsdateien
│   ├── settings.json           # Allgemeine Einstellungen
│   └── defaults.json           # Standardwerte
│
├── logs/                       # Logdateien
│   ├── system/                 # Systemlogs
│   └── user/                   # Nutzerspezifische Logs
│
├── modules/                    # PowerShell-Module
│   ├── UX/                     # UI-Komponenten
│   │   ├── Menu.psm1           # Menüfunktionen
│   │   ├── Themes.psm1         # Farbschemata und Darstellung
│   │   └── Messages.psm1       # Standardisierte Nachrichten
│   │
│   ├── Core/                   # Kernfunktionalitäten
│   │   ├── Session.psm1        # Sessionmanagement
│   │   ├── ErrorHandling.psm1  # Fehlerbehandlung
│   │   └── Logging.psm1        # Loggingfunktionen
│   │
│   └── Utils/                  # Hilfsfunktionen
│       ├── FileOps.psm1        # Dateioperationen
│       └── Validation.psm1     # Eingabevalidierung
│
├── scripts/                    # Funktionsspezifische Scripts
│   ├── Feature1.ps1
│   ├── Feature2.ps1
│   └── ...
│
├── temp/                       # Temporäre Dateien
│
└── docs/                       # Dokumentation
    ├── README.md               # Hauptdokumentation
    └── CHANGELOG.md            # Änderungsprotokoll
```

## Komponentenbeschreibungen

### PiM-Manager.ps1
Dies ist der Haupteinstiegspunkt für die Anwendung. Es initialisiert die Umgebung, lädt alle erforderlichen Module und stellt das Hauptmenü dar. Von hier aus werden alle Funktionalitäten zugänglich gemacht und Umgebungseinstellungen an untergeordnete Scripts vererbt.

### config/
Dieser Ordner enthält alle Konfigurationsdateien:
- **settings.json**: Enthält anpassbare Einstellungen für die Anwendung.
- **defaults.json**: Definiert Standardwerte, die verwendet werden, wenn keine benutzerdefinierten Einstellungen vorhanden sind.

### logs/
Hier werden alle Logdateien gespeichert:
- **system/**: Enthält Systemlogs wie Startzeiten, Fehler und Warnungen.
- **user/**: Enthält nutzerspezifische Logs wie Aktionen und Ergebnisse.

### modules/
Enthält alle PowerShell-Module, die von der Anwendung verwendet werden:

#### UX/
Module für die Benutzerschnittstelle:
- **Menu.psm1**: Funktionen zur Darstellung und Verarbeitung von Menüs.
- **Themes.psm1**: Definiert Farbschemata und visuelle Darstellungen.
- **Messages.psm1**: Standardisierte Nachrichtenformate für Benutzerinteraktionen.

#### Core/
Kernmodule für grundlegende Funktionalitäten:
- **Session.psm1**: Verwaltet Benutzersitzungen und globale Zustände.
- **ErrorHandling.psm1**: Einheitliche Fehlerbehandlung und -meldungen.
- **Logging.psm1**: Funktionen zum Protokollieren von Aktionen und Ereignissen.

#### Utils/
Hilfsmodule für verschiedene Aufgaben:
- **FileOps.psm1**: Funktionen für Dateioperationen.
- **Validation.psm1**: Funktionen zur Validierung von Benutzereingaben.

### scripts/
Enthält einzelne Funktionsscripts, die vom Hauptmenü aufgerufen werden können. Jedes Script repräsentiert eine bestimmte Funktionalität des PiM-Managers.

### temp/
Verzeichnis für temporäre Dateien, die während der Ausführung erstellt werden. Diese Dateien können bei Bedarf gelöscht werden, ohne die Funktionalität zu beeinträchtigen.

### docs/
Enthält die Dokumentation des Projekts:
- **README.md**: Diese Datei mit allgemeinen Informationen.
- **CHANGELOG.md**: Protokoll der Änderungen und Updates.

## Installation

1. Klonen oder laden Sie das Repository herunter.
2. Stellen Sie sicher, dass PowerShell 5.1 oder höher installiert ist.
3. Führen Sie `PiM-Manager.ps1` aus, um das Tool zu starten.

## Verwendung

Starten Sie die Anwendung durch Ausführen von `PiM-Manager.ps1`:

```powershell
.\PiM-Manager.ps1
```

Folgen Sie den Anweisungen im Hauptmenü, um auf die verschiedenen Funktionen zuzugreifen.

## Erweiterungen und eigene Scripts

Um neue Funktionalität hinzuzufügen:

1. Erstellen Sie ein neues Script im Ordner `scripts/`.
2. Importieren Sie benötigte Module aus dem `modules/`-Verzeichnis.
3. Fügen Sie einen Menüeintrag in `PiM-Manager.ps1` oder in einer Konfigurationsdatei hinzu.

Beispiel für ein neues Funktionsscript:

```powershell
# scripts/MeinScript.ps1

# Module importieren
Import-Module -Name "$PSScriptRoot\..\modules\Core\Logging.psm1"
Import-Module -Name "$PSScriptRoot\..\modules\UX\Messages.psm1"

# Funktion definieren
function Start-MeineFunktion {
    Write-Log -Level "Info" -Message "Meine Funktion gestartet"
    Show-Message -Type "Info" -Message "Funktion wird ausgeführt..."
    
    # Funktionslogik hier
    
    Show-Message -Type "Success" -Message "Funktion erfolgreich abgeschlossen"
}

# Funktion ausführen
Start-MeineFunktion
```

## Best Practices

- **Modulimporte**: Verwenden Sie relative Pfade für Modulimporte, um Portabilität zu gewährleisten.
- **Fehlerbehandlung**: Nutzen Sie das ErrorHandling-Modul für einheitliche Fehlerbehandlung.
- **Logging**: Protokollieren Sie alle wichtigen Aktionen mit dem Logging-Modul.
- **Konfiguration**: Speichern Sie keine Hardcoded-Werte in Scripts, sondern verwenden Sie die Konfigurationsdateien.
- **UX-Konsistenz**: Verwenden Sie die UX-Module für eine einheitliche Benutzererfahrung.

## Potenziale und bekannte Probleme

### Potenziale
- Erweiterbarkeit durch modulare Struktur
- Wiederverwendbarkeit der Module in anderen Projekten
- Einfache Versionskontrolle

### Bekannte Probleme
- Bei umfangreichen Skripten kann die Modularisierung die Performance beeinträchtigen
- Korrekte Importpfade sind entscheidend für die Funktionalität
- Bei wachsender Komplexität könnte eine formale Abhängigkeitsverwaltung notwendig werden

## Lizenz

[Hier Lizenzinformationen einfügen]

## Kontakt

[Hier Kontaktinformationen einfügen]