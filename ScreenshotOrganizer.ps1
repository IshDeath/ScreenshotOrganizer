
#Requires -Version 5.1
<#
.SYNOPSIS
    Organizes screenshots into a date-based folder hierarchy.

.DESCRIPTION
    Scans a source folder for supported image files and moves them into
    subfolders named YYYY\MM - MonthName\YYYY-MM-DD, renaming each file
    to a Windows-safe ISO 8601 timestamp: YYYY-MM-DDTHH-mm-ss.ext

    Files already in the correct structure are detected and skipped.
    Each run produces a log file and an undo file so the last run can
    be reversed with -UndoLast.

.PARAMETER DryRun
    Preview all actions without moving any files.

.PARAMETER UndoLast
    Reverse the most recent run using the saved undo log.

.PARAMETER SourcePath
    Override the source folder defined in config\settings.json.

.PARAMETER DestinationRoot
    Override the destination root defined in config\settings.json.

.PARAMETER ConfigPath
    Path to a JSON config file. Defaults to .\config\settings.json.

.EXAMPLE
    .\ScreenshotOrganizer.ps1
    Organize screenshots using the default config.

.EXAMPLE
    .\ScreenshotOrganizer.ps1 -DryRun
    Preview what would happen without moving any files.

.EXAMPLE
    .\ScreenshotOrganizer.ps1 -DryRun -Verbose
    Preview with verbose skip messages included.

.EXAMPLE
    .\ScreenshotOrganizer.ps1 -UndoLast
    Reverse the most recent run.

.EXAMPLE
    .\ScreenshotOrganizer.ps1 -UndoLast -DryRun
    Preview what the undo would do without moving any files.

.EXAMPLE
    .\ScreenshotOrganizer.ps1 -SourcePath "D:\Captures" -DestinationRoot "D:\Organized"
    Run with custom paths, overriding the config file.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$UndoLast,
    [string]$SourcePath      = "",
    [string]$DestinationRoot = "",
    [string]$ConfigPath      = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Module imports
# ---------------------------------------------------------------------------

$modulesDir = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesDir "Config.psm1")    -Force
Import-Module (Join-Path $modulesDir "Logging.psm1")   -Force
Import-Module (Join-Path $modulesDir "Timestamp.psm1") -Force
Import-Module (Join-Path $modulesDir "PathGen.psm1")   -Force
Import-Module (Join-Path $modulesDir "FileOps.psm1")   -Force
Import-Module (Join-Path $modulesDir "UndoOps.psm1")   -Force
Import-Module (Join-Path $modulesDir "Summary.psm1")   -Force

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

if ($ConfigPath -eq "") {
    $ConfigPath = Join-Path $PSScriptRoot "config\settings.json"
}

$config = Get-OrganizerConfig `
    -ConfigPath     $ConfigPath `
    -OverrideSource $SourcePath `
    -OverrideDest   $DestinationRoot

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

New-FolderIfMissing $config.LogFolder
New-FolderIfMissing $config.UndoFolder

$runStamp   = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$logFile    = Join-Path $config.LogFolder  "run_${runStamp}.log"
$undoFile   = Join-Path $config.UndoFolder "undo_${runStamp}.json"
$undoLatest = Join-Path $config.UndoFolder "latest.txt"

$isVerbose = $PSBoundParameters.ContainsKey('Verbose')
$logger    = New-Logger -LogFile $logFile -IsVerbose $isVerbose -IsDryRun $DryRun.IsPresent

Write-LogEntry $logger "INFO" "=========================================="
Write-LogEntry $logger "INFO" "ScreenshotOrganizer started"
Write-LogEntry $logger "INFO" "DryRun      : $($DryRun.IsPresent)"
Write-LogEntry $logger "INFO" "UndoLast    : $($UndoLast.IsPresent)"
Write-LogEntry $logger "INFO" "Verbose     : $isVerbose"
Write-LogEntry $logger "INFO" "Source      : $($config.SourceFolder)"
Write-LogEntry $logger "INFO" "Destination : $($config.DestinationRoot)"
Write-LogEntry $logger "INFO" "Log file    : $logFile"
Write-LogEntry $logger "INFO" "=========================================="

# ---------------------------------------------------------------------------
# Undo mode
# ---------------------------------------------------------------------------

if ($UndoLast) {
    $undoResult = Invoke-Undo -UndoLatestFile $undoLatest -DryRun $DryRun.IsPresent
    foreach ($msg in $undoResult.Messages) {
        Write-LogEntry $logger $msg.Level $msg.Text
    }
    Write-FinalSummary -Logger $logger -IsDryRun $DryRun.IsPresent
    exit 0
}

# ---------------------------------------------------------------------------
# Validate source folder
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $config.SourceFolder)) {
    Write-LogEntry $logger "ERROR" "Source folder not found: $($config.SourceFolder)"
    Write-FinalSummary -Logger $logger -IsDryRun $DryRun.IsPresent
    exit 1
}

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------

Write-LogEntry $logger "INFO" "Scanning: $($config.SourceFolder)"

$allFiles = @(
    Get-ChildItem -LiteralPath $config.SourceFolder -File -Recurse -ErrorAction SilentlyContinue
)

$imageFiles = @(
    $allFiles | Where-Object {
        $config.SupportedExtensions -contains $_.Extension.ToLower()
    }
)

Write-LogEntry $logger "INFO" "Scan complete: $($allFiles.Count) total files, $($imageFiles.Count) image file(s) found"

$stats = [ordered]@{
    Scanned = $allFiles.Count
    Found   = $imageFiles.Count
    Moved   = 0
    Skipped = 0
    Failed  = 0
}

# ---------------------------------------------------------------------------
# Process image files
# ---------------------------------------------------------------------------

foreach ($file in $imageFiles) {

    if (Test-AlreadyProcessed -File $file -DestinationRoot $config.DestinationRoot) {
        Write-LogEntry $logger "SKIP" "Already processed: $($file.FullName)"
        $stats.Skipped++
        continue
    }

    $ts        = Get-BestTimestamp    -File $file
    $baseName  = Get-TargetBaseName   -Timestamp $ts
    $folder    = Get-TargetFolder     -Timestamp $ts -DestinationRoot $config.DestinationRoot
    $extension = $file.Extension.ToLower()
    $target    = Resolve-SafeTargetPath -TargetFolder $folder -BaseName $baseName -Extension $extension

    if ($DryRun) {
        Write-LogEntry $logger "DRY" "Would move : $($file.FullName)"
        Write-LogEntry $logger "DRY" "         -> $target"
        $stats.Moved++
        continue
    }

    $result = Move-Screenshot -File $file -TargetPath $target -UndoFile $undoFile

    if ($result.Success) {
        Write-LogEntry $logger "INFO" "Moved : $($file.FullName)"
        Write-LogEntry $logger "INFO" "    -> $target"
        $stats.Moved++
    }
    else {
        Write-LogEntry $logger "ERROR" "Failed '$($file.FullName)': $($result.Error)"
        $stats.Failed++
    }
}

# ---------------------------------------------------------------------------
# Save undo pointer
# ---------------------------------------------------------------------------

if (-not $DryRun) {
    if ($stats.Moved -gt 0) {
        Set-Content -LiteralPath $undoLatest -Value $undoFile -Encoding UTF8
        Write-LogEntry $logger "INFO" "Undo log saved: $undoFile"
    }
    else {
        Write-LogEntry $logger "INFO" "No files moved. Undo log was not created."
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-FinalSummary -Logger $logger -Stats $stats -IsDryRun $DryRun.IsPresent
