# PowerShell-Skript: 1-Entwicklungsumgebung.ps1
# Verwaltung der Entwicklungsumgebung mit `winget`
# Wird vom PiM-Manager aufgerufen und nutzt zentrale UX- und Menüfunktionen

# 1️⃣ INITIALISIERUNG

# Sicherstellen, dass das Skript im richtigen Verzeichnis ausgeführt wird
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logDir = "$scriptDirectory\logs"

# Importiere zentrale UX-Funktionen aus `PiM-Manager.ps1`
. "$scriptDirectory\PiM-Manager.ps1"

# Softwareliste für die Entwicklungsumgebung
$softwareList = @(
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "Git.Git"; Name = "Git" },
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" },
    @{ Id = "Python.Python"; Name = "Python" }
)

# 2️⃣ FUNKTIONEN

# Prüft, ob `winget` installiert ist und aktuell ist
function Ensure-Winget {
    Show-Message "Prüfe, ob 'winget' installiert ist..." "info"

    try {
        $wingetVersion = winget --version 2>$null
        if ($?) {
            Show-Message "'winget' ist installiert (Version: $wingetVersion)." "success"
        } else {
            Show-Message "'winget' ist nicht installiert. Installation wird gestartet..." "warning"
            Install-Winget
        }

        Show-Message "Prüfe, ob 'winget' aktuell ist..." "info"
        Start-Process -FilePath "winget" -ArgumentList "upgrade --id Microsoft.DesktopAppInstaller --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait -PassThru | Out-Null
        Show-Message "'winget' wurde aktualisiert." "success"
    } catch {
        Show-Message "Fehler bei der Überprüfung von 'winget': $_" "error"
        exit 1
    }
}

# Installiert `winget`, falls es nicht vorhanden ist
function Install-Winget {
    $wingetInstallerUrl = "https://aka.ms/getwinget"
    $wingetInstallerPath = "$env:TEMP\wingetInstaller.msixbundle"

    try {
        Show-Message "Lade 'winget' von $wingetInstallerUrl herunter..." "info"
        Invoke-WebRequest -Uri $wingetInstallerUrl -OutFile $wingetInstallerPath

        Show-Message "Installiere 'winget'..." "info"
        Add-AppxPackage -Path $wingetInstallerPath
        Show-Message "'winget' wurde erfolgreich installiert." "success"
    } catch {
        Show-Message "Fehler bei der Installation von 'winget': $_" "error"
        exit 1
    }
}

# Wähle eine oder mehrere Komponenten zur Installation/Deinstallation
function Select-Components {
    param([string]$action, $list)

    Write-Host "`nWelche Komponenten möchtest du $action?"
    for ($i = 0; $i -lt $list.Length; $i++) {
        Write-Host "$($i + 1)) $($list[$i].Name)"
    }
    Write-Host "A) Alle auswählen"

    $selection = (Read-Host "Gib die Nummer(n) ein (Komma getrennt)").Trim()

    if ($selection -eq "A") { return $list }
    
    $indexes = $selection -split "," | ForEach-Object { $_.Trim() -as [int] - 1 }
    return $indexes | Where-Object { $_ -ge 0 -and $_ -lt $list.Count } | ForEach-Object { $list[$_] }
}

# Installiert eine Software-Komponente
function Install-Component {
    param($component)
    Show-Message "Installiere $($component.Name)..." "info"

    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id=$($component.Id) --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Show-Message "$($component.Name) erfolgreich installiert." "success"
        } else {
            Show-Message "Fehler bei der Installation von $($component.Name). Exit Code: $($process.ExitCode)" "error"
        }
    } catch {
        Show-Message "Fehler beim Installieren von $($component.Name): $_" "error"
    }
}

# Deinstalliert eine Software-Komponente
function Uninstall-Component {
    param($component)
    Show-Message "Entferne $($component.Name)..." "info"

    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "uninstall --id=$($component.Id) --silent" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Show-Message "$($component.Name) erfolgreich entfernt." "success"
        } else {
            Show-Message "Fehler beim Entfernen von $($component.Name). Exit Code: $($process.ExitCode)" "error"
        }
    } catch {
        Show-Message "Fehler beim Entfernen von $($component.Name): $_" "error"
    }
}

# Aktualisiert alle installierten Komponenten
function Update-All {
    Show-Message "Aktualisiere Entwicklungsumgebung..." "success"

    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "upgrade --all --silent" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Show-Message "Alle installierten Komponenten wurden aktualisiert." "success"
        } else {
            Show-Message "Fehler beim Aktualisieren. Exit Code: $($process.ExitCode)" "error"
        }
    } catch {
        Show-Message "Fehler beim Aktualisieren: $_" "error"
    }
}

# 3️⃣ HAUPTMENÜ-LOGIK

# Stelle sicher, dass `winget` vorhanden & aktuell ist
Ensure-Winget

while ($true) {
    $option = Show-SubMenu "Entwicklungsumgebung verwalten" @(
        "Entwicklungsumgebung einrichten",
        "Entwicklungsumgebung aktualisieren",
        "Entwicklungsumgebung entfernen",
        "Zurück zum PiM-Manager"
    )

    switch ($option) {
        "1" {
            $components = Select-Components "einrichten" $softwareList
            foreach ($component in $components) {
                Install-Component $component
            }
        }
        "2" { Update-All }
        "3" {
            $components = Select-Components "entfernen" $softwareList
            foreach ($component in $components) {
                Uninstall-Component $component
            }
        }
        "4" { exit }
        default { Show-Message "Ungültige Eingabe. Bitte erneut versuchen." "error" }
    }
}