# BF2_Mod_Tool.ps1
# Run in the main Battlefield 2 folder (where BF2.exe is located)

$ErrorActionPreference = "Stop"

$scriptPath = $PSScriptRoot
if (-not $scriptPath) { $scriptPath = Get-Location }
$modsPath = Join-Path $scriptPath "mods\bf2"
$objectsZip = Join-Path $modsPath "Objects_server.zip"
$aiFile = Join-Path $modsPath "AI\AIDefault.ai"

# Backup Objects_server.zip
if (Test-Path $objectsZip) {
    $backupDir = Join-Path $modsPath "backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $backupDir "Objects_server_backup_$timestamp.zip"
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

do {
    Write-Host "`n===== BF2 MOD TOOL =====" -ForegroundColor Cyan
    Write-Host "1. Unlimited Ammo - Handheld weapons"
    Write-Host "2. Unlimited Ammo - Vehicles (Air/Land)"
    Write-Host "3. Set Max Bots (edit AIDefault.ai)"
    Write-Host "4. Enhance Air Vehicles: Missile/Bomb (RPM=999, burst=5, PIAltFire) + Flare Spam (X) + Reduce Flare Cooldown to 1s"
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
            Write-Host "===== ENHANCING AIR VEHICLES =====" -ForegroundColor Yellow
            
            # Step 1: Modify global flare launcher (reduce cooldown, set proper values)
            Write-Host "`n[1/2] Modifying global flare launcher (decoy_Flare_Launcher.tweak)..." -ForegroundColor Cyan
            $flareGlobalPath = "Weapons/Armament/decoy_flare_launcher/decoy_Flare_Launcher.tweak"
            $resGlobal = Edit-ZipEntry -zipPath $objectsZip -entryPath $flareGlobalPath -modifyAction {
                param($content)
                # Keep SingleFireComp, only adjust values
                # Set roundsPerMinute to 300 (or higher, but stable)
                $content = $content -replace '(ObjectTemplate\.fire\.roundsPerMinute\s+)\d+', '${1}300'
                # Ensure fireInput = PIFlareFire
                if ($content -match 'ObjectTemplate\.fire\.fireInput') {
                    $content = $content -replace '(ObjectTemplate\.fire\.fireInput\s+)\S+', '${1}PIFlareFire'
                } else {
                    $content = $content -replace '(rem ---BeginComp:SingleFireComp ---.*?ObjectTemplate.createComponent SingleFireComp)', "`$1`nObjectTemplate.fire.fireInput PIFlareFire"
                }
                # addFireRate = 1, burstSize = 5
                if ($content -match 'ObjectTemplate\.fire\.addFireRate') {
                    $content = $content -replace '(ObjectTemplate\.fire\.addFireRate\s+)\d+', '${1}1'
                } else {
                    $content = $content -replace '(rem ---EndComp ---)', "ObjectTemplate.fire.addFireRate 1`n`$1"
                }
                if ($content -match 'ObjectTemplate\.fire\.burstSize') {
                    $content = $content -replace '(ObjectTemplate\.fire\.burstSize\s+)\d+', '${1}5'
                } else {
                    $content = $content -replace '(rem ---EndComp ---)', "ObjectTemplate.fire.burstSize 5`n`$1"
                }
                # Reduce cooldown: minimumTimeUntilReload = 1, reloadTime = 0.5
                $content = $content -replace '(ObjectTemplate\.ammo\.minimumTimeUntilReload\s+)\d+', '${1}1'
                $content = $content -replace '(ObjectTemplate\.ammo\.reloadTime\s+)\d+', '${1}0.5'
                # Set unlimited ammo: magSize = 999, nrOfMags = 999
                if ($content -match 'ObjectTemplate\.ammo\.magSize') {
                    $content = $content -replace '(ObjectTemplate\.ammo\.magSize\s+)\-?\d+', '${1}999'
                } else {
                    $content = $content -replace '(rem ---BeginComp:DefaultAmmoComp ---.*?ObjectTemplate.createComponent DefaultAmmoComp)', "`$1`nObjectTemplate.ammo.magSize 999"
                }
                if ($content -match 'ObjectTemplate\.ammo\.nrOfMags') {
                    $content = $content -replace '(ObjectTemplate\.ammo\.nrOfMags\s+)\-?\d+', '${1}999'
                } else {
                    $content = $content -replace '(rem ---BeginComp:DefaultAmmoComp ---.*?ObjectTemplate.createComponent DefaultAmmoComp)', "`$1`nObjectTemplate.ammo.nrOfMags 999"
                }
                return $content
            }
            if ($resGlobal) { Write-Host "Global flare launcher modified: cooldown reduced to ~1s, spam enabled (X key)." -ForegroundColor Green }
            else { Write-Host "Global flare launcher not found or unchanged." -ForegroundColor Yellow }

            # Step 2: Modify individual air vehicle tweaks (missiles/bombs) without breaking flares
            Write-Host "`n[2/2] Modifying individual air vehicle weapons (missiles/bombs)..." -ForegroundColor Cyan
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($objectsZip)
            $vehicleTweaks = $zip.Entries | Where-Object { 
                ($_.FullName -like "Vehicles/Air/*.tweak" -or $_.FullName -like "Vehicles/Air/*/*.tweak") -and
                $_.FullName -notlike "*cannon*" -and $_.FullName -notlike "*gun*" -and $_.FullName -notlike "*autocannon*"
            }
            $zip.Dispose()

            $count = 0
            foreach ($entry in $vehicleTweaks) {
                $fileName = Split-Path $entry.FullName -Leaf
                if ($fileName -match '(?i)cannon|gun|autocannon|mg$') { continue }
                
                $res = Edit-ZipEntry -zipPath $objectsZip -entryPath $entry.FullName -modifyAction {
                    param($content)
                    # Only modify MultiFireComp blocks that are NOT flare-related
                    # We'll use regex to find each MultiFireComp block, check if it contains "Flare" or not
                    $patternMulti = '(?s)(rem ---BeginComp:MultiFireComp ---.*?rem ---EndComp ---)'
                    $modifiedContent = [regex]::Replace($content, $patternMulti, {
                        param($match)
                        $block = $match.Groups[0].Value
                        # Skip if this block appears to be a flare launcher (based on object name or "flare")
                        if ($block -match '(?i)flare' -or $fileName -match '(?i)flare') {
                            return $block  # leave flare blocks untouched (already handled globally)
                        }
                        # Modify missile/bomb block
                        $block = $block -replace '(ObjectTemplate\.fire\.roundsPerMinute\s+)\d+', '${1}999'
                        if ($block -match 'ObjectTemplate\.fire\.fireInput') {
                            $block = $block -replace '(ObjectTemplate\.fire\.fireInput\s+)\S+', '${1}PIAltFire'
                        } else {
                            $block = $block -replace '(rem ---BeginComp:MultiFireComp ---.*?ObjectTemplate.createComponent MultiFireComp)', "`$1`nObjectTemplate.fire.fireInput PIAltFire"
                        }
                        if ($block -match 'ObjectTemplate\.fire\.addFireRate') {
                            $block = $block -replace '(ObjectTemplate\.fire\.addFireRate\s+)\d+', '${1}1'
                        } else {
                            $block = $block -replace '(rem ---EndComp ---)', "ObjectTemplate.fire.addFireRate 1`n`$1"
                        }
                        if ($block -match 'ObjectTemplate\.fire\.burstSize') {
                            $block = $block -replace '(ObjectTemplate\.fire\.burstSize\s+)\d+', '${1}5'
                        } else {
                            $block = $block -replace '(rem ---EndComp ---)', "ObjectTemplate.fire.burstSize 5`n`$1"
                        }
                        return $block
                    })
                    # Also ensure DefaultAmmoComp is set to 999 for these vehicle files
                    if ($modifiedContent -match '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)') {
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
                        $modifiedContent = $modifiedContent -replace '(?s)(rem ---BeginComp:DefaultAmmoComp ---.*?rem ---EndComp ---)', $newAmmo
                    }
                    return $modifiedContent
                }
                if ($res) { $count++ }
            }
            Write-Host "Modified $count air vehicle files (missiles/bombs)." -ForegroundColor Green
            Write-Host "`n===== SUMMARY =====" -ForegroundColor Cyan
            Write-Host "✓ Global flare cooldown reduced to ~1 second (press X to spam)." -ForegroundColor Green
            Write-Host "✓ Flare uses PIFlareFire (X key) - stable." -ForegroundColor Green
            Write-Host "✓ Missiles/bombs set to RPM=999, burst=5, fireInput=PIAltFire (RMB)." -ForegroundColor Green
            Write-Host "✓ Unlimited ammo (999) applied to both." -ForegroundColor Green
            Write-Host "If you still experience crashes, restore backup from 'mods/bf2/backup'." -ForegroundColor Yellow
        }

        "0" { Write-Host "Exiting..." -ForegroundColor Cyan }
        default { Write-Host "Invalid choice" -ForegroundColor Red }
    }
} while ($choice -ne "0")