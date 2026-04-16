
#Requires -Version 5.1
<#
.SYNOPSIS
    Unit tests for ScreenshotOrganizer modules.

.DESCRIPTION
    Imports each module and runs assertions against key functions.
    Exits with code 1 if any test fails, 0 on full pass.

.EXAMPLE
    .\tests\Run-Tests.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root       = Split-Path $PSScriptRoot -Parent
$modulesDir = Join-Path $root "modules"

Import-Module (Join-Path $modulesDir "Config.psm1")    -Force
Import-Module (Join-Path $modulesDir "Logging.psm1")   -Force
Import-Module (Join-Path $modulesDir "Timestamp.psm1") -Force
Import-Module (Join-Path $modulesDir "PathGen.psm1")   -Force

$pass = 0
$fail = 0

function Assert-Equal {
    param([string]$Label, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        Write-Host "[PASS] $Label" -ForegroundColor Green
        $script:pass++
    }
    else {
        Write-Host "[FAIL] $Label" -ForegroundColor Red
        Write-Host "       Expected : $Expected"
        Write-Host "       Actual   : $Actual"
        $script:fail++
    }
}

function Assert-True  { param([string]$Label, [bool]$Value) Assert-Equal $Label $true  $Value }
function Assert-False { param([string]$Label, [bool]$Value) Assert-Equal $Label $false $Value }

# ---------------------------------------------------------------------------
# PathGen -- Get-TargetBaseName
# ---------------------------------------------------------------------------

$ts = [DateTime]::new(2026, 4, 16, 13, 42, 8)

Assert-Equal "Get-TargetBaseName: basic"           "2026-04-16T13-42-08" (Get-TargetBaseName -Timestamp $ts)
Assert-Equal "Get-TargetBaseName: midnight"        "2026-01-01T00-00-00" (Get-TargetBaseName -Timestamp ([DateTime]::new(2026,1,1,0,0,0)))
Assert-Equal "Get-TargetBaseName: end of day"      "2026-12-31T23-59-59" (Get-TargetBaseName -Timestamp ([DateTime]::new(2026,12,31,23,59,59)))

# ---------------------------------------------------------------------------
# PathGen -- Get-TargetFolder
# ---------------------------------------------------------------------------

$f = Get-TargetFolder -Timestamp $ts -DestinationRoot "C:\Out"
Assert-Equal "Get-TargetFolder: year segment"      "C:\Out\2026\04 - April\2026-04-16" $f

$fJan = Get-TargetFolder -Timestamp ([DateTime]::new(2025,1,5,0,0,0)) -DestinationRoot "C:\Out"
Assert-Equal "Get-TargetFolder: January"           "C:\Out\2025\01 - January\2025-01-05" $fJan

# ---------------------------------------------------------------------------
# PathGen -- filename collision patterns (regex only, no filesystem)
# ---------------------------------------------------------------------------

$namePattern = '^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}(_\d+)?$'
Assert-True  "Name pattern: base name"             ("2026-04-16T13-42-08"   -match $namePattern)
Assert-True  "Name pattern: suffix _2"             ("2026-04-16T13-42-08_2" -match $namePattern)
Assert-True  "Name pattern: suffix _10"            ("2026-04-16T13-42-08_10"-match $namePattern)
Assert-False "Name pattern: colon format"          ("2026-04-16T13:42:08"   -match $namePattern)
Assert-False "Name pattern: plain name"            ("Screenshot 2026"        -match $namePattern)
Assert-False "Name pattern: space separator"       ("2026-04-16 13-42-08"   -match $namePattern)

# ---------------------------------------------------------------------------
# PathGen -- Test-AlreadyProcessed (uses real temp files)
# ---------------------------------------------------------------------------

$tempRoot = Join-Path $env:TEMP "OrgTest_$(Get-Random)"
try {
    $destRoot  = Join-Path $tempRoot "Dest"
    $goodPath  = Join-Path $destRoot "2026\04 - April\2026-04-16\2026-04-16T13-42-08.png"
    $goodDir   = Split-Path $goodPath -Parent
    New-Item -ItemType Directory -Path $goodDir -Force | Out-Null
    New-Item -ItemType File      -Path $goodPath -Force | Out-Null
    $goodFile  = Get-Item -LiteralPath $goodPath

    Assert-True  "Test-AlreadyProcessed: correctly placed"   (Test-AlreadyProcessed -File $goodFile -DestinationRoot $destRoot)

    $badPath   = Join-Path $destRoot "2026\04 - April\2026-04-16\Screenshot 2026.png"
    New-Item -ItemType File -Path $badPath -Force | Out-Null
    $badFile   = Get-Item -LiteralPath $badPath

    Assert-False "Test-AlreadyProcessed: plain filename"     (Test-AlreadyProcessed -File $badFile  -DestinationRoot $destRoot)

    # File with correct name but wrong structure (no year/month/day folders)
    $flatPath  = Join-Path $tempRoot "2026-04-16T13-42-08.png"
    New-Item -ItemType File -Path $flatPath -Force | Out-Null
    $flatFile  = Get-Item -LiteralPath $flatPath

    Assert-False "Test-AlreadyProcessed: correct name, wrong folder" (Test-AlreadyProcessed -File $flatFile -DestinationRoot $destRoot)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Config -- overrides
# ---------------------------------------------------------------------------

$cfg = Get-OrganizerConfig -OverrideSource "D:\Foo" -OverrideDest "E:\Bar"
Assert-Equal "Config: override source"             "D:\Foo" $cfg.SourceFolder
Assert-Equal "Config: override dest"               "E:\Bar" $cfg.DestinationRoot

$cfg2 = Get-OrganizerConfig
Assert-True  "Config: default extensions non-empty" ($cfg2.SupportedExtensions.Count -gt 0)
Assert-True  "Config: .png in extensions"           ($cfg2.SupportedExtensions -contains ".png")

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host ("=" * 45)
if ($fail -eq 0) {
    Write-Host "  All $pass tests passed." -ForegroundColor Green
} else {
    Write-Host "  $pass passed, $fail FAILED." -ForegroundColor Red
}
Write-Host ("=" * 45)

if ($fail -gt 0) { exit 1 }
exit 0
