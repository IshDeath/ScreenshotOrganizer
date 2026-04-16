
#Requires -Version 5.1
<#
    Timestamp Selection
    -------------------
    PowerShell does not include a native EXIF/metadata reader. Third-party
    modules exist (e.g. ExifTool wrappers) but require a separate install and
    are not guaranteed available.

    More importantly, screenshots produced by Windows -- Win+PrtScn, Snipping
    Tool, Snip & Sketch, Xbox Game Bar -- are screen captures, not camera
    photographs. They do NOT embed EXIF DateTimeOriginal. Inspecting EXIF would
    therefore find nothing useful and is not worth the dependency.

    Timestamp precedence used by this module:

        1. CreationTime  (File.CreationTime)
           The NTFS creation timestamp set when the OS first writes the file.
           For Windows screenshots this equals the moment of capture. This is
           the most reliable indicator of when the screenshot was taken.

        2. LastWriteTime  (File.LastWriteTime)
           The last-modified timestamp. Used as a fallback when CreationTime
           has been reset (e.g. by OneDrive sync, xcopy, robocopy, or a
           backup restore that did not preserve creation timestamps).

        3. Current time
           An ultimate fallback if both timestamps are invalid (pre-1970).
           A warning is logged. This case is extremely rare in practice.

    If you later add EXIF support (e.g. via ExifTool), insert its call before
    the CreationTime check below and return early on success.
#>

function Get-BestTimestamp {
    [OutputType([DateTime])]
    param(
        [Parameter(Mandatory)] [System.IO.FileInfo]$File
    )

    $ct = $File.CreationTime
    if ($ct -gt [DateTime]::MinValue -and $ct.Year -ge 1970) {
        return $ct
    }

    $wt = $File.LastWriteTime
    if ($wt -gt [DateTime]::MinValue -and $wt.Year -ge 1970) {
        return $wt
    }

    Write-Warning "No valid filesystem timestamp found for '$($File.FullName)'. Falling back to current time."
    return (Get-Date)
}

Export-ModuleMember -Function Get-BestTimestamp
