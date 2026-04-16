
#Requires -Version 5.1

function Get-OrganizerConfig {
    param(
        [string]$ConfigPath     = "",
        [string]$OverrideSource = "",
        [string]$OverrideDest   = ""
    )

    $projectRoot = Split-Path $PSScriptRoot -Parent
    $defaultScreenshots = Join-Path ([Environment]::GetFolderPath('MyPictures')) "Screenshots"

    $config = [ordered]@{
        SourceFolder        = $defaultScreenshots
        DestinationRoot     = $defaultScreenshots
        SupportedExtensions = @(".png", ".jpg", ".jpeg", ".webp")
        LogFolder           = Join-Path $projectRoot "logs"
        UndoFolder          = Join-Path $projectRoot "undo"
    }

    if ($ConfigPath -ne "" -and (Test-Path -LiteralPath $ConfigPath)) {
        try {
            $json = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $json.PSObject.Properties) {
                $config[$prop.Name] = $prop.Value
            }
        }
        catch {
            Write-Warning "Could not parse config file '$ConfigPath': $_. Using defaults."
        }
    }

    if ($OverrideSource -ne "") { $config['SourceFolder']    = $OverrideSource }
    if ($OverrideDest   -ne "") { $config['DestinationRoot'] = $OverrideDest   }

    # Normalize extension list to lowercase strings regardless of source
    $config['SupportedExtensions'] = @(
        $config['SupportedExtensions'] | ForEach-Object { $_.ToString().ToLower() }
    )

    return $config
}

Export-ModuleMember -Function Get-OrganizerConfig
