
#Requires -Version 5.1

function New-Logger {
    param(
        [Parameter(Mandatory)] [string]$LogFile,
        [bool]$IsVerbose = $false,
        [bool]$IsDryRun  = $false
    )

    return @{
        LogFile   = $LogFile
        IsVerbose = $IsVerbose
        IsDryRun  = $IsDryRun
        Errors    = [System.Collections.Generic.List[string]]::new()
        Warnings  = [System.Collections.Generic.List[string]]::new()
    }
}

function Write-LogEntry {
    param(
        [Parameter(Mandatory)] [hashtable]$Logger,
        [Parameter(Mandatory)] [ValidateSet("INFO","SKIP","WARN","ERROR","DRY")] [string]$Level,
        [Parameter(Mandatory)] [string]$Message
    )

    $ts     = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $prefix = if ($Logger.IsDryRun -and $Level -notin @("ERROR","WARN")) { "[DRY-RUN] " } else { "" }
    $line   = "[$ts] [$Level] $prefix$Message"

    Add-Content -LiteralPath $Logger.LogFile -Value $line -Encoding UTF8

    switch ($Level) {
        "ERROR" {
            Write-Host $line -ForegroundColor Red
            $Logger.Errors.Add($line) | Out-Null
        }
        "WARN"  {
            Write-Host $line -ForegroundColor Yellow
            $Logger.Warnings.Add($line) | Out-Null
        }
        "SKIP"  { if ($Logger.IsVerbose) { Write-Host $line -ForegroundColor DarkGray } }
        "INFO"  { Write-Host $line -ForegroundColor Cyan }
        "DRY"   { Write-Host $line -ForegroundColor Magenta }
    }
}

function New-FolderIfMissing {
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Export-ModuleMember -Function New-Logger, Write-LogEntry, New-FolderIfMissing
