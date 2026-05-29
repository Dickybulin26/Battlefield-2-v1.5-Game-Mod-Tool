# BF2_Mod_Tool.ps1
# Run in the main Battlefield 2 folder (where BF2.exe is located)

$ErrorActionPreference = "Stop"

# Determine path relative to script location
$scriptPath = $PSScriptRoot
if (-not $scriptPath) { $scriptPath = Get-Location }
$modsPath = Join-Path $scriptPath "mods\bf2"
$objectsZip = Join-Path $modsPath "Objects_server.zip"
$aiFile = Join-Path $modsPath "AI\AIDefault.ai"

# ========== BACKUP OBJECTS_SERVER.ZIP BEFORE MENU ==========
if (Test-Path $objectsZip) {
    $backupDir = Join-Path $modsPath "backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $backupDir "Objects_server_backup_$timestamp.zip"   # <--- .zip extension
    
    Write-Host "`n===== BACKUP OBJECTS_SERVER.ZIP =====" -ForegroundColor Cyan
    Write-Host "Source: $objectsZip" -ForegroundColor Gray
    Write-Host "Destination: $backupFile" -ForegroundColor Gray
    $confirm = Read-Host "Backup file before modification? (Y/N) [Y]"
    if ($confirm -ne "N" -and $confirm -ne "n") {
        Write-Host "Creating backup..." -ForegroundColor Yellow
        Copy-Item -Path $objectsZip -Destination $backupFile -Force
        Write-Host "Backup successfully created at: $backupFile" -ForegroundColor Green
    }
    else {
        Write-Host "Backup skipped." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Objects_server.zip not found at: $objectsZip" -ForegroundColor Red
    Write-Host "Make sure the script is run from the main Battlefield 2 folder." -ForegroundColor Red
    exit
}
# ============================================

# Function to backup AIDefault.ai file
function Backup-File {
    param([string]$path)
    if (Test-Path $path) {
        $backup = "$path.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $path -Destination $backup
        Write-Host "Backup created: $backup" -ForegroundColor DarkGray
        return $true
    }
    return $false
}

# Function to modify file inside ZIP without extracting everything (use temp folder)
function Edit-ZipEntry {
    param(
        [string]$zipPath,
        [string]$entryPath,
        [scriptblock]$modifyAction
    )
    if (-not (Test-Path $zipPath)) {
        Write-Host "ZIP file not found: $zipPath" -ForegroundColor Red
        return $false
    }
    $tempDir = Join-Path $env:TEMP "BF2_Mod_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $entryPath -or $_.FullName -like "*$entryPath" } | Select-Object -First 1
        if (-not $entry) {
            Write-Host "Entry not found: $entryPath" -ForegroundColor Yellow
            return $false
        }
        $destFile = Join-Path $tempDir "temp.tweak"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
        $zip.Dispose()
        
        $content = Get-Content -Path $destFile -Raw
        $newContent = & $modifyAction $content
        if ($newContent -ne $content) {
            Set-Content -Path $destFile -Value $newContent -NoNewline
            $mode = 'Update'
            $zipOut = [System.IO.Compression.ZipFile]::Open($zipPath, $mode)
            $entryToDelete = $zipOut.GetEntry($entry.FullName)
            if ($entryToDelete) { $entryToDelete.Delete() }
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipOut, $destFile, $entry.FullName) | Out-Null
            $zipOut.Dispose()
            Write-Host "Modified: $entryPath" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "No changes for: $entryPath" -ForegroundColor DarkGray
            return $false
        }
    }
    catch {
        Write-Host "Error processing $entryPath : $_" -ForegroundColor Red
        return $false
    }
    finally {
        if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    }
}

# Main menu
do {
    Write-Host "`n===== BF2 MOD TOOL =====" -ForegroundColor Cyan
    Write-Host "1. Unlimited Ammo - Handheld weapons"
    Write-Host "2. Unlimited Ammo - Vehicles (Air/Land)"
    Write-Host "3. Set Max Bots (edit AIDefault.ai)"
    Write-Host "4. Set AGM Fire Rate to 9999 (Jet/Heli dual-seat)"
    Write-Host "0. Exit"
    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Host "Processing handheld weapons..." -ForegroundColor Yellow
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($objectsZip)
            $tweakFiles = $zip.Entries | Where-Object { $_.FullName -like "Weapons/Handheld/*.tweak" -and $_.FullName -notlike "*/*/*" }
            $zip.Dispose()
            $count = 0
            foreach ($entry in $tweakFiles) {
                $res = Edit-ZipEntry -zipPath $objectsZip -entryPath $entry.FullName -modifyAction {
                    param($content)
                    if ($content -match '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)') {
                        $newAmmo = @"
rem ---BeginComp:DefaultAmmoComp ---
ObjectTemplate.createComponent DefaultAmmoComp
rem *** 999 AMMO FOR ALL ***
ObjectTemplate.ammo.magSize 999
ObjectTemplate.ammo.nrOfMags 999
ObjectTemplate.ammo.autoReload 1
ObjectTemplate.ammo.reloadWithoutPlayer 1
rem ---EndComp ---
"@
                        $content = $content -replace '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)', $newAmmo
                    }
                    else {
                        $content = $content -replace '(?s)(rem ---EndComp ---)', "`$1`n`nrem ---BeginComp:DefaultAmmoComp ---`nObjectTemplate.createComponent DefaultAmmoComp`nrem *** 999 AMMO FOR ALL ***`nObjectTemplate.ammo.magSize 999`nObjectTemplate.ammo.nrOfMags 999`nObjectTemplate.ammo.autoReload 1`nObjectTemplate.ammo.reloadWithoutPlayer 1`nrem ---EndComp ---"
                    }
                    return $content
                }
                if ($res) { $count++ }
            }
            Write-Host "Modified $count handheld weapon tweaks." -ForegroundColor Green
        }

        "2" {
            Write-Host "Vehicle type: 1. Air  2. Land" -ForegroundColor Yellow
            $vt = Read-Host
            $subfolder = if ($vt -eq "1") { "Vehicles/Air" } elseif ($vt -eq "2") { "Vehicles/Land" } else { continue }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($objectsZip)
            $tweakFiles = $zip.Entries | Where-Object { $_.FullName -like "$subfolder/*.tweak" }
            $zip.Dispose()
            $count = 0
            foreach ($entry in $tweakFiles) {
                $res = Edit-ZipEntry -zipPath $objectsZip -entryPath $entry.FullName -modifyAction {
                    param($content)
                    if ($content -match '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)') {
                        $newAmmo = @"
rem ---BeginComp:DefaultAmmoComp ---
ObjectTemplate.createComponent DefaultAmmoComp
rem *** 999 AMMO FOR ALL ***
ObjectTemplate.ammo.magSize 999
ObjectTemplate.ammo.nrOfMags 999
ObjectTemplate.ammo.autoReload 1
ObjectTemplate.ammo.reloadWithoutPlayer 1
rem ---EndComp ---
"@
                        $content = $content -replace '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)', $newAmmo
                    }
                    else {
                        $content = $content -replace '(?s)(rem ---EndComp ---)', "`$1`n`nrem ---BeginComp:DefaultAmmoComp ---`nObjectTemplate.createComponent DefaultAmmoComp`nrem *** 999 AMMO FOR ALL ***`nObjectTemplate.ammo.magSize 999`nObjectTemplate.ammo.nrOfMags 999`nObjectTemplate.ammo.autoReload 1`nObjectTemplate.ammo.reloadWithoutPlayer 1`nrem ---EndComp ---"
                    }
                    return $content
                }
                if ($res) { $count++ }
            }
            Write-Host "Modified $count vehicle tweaks." -ForegroundColor Green
        }

        "3" {
            if (-not (Test-Path $aiFile)) {
                Write-Host "AIDefault.ai not found at $aiFile" -ForegroundColor Red
                break
            }
            Backup-File $aiFile
            $content = Get-Content $aiFile -Raw
            $botCount = Read-Host "Enter number of bots (max 255, e.g. 127)"
            if ($botCount -notmatch '^\d+$' -or [int]$botCount -gt 255) {
                Write-Host "Invalid number. Using 127." -ForegroundColor Yellow
                $botCount = 127
            }
            $newContent = $content -replace '(?m)^\s*rem\s+aiSettings\.overrideMenuSettings\s+1', 'aiSettings.overrideMenuSettings 1'
            $newContent = $newContent -replace '(?m)^\s*aiSettings\.overrideMenuSettings\s+0', 'aiSettings.overrideMenuSettings 1'
            $newContent = $newContent -replace '(?m)^\s*(rem\s+)?aiSettings\.setMaxNBots\s+\d+', "aiSettings.setMaxNBots $botCount"
            $newContent = $newContent -replace '(?m)^\s*aiSettings\.maxBotsIncludeHumans\s+1', 'aiSettings.maxBotsIncludeHumans 0'
            $newContent = $newContent -replace '(?m)^rem\s+(aiSettings\.(setMaxNBots|maxBotsIncludeHumans|overrideMenuSettings))', '$1'
            $newContent = $newContent -replace '(?m)^rem\s+aiSettings\.setBotSkill', 'aiSettings.setBotSkill'
            Set-Content -Path $aiFile -Value $newContent -NoNewline
            Write-Host "AIDefault.ai updated: Max bots = $botCount (excluding human)" -ForegroundColor Green
        }

        "4" {
            $targetAircraft = @(
                "usair_f15.tweak",
                "air_su34.tweak",
                "air_su30mkk.tweak",
                "air_f35b.tweak",
                "ahe_ah1z.tweak",
                "ahe_havoc.tweak",
                "ahe_z10.tweak"
            )
            $modified = 0
            foreach ($fileName in $targetAircraft) {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::OpenRead($objectsZip)
                $entries = $zip.Entries | Where-Object { $_.FullName -like "*$fileName" }
                $zip.Dispose()
                if ($entries.Count -eq 0) {
                    Write-Host "File $fileName not found in zip." -ForegroundColor DarkGray
                    continue
                }
                $entry = $entries[0]
                $res = Edit-ZipEntry -zipPath $objectsZip -entryPath $entry.FullName -modifyAction {
                    param($content)
                    $modifiedContent = $content
                    # MultiFireComp
                    $patternMulti = '(?s)(rem ---BeginComp:MultiFireComp ---.*?rem ---EndComp ---)'
                    if ($modifiedContent -match $patternMulti) {
                        $block = $matches[1]
                        $newBlock = $block -replace '(ObjectTemplate\.fire\.roundsPerMinute\s+)\d+', '${1}9999'
                        if ($newBlock -notmatch 'ObjectTemplate\.fire\.addFireRate') {
                            $newBlock = $newBlock -replace '(rem ---EndComp ---)', "ObjectTemplate.fire.addFireRate 1`nObjectTemplate.fire.burstSize 0`n`$1"
                        }
                        else {
                            $newBlock = $newBlock -replace '(ObjectTemplate\.fire\.addFireRate\s+)\d+', '${1}1'
                            $newBlock = $newBlock -replace '(ObjectTemplate\.fire\.burstSize\s+)\d+', '${1}0'
                        }
                        $modifiedContent = $modifiedContent -replace $patternMulti, $newBlock
                    }
                    # SingleFireComp
                    $patternSingle = '(?s)(rem ---BeginComp:SingleFireComp ---.*?rem ---EndComp ---)'
                    if ($modifiedContent -match $patternSingle) {
                        $block = $matches[1]
                        $newBlock = $block -replace '(ObjectTemplate\.fire\.roundsPerMinute\s+)\d+', '${1}9999'
                        $modifiedContent = $modifiedContent -replace $patternSingle, $newBlock
                    }
                    return $modifiedContent
                }
                if ($res) { $modified++ }
            }
            Write-Host "Modified $modified aircraft files (AGM rate = 9999)." -ForegroundColor Green
        }

        "0" { Write-Host "Exiting..." -ForegroundColor Cyan }
        default { Write-Host "Invalid choice" -ForegroundColor Red }
    }
} while ($choice -ne "0")