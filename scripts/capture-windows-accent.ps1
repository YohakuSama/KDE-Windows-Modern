# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only reference capture. Run in the interactive Windows desktop.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Automatic', 'Manual')]
    [string]$AccentMode,

    [string]$SourceWallpaper,

    [ValidatePattern('^#[0-9a-fA-F]{6}$')]
    [string]$ManualColor
)

$ErrorActionPreference = 'Stop'

if ($ManualColor -and $AccentMode -ne 'Manual') {
    throw 'ManualColor is only valid for a manually selected accent.'
}

Add-Type -AssemblyName System.Windows.Forms
$ui = [Windows.UI.ViewManagement.UISettings, Windows.UI.ViewManagement, ContentType=WindowsRuntime]::new()
$colorType = [Windows.UI.ViewManagement.UIColorType, Windows.UI.ViewManagement, ContentType=WindowsRuntime]
$build = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

function Get-ImageHash([string]$Path) {
    if (-not $Path) {
        throw 'Select a static picture as the desktop background first.'
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    return (Get-FileHash -LiteralPath $expanded -Algorithm SHA256).Hash
}

function Read-AccentSnapshot {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if ($screens.Count -ne 1) {
        throw 'Use a single display for this reference capture.'
    }
    $desktop = Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop'
    $appearance = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $palette = [ordered]@{}
    foreach ($name in 'Accent', 'AccentDark1', 'AccentDark2', 'AccentDark3',
                      'AccentLight1', 'AccentLight2', 'AccentLight3',
                      'Background', 'Foreground') {
        $value = $ui.GetColorValue([System.Enum]::Parse($colorType, $name))
        $palette[$name] = '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $value.A, $value.R, $value.G, $value.B
    }
    $sourceHash = $null
    if ($SourceWallpaper) {
        $sourceHash = Get-ImageHash $SourceWallpaper
    }

    return [ordered]@{
        registered_wallpaper_sha256 = (Get-ImageHash $desktop.WallPaper)
        source_wallpaper_sha256 = $sourceHash
        wallpaper_style_raw = $desktop.WallpaperStyle
        tile_wallpaper_raw = $desktop.TileWallpaper
        auto_colorization_raw = $desktop.AutoColorization
        apps_use_light_theme = $appearance.AppsUseLightTheme
        system_uses_light_theme = $appearance.SystemUsesLightTheme
        transparency_raw = $appearance.EnableTransparency
        reported_display_width = $screens[0].Bounds.Width
        reported_display_height = $screens[0].Bounds.Height
        colors_argb = $palette
    }
}

# Reject a snapshot taken during an observed wallpaper or palette transition.
# This does not prove that a transition has already finished.
$first = Read-AccentSnapshot
Start-Sleep -Seconds 1
$second = Read-AccentSnapshot
if (($first | ConvertTo-Json -Depth 5 -Compress) -cne
    ($second | ConvertTo-Json -Depth 5 -Compress)) {
    throw 'Appearance changed during capture. Wait for the transition to finish and retry.'
}

[ordered]@{
    schema_version = 1
    windows_build = "$($build.CurrentBuildNumber).$($build.UBR)"
    display_version = $build.DisplayVersion
    accent_mode_reported_by_operator = $AccentMode
    manual_color_reported_by_operator = $ManualColor
    appearance = $second
} | ConvertTo-Json -Depth 6
