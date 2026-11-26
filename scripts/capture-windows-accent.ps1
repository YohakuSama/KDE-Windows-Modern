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

function Get-RegistryValue([string]$Path, [string]$Name) {
    $key = $null
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        $value = $key.GetValue($Name, $null)
        if ($null -eq $value) {
            return $null
        }
        if ($value -is [byte[]]) {
            return ,$value
        }
        return $value
    } catch {
        return $null
    } finally {
        if ($null -ne $key) {
            $key.Dispose()
        }
    }
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

    $accentPaletteBytes = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'AccentPalette'
    $accentPaletteHex = $null
    $accentPaletteLength = $null
    if ($accentPaletteBytes -is [byte[]]) {
        $accentPaletteLength = $accentPaletteBytes.Length
        $accentPaletteHex = [BitConverter]::ToString($accentPaletteBytes).Replace('-', '')
    }

    $registry = [ordered]@{
        control_panel_auto_colorization_raw = Get-RegistryValue 'HKCU:\Control Panel\Desktop' 'AutoColorization'
        themes_history_auto_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\History' 'AutoColor'
        dwm_accent_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\DWM' 'AccentColor'
        dwm_colorization_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorizationColor'
        explorer_accent_color_menu_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'AccentColorMenu'
        explorer_start_color_menu_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'StartColorMenu'
        accent_palette_length_bytes = $accentPaletteLength
        accent_palette_hex = $accentPaletteHex
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
        apps_use_light_theme = $appearance.AppsUseLightTheme
        system_uses_light_theme = $appearance.SystemUsesLightTheme
        transparency_raw = $appearance.EnableTransparency
        reported_display_width = $screens[0].Bounds.Width
        reported_display_height = $screens[0].Bounds.Height
        colors_argb = $palette
        registry = $registry
    }
}

# Reject a snapshot taken during an observed wallpaper or palette transition.
# This does not prove that a transition has already finished.
$first = Read-AccentSnapshot
Start-Sleep -Seconds 1
$second = Read-AccentSnapshot
if (($first | ConvertTo-Json -Depth 7 -Compress) -cne
    ($second | ConvertTo-Json -Depth 7 -Compress)) {
    throw 'Appearance changed during capture. Wait for the transition to finish and retry.'
}

$registryModes = @()
foreach ($value in @(
    $second.registry.control_panel_auto_colorization_raw,
    $second.registry.themes_history_auto_color_raw
)) {
    if ($null -eq $value) {
        continue
    }
    switch ([string]$value) {
        '0' { $registryModes += 'Manual' }
        '1' { $registryModes += 'Automatic' }
    }
}
$uniqueRegistryModes = @($registryModes | Select-Object -Unique)
$registryMode = $null
$registryModeConflict = $false
if ($uniqueRegistryModes.Count -eq 1) {
    $registryMode = $uniqueRegistryModes[0]
} elseif ($uniqueRegistryModes.Count -gt 1) {
    $registryModeConflict = $true
}

$accentObserved = $second['colors_argb']['Accent']
$manualColorObserved = $null
if ($registryMode -eq 'Manual') {
    $manualColorObserved = $accentObserved
}
if ($ManualColor) {
    $expectedManualColor = '#FF' + $ManualColor.Substring(1).ToUpperInvariant()
    if ($accentObserved -ne $expectedManualColor) {
        throw "ManualColor does not match the UISettings Accent value ($accentObserved)."
    }
}

[ordered]@{
    schema_version = 2
    windows_build = "$($build.CurrentBuildNumber).$($build.UBR)"
    display_version = $build.DisplayVersion
    accent_mode_argument = $AccentMode
    accent_mode_registry = $registryMode
    accent_mode_registry_conflict = $registryModeConflict
    manual_color_argument = $ManualColor
    accent_observed_from_ui_settings = $accentObserved
    manual_color_observed_from_ui_settings = $manualColorObserved
    appearance = $second
} | ConvertTo-Json -Depth 8
