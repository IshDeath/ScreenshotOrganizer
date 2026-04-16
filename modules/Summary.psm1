
#Requires -Version 5.1
<#
    Summary uses Write-Host and Add-Content directly rather than importing
    Logging.psm1, so that module loading order does not affect session state.
#>

function Write-FinalSummary {
    param(
        [Parameter(Mandatory)] [hashtable]$Logger,
        [hashtable]$Stats   = $null,
        [bool]$IsDryRun     = $false
    )

    $bar   = "-" * 55
    $label = if ($IsDryRun) { "SUMMARY  (DRY RUN -- no files were moved)" } else { "SUMMARY" }

    $lines = @()
    $lines += $bar
    $lines += "  $label"
    $lines += $bar

    if ($null -ne $Stats) {
        $movedLabel = if ($IsDryRun) { "Files that would move " } else { "Files moved         " }
        $lines += "  Total files scanned : $($Stats.Scanned)"
        $lines += "  Image files found   : $($Stats.Found)"
        $lines += "  $movedLabel : $($Stats.Moved)"
        $lines += "  Files skipped       : $($Stats.Skipped)"
        $lines += "  Files failed        : $($Stats.Failed)"
        $lines += $bar
    }

    $lines += "  Log file : $($Logger.LogFile)"

    if ($Logger.Errors.Count -gt 0) {
        $lines += ""
        $lines += "  Errors ($($Logger.Errors.Count)):"
        foreach ($err in $Logger.Errors) {
            $lines += "    $err"
        }
    }

    $lines += $bar

    $hasErrors = $Logger.Errors.Count -gt 0

    foreach ($l in $lines) {
        $color = if ($hasErrors -and ($l -eq $bar)) { "Red" } else { "White" }
        Write-Host $l -ForegroundColor $color
        Add-Content -LiteralPath $Logger.LogFile -Value $l -Encoding UTF8
    }
}

Export-ModuleMember -Function Write-FinalSummary
