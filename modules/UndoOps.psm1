
#Requires -Version 5.1
<#
    UndoOps does not import Logging.psm1 to avoid a -Force re-import clobbering
    the caller's session state. Instead, Invoke-Undo returns a result object.
    The caller (main script) is responsible for logging each message.
#>

function Invoke-Undo {
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]$UndoLatestFile,
        [Parameter(Mandatory)] [bool]$DryRun
    )

    $result = [PSCustomObject]@{
        Messages   = [System.Collections.Generic.List[object]]::new()
        Succeeded  = 0
        Failed     = 0
    }

    # Helper that appends a message object to the result list.
    # Level is one of: INFO, WARN, ERROR, DRY
    $addMsg = {
        param([string]$Level, [string]$Text)
        $result.Messages.Add([PSCustomObject]@{ Level = $Level; Text = $Text })
    }

    if (-not (Test-Path -LiteralPath $UndoLatestFile)) {
        & $addMsg "WARN" "No undo pointer found at: $UndoLatestFile"
        & $addMsg "WARN" "Nothing to undo. Run the organizer first."
        return $result
    }

    $undoFilePath = ""
    try {
        $undoFilePath = (Get-Content -LiteralPath $UndoLatestFile -Encoding UTF8 -ErrorAction Stop).Trim()
    }
    catch {
        & $addMsg "ERROR" "Could not read undo pointer file: $_"
        return $result
    }

    if ($undoFilePath -eq "" -or -not (Test-Path -LiteralPath $undoFilePath)) {
        & $addMsg "ERROR" "Undo file listed in latest.txt does not exist: '$undoFilePath'"
        return $result
    }

    $rawLines = @(
        Get-Content -LiteralPath $undoFilePath -Encoding UTF8 |
            Where-Object { $_.Trim() -ne "" }
    )

    if ($rawLines.Count -eq 0) {
        & $addMsg "INFO" "Undo file is empty. Nothing to reverse."
        return $result
    }

    & $addMsg "INFO" "Undoing $($rawLines.Count) move(s) from: $undoFilePath"

    # Reverse so the most-recently-moved file is restored first.
    [array]::Reverse($rawLines)

    foreach ($line in $rawLines) {
        try {
            $entry = $line | ConvertFrom-Json
            $from  = $entry.From   # file's current (post-move) location
            $to    = $entry.To     # file's original (pre-move) location

            if ($DryRun) {
                & $addMsg "DRY" "Would undo: $from -> $to"
                $result.Succeeded++
                continue
            }

            if (-not (Test-Path -LiteralPath $from)) {
                & $addMsg "WARN" "Undo source not found (already moved or deleted?): $from"
                $result.Failed++
                continue
            }

            if (Test-Path -LiteralPath $to) {
                & $addMsg "WARN" "Undo destination already occupied, skipping: $to"
                $result.Failed++
                continue
            }

            $toFolder = Split-Path $to -Parent
            if (-not (Test-Path -LiteralPath $toFolder)) {
                New-Item -ItemType Directory -Path $toFolder -Force | Out-Null
            }

            Move-Item -LiteralPath $from -Destination $to -ErrorAction Stop
            & $addMsg "INFO" "Undone: $from -> $to"
            $result.Succeeded++
        }
        catch {
            & $addMsg "ERROR" "Undo failed for entry '$line': $_"
            $result.Failed++
        }
    }

    & $addMsg "INFO" "Undo complete. Succeeded=$($result.Succeeded) Failed=$($result.Failed)"

    if (-not $DryRun -and $result.Failed -eq 0) {
        Remove-Item -LiteralPath $UndoLatestFile -Force -ErrorAction SilentlyContinue
        & $addMsg "INFO" "Cleared undo pointer (latest.txt) after full success."
    }
    elseif (-not $DryRun -and $result.Failed -gt 0) {
        & $addMsg "WARN" "Undo pointer NOT cleared because $($result.Failed) item(s) failed."
    }

    return $result
}

Export-ModuleMember -Function Invoke-Undo
