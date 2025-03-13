#Requires -Version 5.0
# PiM Bootstrap Installer
# Ausführung: iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/yourorg/pim-setup/raw/main/install.ps1'))

[CmdletBinding()]
param (
    [Parameter()]
    [string]$InstallDir = "$env:USERPROFILE\PiM",
    
    [Parameter()]
    [string]$Branch = "main",
    
    [Parameter()]
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Beschleunigt WebClient-Downloads
$InformationPreference = "Continue"

# Status-Tracking-Datei
$statusFile = "$env:TEMP\pim-setup-status.json"
$logFile = "$env:TEMP\pim-setup.log"

$baseRepoUrl = "https://github.com/yourorg/pim-setup"
$setupModules = @(
    @{ Name = "0_pim-check-requirements"; Description = "Voraussetzungen prüfen" },
    @{ Name = "1_pim-setup-prerequisites"; Description = "Abhängigkeiten installieren" },
    @{ Name = "2_pim-setup-repository"; Description = "Repository einrichten" },
    @{ Name = "3_pim-generate-configs"; Description = "Konfigurationsdateien generieren" },
    @{ Name = "4_pim-setup-docker-environment"; Description = "Docker-Umgebung einrichten" }
)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

function Initialize-Setup {
    # Starte neue Setup-Session oder setze vorherige fort
    if ((Test-Path $statusFile) -and -not $Force) {
        try {
            $status = Get-Content $statusFile -Raw | ConvertFrom-Json
            Write-Log "Vorheriges Setup gefunden, wird fortgesetzt ab Modul: $($status.CurrentModule)" -Level "INFO"
            return $status
        }
        catch {
            Write-Log "Statusdatei konnte nicht gelesen werden, starte neu: $_" -Level "WARNING"
        }
    }
    
    # Neuen Status initialisieren
    $status = @{
        StartTime = Get-Date -Format "o"
        CurrentModule = 0
        CompletedModules = @()
        InstallDir = $InstallDir
        Branch = $Branch
        Errors = @()
    }
    
    $status | ConvertTo-Json | Set-Content $statusFile
    return $status
}

function Update-SetupStatus {
    param (
        [PSCustomObject]$Status,
        [int]$ModuleIndex = -1,
        [bool]$Success = $false,
        [string]$ErrorMsg = ""
    )
    
    if ($ModuleIndex -ge 0) {
        $Status.CurrentModule = $ModuleIndex
        
        if ($Success) {
            $completedModule = $setupModules[$ModuleIndex].Name
            if ($Status.CompletedModules -notcontains $completedModule) {
                $Status.CompletedModules += $completedModule
            }
        }
    }
    
    if ($ErrorMsg) {
        $errorEntry = @{
            Timestamp = Get-Date -Format "o"
            Module = $setupModules[$ModuleIndex].Name
            Message = $ErrorMsg
        }
        $Status.Errors += $errorEntry
    }
    
    $Status | ConvertTo-Json -Depth 10 | Set-Content $statusFile
}

function Ensure-Directory {
    param (
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Verzeichnis erstellt: $Path" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Konnte Verzeichnis nicht erstellen: $Path - $_" -Level "ERROR"
            return $false
        }
    }
    
    return $true
}

function Test-GitInstalled {
    try {
        $gitVersion = git --version
        Write-Log "Git ist installiert: $gitVersion" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Git ist nicht installiert oder nicht im PATH" -Level "WARNING"
        return $false
    }
}

function Install-Git {
    Write-Log "Installiere Git..." -Level "INFO"
    
    $tempFile = "$env:TEMP\GitInstaller.exe"
    try {
        # Download Git-Installer
        Write-Log "Lade Git-Installer herunter..."
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.1/Git-2.41.0-64-bit.exe" -OutFile $tempFile
        
        # Installiere Git
        Write-Log "Führe Git-Installer aus..."
        Start-Process -FilePath $tempFile -ArgumentList "/VERYSILENT /NORESTART" -Wait
        
        # Aktualisiere PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                   [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Überprüfe Installation
        if (Test-GitInstalled) {
            Write-Log "Git wurde erfolgreich installiert" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "Git-Installation fehlgeschlagen" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Fehler bei der Git-Installation: $_" -Level "ERROR"
        return $false
    }
    finally {
        # Bereinige Temp-Dateien
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

function Clone-SetupRepository {
    param (
        [string]$Destination,
        [string]$Branch = "main"
    )
    
    # Stelle sicher, dass das Zielverzeichnis existiert
    if (Test-Path $Destination) {
        # Prüfe, ob es bereits ein Git-Repository ist
        if (Test-Path "$Destination\.git") {
            Write-Log "Repository existiert bereits in $Destination, aktualisiere..." -Level "INFO"
            try {
                Push-Location $Destination
                git fetch origin
                git reset --hard "origin/$Branch"
                git clean -fd
                $result = $true
                Write-Log "Repository erfolgreich aktualisiert" -Level "SUCCESS"
            }
            catch {
                Write-Log "Fehler beim Aktualisieren des Repositories: $_" -Level "ERROR"
                $result = $false
            }
            finally {
                Pop-Location
            }
            return $result
        }
        else {
            # Erstelle Backup vom vorhandenen Verzeichnis
            $backupDir = "$Destination.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Write-Log "Vorhandenes Verzeichnis wird gesichert nach: $backupDir" -Level "WARNING"
            try {
                Rename-Item -Path $Destination -NewName $backupDir
            }
            catch {
                Write-Log "Konnte vorhandenes Verzeichnis nicht umbenennen: $_" -Level "ERROR"
                return $false
            }
        }
    }
    
    # Stelle sicher, dass das übergeordnete Verzeichnis existiert
    $parentDir = Split-Path -Path $Destination -Parent
    if (-not (Ensure-Directory -Path $parentDir)) {
        return $false
    }
    
    try {
        git clone --branch $Branch --single-branch --depth 1 "$baseRepoUrl.git" $Destination
        Write-Log "Repository erfolgreich geklont nach $Destination" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Fehler beim Klonen des Repositories: $_" -Level "ERROR"
        
        # Versuche, es über HTTPS zu klonen, falls SSH fehlschlägt
        try {
            git clone --branch $Branch --single-branch --depth 1 "$baseRepoUrl.git" $Destination
            Write-Log "Repository erfolgreich über HTTPS geklont" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Konnte Repository weder über SSH noch HTTPS klonen: $_" -Level "ERROR"
            return $false
        }
    }
}

function Execute-SetupModule {
    param (
        [int]$ModuleIndex,
        [PSCustomObject]$Status
    )
    
    $module = $setupModules[$ModuleIndex]
    $moduleName = $module.Name
    $moduleDescription = $module.Description
    
    Write-Log "=== Starte Modul $($ModuleIndex): $moduleName - $moduleDescription ===" -Level "INFO"
    
    # Prüfe, ob Modul bereits erfolgreich abgeschlossen wurde
    if ($Status.CompletedModules -contains $moduleName -and -not $Force) {
        Write-Log "Modul $moduleName wurde bereits erfolgreich abgeschlossen, überspringe..." -Level "SUCCESS"
        return $true
    }
    
    # Führe Modul aus
    try {
        $scriptPath = Join-Path $Status.InstallDir "scripts\$moduleName.ps1"
        
        if (-not (Test-Path $scriptPath)) {
            Write-Log "Skript nicht gefunden: $scriptPath" -Level "ERROR"
            return $false
        }
        
        # Parameter für das Skript vorbereiten
        $params = @{
            InstallDir = $Status.InstallDir
            LogFile = $logFile
            Force = $Force
        }
        
        # Skript ausführen
        & $scriptPath @params
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Modul $moduleName schlug fehl mit Exit-Code $LASTEXITCODE" -Level "ERROR"
            return $false
        }
        
        Write-Log "Modul $moduleName erfolgreich abgeschlossen" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Fehler beim Ausführen von Modul $moduleName: $_" -Level "ERROR"
        return $false
    }
}

# Hauptfunktion
function Start-PiMSetup {
    # Banner anzeigen
    Write-Host @"
    
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║                  PiM - SETUP INSTALLER                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
    
    Write-Log "PiM-Setup gestartet - Zielverzeichnis: $InstallDir, Branch: $Branch" -Level "INFO"
    
    # Initialisiere oder setze Setup fort
    $status = Initialize-Setup
    
    # Stelle sicher, dass Git installiert ist
    if (-not (Test-GitInstalled)) {
        $installGit = Read-Host "Git ist erforderlich, aber nicht installiert. Jetzt installieren? (j/N)"
        if ($installGit -eq "j") {
            if (-not (Install-Git)) {
                Write-Log "Setup wird abgebrochen, da Git nicht installiert werden konnte" -Level "ERROR"
                return 1
            }
        }
        else {
            Write-Log "Setup wird abgebrochen, da Git benötigt wird" -Level "ERROR"
            return 1
        }
    }
    
    # Klone das Setup-Repository
    if (-not (Clone-SetupRepository -Destination $InstallDir -Branch $Branch)) {
        Write-Log "Setup wird abgebrochen, da das Repository nicht geklont werden konnte" -Level "ERROR"
        return 1
    }
    
    # Module der Reihe nach ausführen
    for ($i = $status.CurrentModule; $i -lt $setupModules.Count; $i++) {
        $success = Execute-SetupModule -ModuleIndex $i -Status $status
        
        Update-SetupStatus -Status $status -ModuleIndex $i -Success $success
        
        if (-not $success) {
            Write-Log "Modul $($setupModules[$i].Name) schlug fehl. Versuche erneut? (j/N)" -Level "WARNING"
            $retry = Read-Host
            
            if ($retry -eq "j") {
                $i-- # Wiederhole dieses Modul
            }
            else {
                Write-Log "Setup unterbrochen bei Modul $($setupModules[$i].Name)" -Level "WARNING"
                Write-Log "Sie können das Setup später fortsetzen, indem Sie dieses Skript erneut ausführen" -Level "INFO"
                return 1
            }
        }
    }
    
    # Setup abgeschlossen
    Write-Host @"
    
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         🎉 PiM-SETUP ERFOLGREICH ABGESCHLOSSEN 🎉         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
    
    Write-Log "Alle Module erfolgreich ausgeführt" -Level "SUCCESS"
    Write-Host "PiM wurde installiert in: $InstallDir" -ForegroundColor Cyan
    Write-Host "Zugangsdaten wurden gespeichert in: $InstallDir\pim-credentials.txt" -ForegroundColor Yellow
    
    if (Test-Path "$InstallDir\scripts\status.ps1") {
        Write-Host "`nFühre Statusüberprüfung aus..." -ForegroundColor Cyan
        & "$InstallDir\scripts\status.ps1"
    }
    
    # Löschen der Status-Datei nach erfolgreicher Installation
    if (Test-Path $statusFile) {
        Remove-Item $statusFile -Force
    }
    
    return 0
}

# Starte Setup
exit (Start-PiMSetup)