# PowerShell-Skript zur Verwaltung der Entwicklungsumgebung unter Windows 11 Pro

# ANSI-Farbdefinitionen für volle Kompatibilität mit modernen Terminals
$useANSI = $true
if ($Host.Name -match 'ConsoleHost' -and $PSVersionTable.PSVersion.Major -lt 7) {
    $useANSI = $false
}

# Farbwerte (mit Fallback für ältere PowerShell-Versionen)
$colorSuccess = if ($useANSI) { "`e[34m" } else { "DarkBlue" }
$colorWarning = if ($useANSI) { "`e[33m" } else { "DarkYellow" }
$colorError = if ($useANSI) { "`e[31m" } else { "Red" }
$colorInfo = if ($useANSI) { "`e[37m" } else { "Gray" }
$colorPrompt = if ($useANSI) { "`e[36m" } else { "Cyan" }
$colorHighlight = if ($useANSI) { "`e[97m" } else { "White" }
$colorReset = if ($useANSI) { "`e[0m" } else { "" }

# Verfügbare Software-Liste
$softwareList = @(
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "Git.Git"; Name = "Git" },
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" },
    @{ Id = "Python.Python"; Name = "Python" }
)

function Show-Menu {
    Clear-Host
    Write-Host "=====================================" $colorHighlight
    Write-Host "====  Entwicklungsumgebung Verwaltung  ====" $colorInfo
    Write-Host "=====================================" $colorHighlight
    Write-Host "1. Entwicklungsumgebung einrichten" $colorPrompt
    Write-Host "2. Entwicklungsumgebung aktualisieren" $colorPrompt
    Write-Host "3. Entwicklungsumgebung entfernen" $colorPrompt
    Write-Host "4. Beenden" $colorPrompt
    return Read-Host "Bitte eine Option wählen (1-4 oder 'exit' zum Beenden)"
}

function Select-Components {
    param([string]$action)
    
    Write-Host "------------------------------------" $colorHighlight
    Write-Host "Welche Komponenten möchten Sie $action? (Mehrfachauswahl möglich)" $colorInfo
    for ($i = 0; $i -lt $softwareList.Count; $i++) {
        Write-Host "$($i + 1). $($softwareList[$i].Name)" $colorPrompt
    }
    Write-Host "$(($softwareList.Count + 1)). Alle auswählen" $colorPrompt
    Write-Host "------------------------------------" $colorHighlight
    
    $input = Read-Host "Bitte eine oder mehrere Zahlen (z.B. 1,2) wählen oder 'exit' zum Beenden"
    if ($input -eq "exit") { exit }
    
    $selectedIndexes = $input -split ',' | ForEach-Object { $_.Trim() }
    if ($selectedIndexes -contains ($softwareList.Count + 1).ToString()) {
        return $softwareList
    }
    return $softwareList[$selectedIndexes -as [int[]]]
}

function Install-Component {
    param($component)
    Write-Host "$colorInfo Überprüfe Installation von $($component.Name)... $colorReset"
    if (!(Get-Command $component.Id -ErrorAction SilentlyContinue)) {
        Write-Host "$colorSuccess Installiere $($component.Name)... $colorReset"
        winget install --id $component.Id -e --silent
    } else {
        Write-Host "$colorWarning $($component.Name) ist bereits installiert. $colorReset"
    }
}

function Cleanup-System {
    Write-Host "$colorInfo Bereinigung des Systems gestartet... $colorReset"
    Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue
    Start-Process -FilePath "reg" -ArgumentList "delete HKCU\Software\Temp /f" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process -FilePath "cleanmgr" -ArgumentList "/sagerun:1" -NoNewWindow -Wait
    Write-Host "$colorSuccess Systembereinigung abgeschlossen. $colorReset"
}

function Uninstall-Component {
    param($component)
    Write-Host "------------------------------------" $colorHighlight
    Write-Host "$colorWarning Deinstalliere $($component.Name)... $colorReset"
    winget uninstall --id $component.Id -e --silent
    Cleanup-System
    Write-Host "$colorSuccess $($component.Name) erfolgreich entfernt. $colorReset"
    Write-Host "------------------------------------" $colorHighlight
}

while ($true) {
    $option = Show-Menu
    if ($option -eq "exit") { exit }
    switch ($option) {
        '1' {
            $components = Select-Components "einrichten"
            foreach ($component in $components) {
                Install-Component $component
            }
        }
        '2' {
            Write-Host "$colorSuccess Aktualisiere Entwicklungsumgebung... $colorReset"
            winget upgrade --all --silent
        }
        '3' {
            $components = Select-Components "entfernen"
            foreach ($component in $components) {
                Uninstall-Component $component
            }
        }
        '4' { exit }
        default { Write-Host "$colorError Ungültige Eingabe. Bitte erneut versuchen. $colorReset" }
    }
}