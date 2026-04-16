
#Requires -Version 5.1

function Get-TargetFolder {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [DateTime]$Timestamp,
        [Parameter(Mandatory)] [string]$DestinationRoot
    )

    $year      = $Timestamp.ToString("yyyy")
    $monthNum  = $Timestamp.ToString("MM")
    $monthName = $Timestamp.ToString("MMMM")
    $day       = $Timestamp.ToString("yyyy-MM-dd")

    return Join-Path $DestinationRoot "$year\$monthNum - $monthName\$day"
}

function Get-TargetBaseName {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [DateTime]$Timestamp
    )

    # Colons are illegal in Windows filenames; replace with hyphens.
    # Result format: YYYY-MM-DDTHH-mm-ss
    return $Timestamp.ToString("yyyy-MM-ddTHH-mm-ss")
}

function Resolve-SafeTargetPath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$TargetFolder,
        [Parameter(Mandatory)] [string]$BaseName,
        [Parameter(Mandatory)] [string]$Extension
    )

    $candidate = Join-Path $TargetFolder "$BaseName$Extension"
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    # First file has no suffix; subsequent files get _2, _3, ...
    $counter = 2
    do {
        $candidate = Join-Path $TargetFolder "${BaseName}_${counter}${Extension}"
        $counter++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

function Test-AlreadyProcessed {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [System.IO.FileInfo]$File,
        [Parameter(Mandatory)] [string]$DestinationRoot
    )

    # All five conditions must be true for a file to be considered processed:
    #
    #   1. Filename base matches  YYYY-MM-DDTHH-mm-ss[_N]
    #   2. Parent dir name matches YYYY-MM-DD
    #   3. Grandparent dir name matches MM - MonthName
    #   4. Great-grandparent dir name matches YYYY
    #   5. File lives somewhere under DestinationRoot

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    if ($baseName -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}(_\d+)?$') { return $false }

    $dayDir = Split-Path $File.DirectoryName -Leaf
    if ($dayDir -notmatch '^\d{4}-\d{2}-\d{2}$') { return $false }

    $monthDir = Split-Path (Split-Path $File.DirectoryName -Parent) -Leaf
    if ($monthDir -notmatch '^\d{2} - \w+$') { return $false }

    $yearDir = Split-Path (Split-Path (Split-Path $File.DirectoryName -Parent) -Parent) -Leaf
    if ($yearDir -notmatch '^\d{4}$') { return $false }

    $normFile = $File.FullName.ToLower().TrimEnd('\')
    $normDest = $DestinationRoot.ToLower().TrimEnd('\')

    return $normFile.StartsWith($normDest + '\')
}

Export-ModuleMember -Function Get-TargetFolder, Get-TargetBaseName, Resolve-SafeTargetPath, Test-AlreadyProcessed
