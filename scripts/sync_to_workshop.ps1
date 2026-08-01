# Unified sync script: all null0x686F local repos -> Zomboid Workshop test folder.
# Replaces the 5 near-identical per-repo copies (corelib/qol/contextcleaner/combattext/dangersensorhud).
# Run after any code change to test in-game.
#
# Usage:
#   .\sync_to_workshop.ps1              # syncs every mod
#   .\sync_to_workshop.ps1 -Mod qol     # syncs just one (folder name, not display name)

param(
    [string]$Mod = "all"
)

$RepoRoot = "C:\obsidian\pz-mods-byme"
$WorkshopRoot = "C:\Users\lucas\Zomboid\Workshop"

$Mods = [ordered]@{
    corelib         = "[null0x686F] CoreLib"
    qol             = "[null0x686F] QoL"
    contextcleaner  = "[null0x686F] ContextCleaner"
    combattext      = "[null0x686F] CombatText"
    dangersensorhud = "[null0x686F] DangerSensorHUD"
}

if ($Mod -eq "all") {
    $Targets = $Mods.Keys
} elseif ($Mods.Contains($Mod)) {
    $Targets = @($Mod)
} else {
    Write-Host "Unknown mod '$Mod'. Valid: all, $($Mods.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

$HadErrors = $false

foreach ($folder in $Targets) {
    $SourcePath = Join-Path $RepoRoot $folder
    $DestPath = Join-Path $WorkshopRoot $folder

    Write-Host "Syncing $($Mods[$folder])..." -ForegroundColor Cyan
    Write-Host "Source: $SourcePath"
    Write-Host "Dest:   $DestPath"
    Write-Host "--------------------------------------------------"

    robocopy "$SourcePath" "$DestPath" /MIR /XD .git /NFL /NDL

    if ($LASTEXITCODE -lt 8) {
        Write-Host "Sync complete." -ForegroundColor Green
    } else {
        Write-Host "Warning: errors during copy. (Robocopy Exit Code: $LASTEXITCODE)" -ForegroundColor Red
        $HadErrors = $true
    }
    Write-Host ""
}

if (-not [Console]::IsInputRedirected) {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

if ($HadErrors) { exit 1 }
