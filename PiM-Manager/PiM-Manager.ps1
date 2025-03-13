# PowerShell-Skript: PiM-Manager
# Zentraler Manager für PiM-Skripte mit einheitlichem Aufbau, Menüführung & UX

# 1️⃣ INITIALISIERUNG

# Aktuellen Pfad des Skripts bestimmen
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logDir = "$scriptDirectory\logs"
$scriptSubDir = "$scriptDirectory\scripte"

# Erstelle `logs`- und `scripte`-Verzeichnisse, falls nicht vorhanden
@($logDir, $scriptSubDir) | ForEach-Object {
    if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null }
}

# Generiere eine eindeutige Log-Datei für jede Session
$logTimestamp = Get-Date -Format "yyyy-MM-dd HH-mm"
$logFile = "$logDir\log-$logTimestamp.txt"

# Prüfe, ob eine Transkript-Session aktiv ist und stoppe sie korrekt
if ($global:TranscriptStatus) {
    Stop-Transcript | Out-Null
    Start-Sleep -Milliseconds 500
}

# Starte vollständige Protokollierung der Sitzung
try {
    Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null
} catch {
    Write-Host "WARNUNG: Konnte Transkript nicht starten. Fallback-Logging wird verwendet." -ForegroundColor Yellow
    $useFallbackLogging = $true
}

# Prüfe Admin-Rechte einmalig
function Ensure-AdminRights {
    if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "FEHLER: Dieses Skript benötigt Administratorrechte. Es wird jetzt neu gestartet..." -ForegroundColor Red
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
Ensure-AdminRights  # Admin-Check direkt zu Beginn

# ANSI-Farbdefinitionen für einheitliche UX
$useANSI = ($Host.Name -match 'ConsoleHost' -and $PSVersionTable.PSVersion.Major -ge 7)
$colorSuccess = if ($useANSI) { "`e[32m" } else { "Green" }
$colorWarning = if ($useANSI) { "`e[33m" } else { "Yellow" }
$colorError = if ($useANSI) { "`e[31m" } else { "Red" }
$colorReset = if ($useANSI) { "`e[0m" } else { "" }

# 2️⃣ HILFSFUNKTIONEN

# Logging-Funktion, die sicher funktioniert
function Show-Message {
    param([string]$message, [string]$type)

    $color = switch ($type) {
        "success" { $colorSuccess }
        "warning" { $colorWarning }
        "error" { $colorError }
        default { $colorReset }
    }

    Write-Host "$color$message$colorReset"

    # Falls `Start-Transcript` fehlschlägt, nutze Fallback-Logging
    if ($useFallbackLogging) {
        try {
            Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$type] $message"
        } catch {
            Write-Host "WARNUNG: Fallback-Log konnte nicht geschrieben werden." -ForegroundColor Yellow
        }
    }
}

# Menü für Unter-Skripte
function Show-SubMenu {
    param([string]$title, [string[]]$options)

    Write-Host "`n$title`n"
    for ($i = 0; $i -lt $options.Length; $i++) {
        Write-Host "$($i + 1)) $($options[$i])"
    }

    return (Read-Host "Wähle eine Option").Trim()
}

# Prüft die Menüauswahl des Benutzers (Erzwingt gültige Eingabe)
function Validate-MenuChoice {
    param([string]$input, [int]$maxOption)

    if ($input -match "^\d+$" -and [int]$input -ge 1 -and [int]$input -le $maxOption) {
        return [int]$input
    }

    Show-Message "Ungültige Auswahl. Bitte eine Zahl zwischen 1 und $maxOption eingeben." "warning"
    return $null
}

# 3️⃣ FUNKTIONEN ZUR VERWALTUNG DER ENTWICKLUNGSUMGEBUNG

# Entwicklungsumgebung starten
function Start-Entwicklungsumgebung {
    Show-Message "Starte Entwicklungsumgebung..." "success"

    try {
        # ExecutionPolicy nur setzen, falls nötig
        if ((Get-ExecutionPolicy -Scope Process) -notmatch "Unrestricted|Bypass") {
            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        }

        # Starte das Unter-Skript
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptSubDir\1-Entwicklungsumgebung.ps1`"" -NoNewWindow -Wait -PassThru -WorkingDirectory "$scriptSubDir" -RedirectStandardOutput "$logDir\script_output-$logTimestamp.log" -RedirectStandardError "$logDir\script_error-$logTimestamp.log"

        if ($process.ExitCode -ne 0) {
            $errorMessage = Get-Content "$logDir\script_error-$logTimestamp.log" -Raw
            Show-Message "Fehler beim Starten des Skripts. Details: $errorMessage" "error"
        } else {
            Show-Message "Entwicklungsumgebung erfolgreich gestartet." "success"
        }
    } catch {
        Show-Message "Unbekannter Fehler beim Starten der Entwicklungsumgebung: $_" "error"
    }
}

# 4️⃣ HAUPTMENÜ-LOGIK

# Hauptmenü anzeigen
function Show-Menu {
    Clear-Host
    Write-Host "PiM-Manager - Hauptmenü"
    Write-Host "1) Entwicklungsumgebung starten"
    Write-Host "2) Beenden"
}

# Menüschleife
while ($true) {
    Show-Menu
    $choice = (Read-Host "Wähle eine Option").Trim()

    # Prüfe & erzwinge gültige Eingabe
    while (-not $choice -or -not ($validatedChoice = Validate-MenuChoice $choice 2)) {
        $choice = (Read-Host "Wähle eine Option").Trim()
    }

    if ($validatedChoice -eq 1) { Start-Entwicklungsumgebung }
    elseif ($validatedChoice -eq 2) { Show-Message "PiM-Manager wird beendet." "success"; Stop-Transcript; exit }
}
