
#Requires -Version 5.1

function Move-Screenshot {
    param(
        [Parameter(Mandatory)] [System.IO.FileInfo]$File,
        [Parameter(Mandatory)] [string]$TargetPath,
        [Parameter(Mandatory)] [string]$UndoFile
    )

    $result = @{ Success = $false; Error = "" }
    $targetFolder = Split-Path $TargetPath -Parent

    try {
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        }

        # Collision guard: Resolve-SafeTargetPath should have avoided this,
        # but a race condition or logic error could still cause a collision.
        if (Test-Path -LiteralPath $TargetPath) {
            $result.Error = "Target already exists (collision guard triggered): $TargetPath"
            return $result
        }

        Move-Item -LiteralPath $File.FullName -Destination $TargetPath -ErrorAction Stop

        # Append one JSON line to the undo file.
        # From = current location (where the file is now)
        # To   = original location (where to put it back on undo)
        $entry = [PSCustomObject]@{ From = $TargetPath; To = $File.FullName } | ConvertTo-Json -Compress
        Add-Content -LiteralPath $UndoFile -Value $entry -Encoding UTF8

        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

Export-ModuleMember -Function Move-Screenshot
