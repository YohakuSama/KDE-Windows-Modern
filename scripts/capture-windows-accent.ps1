# SPDX-License-Identifier: GPL-3.0-or-later
# Reference capture. The optional private shell query may refresh its internal cache.
# Run in the interactive Windows desktop.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Automatic', 'Manual')]
    [string]$AccentMode,

    [string]$SourceWallpaper,

    [ValidatePattern('^#[0-9a-fA-F]{6}$')]
    [string]$ManualColor,

    [switch]$IncludeNativeWallpaperColor,

    [switch]$ManualPaletteBatch,

    [ValidatePattern('^#[0-9a-fA-F]{6}$')]
    [string[]]$BatchColors
)

$ErrorActionPreference = 'Stop'

if ($ManualColor -and $AccentMode -ne 'Manual') {
    throw 'ManualColor is only valid for a manually selected accent.'
}
if ($ManualPaletteBatch -and ($AccentMode -ne 'Manual' -or $ManualColor -or
        $IncludeNativeWallpaperColor -or $SourceWallpaper)) {
    throw 'ManualPaletteBatch requires Manual mode without ManualColor, SourceWallpaper or the native wallpaper query.'
}
if ($BatchColors -and -not $ManualPaletteBatch) {
    throw 'BatchColors requires ManualPaletteBatch.'
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
        desktop_image_color_raw = Get-RegistryValue 'HKCU:\Control Panel\Desktop' 'ImageColor'
        themes_history_auto_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\History' 'AutoColor'
        dwm_accent_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\DWM' 'AccentColor'
        dwm_colorization_color_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorizationColor'
        dwm_colorization_afterglow_raw = Get-RegistryValue 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorizationAfterglow'
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


function Format-RegistryDword([object]$Value) {
    if ($null -eq $Value) {
        return $null
    }
    $bytes = [BitConverter]::GetBytes([int32]$Value)
    return '0x{0:X8}' -f [BitConverter]::ToUInt32($bytes, 0)
}

function Format-RegistryRgb([object]$Value) {
    if ($null -eq $Value) {
        return $null
    }
    $bytes = [BitConverter]::GetBytes([int32]$Value)
    $unsigned = [BitConverter]::ToUInt32($bytes, 0)
    return '0x{0:X6}' -f ($unsigned -band 0x00FFFFFF)
}

function Get-NativeWallpaperColor($Sample, [string]$Mode, [bool]$ModeConflict) {
    $result = [ordered]@{
        status = 'not_requested'
        hresult = $null
        argb = $null
        alpha = $null
        image_color_argb = $null
        image_color_alpha = $null
        image_color_after_api_argb = $null
        image_color_changed_by_api = $null
        argb_matches_image_color = $null
        alpha_matches_image_color = $null
        argb_matches_image_color_after_api = $null
        alpha_matches_image_color_after_api = $null
        rgb_matches_image_color = $null
        rgb_matches_dwm_colorization = $null
        error_type = $null
    }
    if (-not $IncludeNativeWallpaperColor) {
        return $result
    }
    if ($Mode -ne 'Automatic' -or $ModeConflict) {
        $result.status = 'skipped_unverified_automatic_mode'
        return $result
    }

    try {
        if (-not ('WindowsModern.Reference.NativeWallpaperColor' -as [type])) {
            Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WindowsModern.Reference
{
    // Reverse-engineered private shell32 interface. Slots 0..18 are the
    // public IDesktopWallpaper vtable; private methods occupy slots 19..24.
    // Only ComputeImageColorizationColor (slot 21) is invoked here.
    [ComImport, Guid("C182461F-DFAC-4375-AB6E-4CC45AA7F9CC"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IDesktopWallpaperPrivate
    {
        [PreserveSig] int SetWallpaper(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor,
            [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [PreserveSig] int GetWallpaper(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor, out IntPtr wallpaper);
        [PreserveSig] int GetMonitorDevicePathAt(uint index, out IntPtr monitor);
        [PreserveSig] int GetMonitorDevicePathCount(out uint count);
        [PreserveSig] int GetMonitorRECT(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor, IntPtr rect);
        [PreserveSig] int SetBackgroundColor(uint color);
        [PreserveSig] int GetBackgroundColor(out uint color);
        [PreserveSig] int SetPosition(int position);
        [PreserveSig] int GetPosition(out int position);
        [PreserveSig] int SetSlideshow(IntPtr items);
        [PreserveSig] int GetSlideshow(out IntPtr items);
        [PreserveSig] int SetSlideshowOptions(int options, uint interval);
        [PreserveSig] int GetSlideshowOptions(out int options, out uint interval);
        [PreserveSig] int AdvanceSlideshow(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor, int direction);
        [PreserveSig] int GetStatus(out int state);
        [PreserveSig] int Enable(int enabled);

        [PreserveSig] int SetWallpaperNoGP(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor,
            [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [PreserveSig] int PaintWallpaperThumbnail(long dc, int width, int height);
        [PreserveSig] int ComputeImageColorizationColor(out uint color);
        [PreserveSig] int GetMonitorNumber(
            [MarshalAs(UnmanagedType.LPWStr)] string monitor, out uint number);
        [PreserveSig] int Flush();
        [PreserveSig] int PaintWallpaperBitmapFromShellTask();
    }

    public static class NativeWallpaperColor
    {
        [DllImport("ole32.dll", PreserveSig = true)]
        private static extern int CoCreateInstance(
            ref Guid clsid, IntPtr outer, uint context, ref Guid iid, out IntPtr instance);

        public static int Get(out uint color)
        {
            color = 0;
            IntPtr pointer = IntPtr.Zero;
            object instance = null;
            try
            {
                var clsid = new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD");
                var iid = new Guid("C182461F-DFAC-4375-AB6E-4CC45AA7F9CC");
                int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 0x4, ref iid, out pointer);
                if (hr < 0) return hr;
                instance = Marshal.GetObjectForIUnknown(pointer);
                var wallpaper = (IDesktopWallpaperPrivate)instance;
                return wallpaper.ComputeImageColorizationColor(out color);
            }
            catch (Exception error)
            {
                color = 0;
                return Marshal.GetHRForException(error);
            }
            finally
            {
                if (instance != null && Marshal.IsComObject(instance))
                {
                    try { Marshal.ReleaseComObject(instance); }
                    catch { }
                }
                if (pointer != IntPtr.Zero)
                {
                    try { Marshal.Release(pointer); }
                    catch { }
                }
            }
        }
    }
}
'@
        }

        [uint32]$nativeArgb = 0
        $hr = [WindowsModern.Reference.NativeWallpaperColor]::Get([ref]$nativeArgb)
        $result.hresult = '0x{0:X8}' -f [BitConverter]::ToUInt32(
            [BitConverter]::GetBytes([int32]$hr), 0)
        if ($hr -lt 0) {
            $result.status = 'native_api_failed'
            return $result
        }

        $nativeHex = '0x{0:X8}' -f $nativeArgb
        $nativeRgb = '0x{0:X6}' -f ($nativeArgb -band 0x00FFFFFF)
        $nativeAlpha = [int](($nativeArgb -shr 24) -band 0xFF)
        $imageHex = Format-RegistryDword $Sample.registry.desktop_image_color_raw
        $imageRgb = Format-RegistryRgb $Sample.registry.desktop_image_color_raw
        $imageAfterHex = Format-RegistryDword (
            Get-RegistryValue 'HKCU:\Control Panel\Desktop' 'ImageColor')
        $dwmRgb = Format-RegistryRgb $Sample.registry.dwm_colorization_color_raw
        $imageAlpha = $null
        $imageAfterAlpha = $null
        if ($null -ne $imageHex) {
            $imageAlpha = [Convert]::ToInt32($imageHex.Substring(2, 2), 16)
        }
        if ($null -ne $imageAfterHex) {
            $imageAfterAlpha = [Convert]::ToInt32($imageAfterHex.Substring(2, 2), 16)
        }

        $result.status = 'ok'
        $result.argb = $nativeHex
        $result.alpha = $nativeAlpha
        $result.image_color_argb = $imageHex
        $result.image_color_alpha = $imageAlpha
        $result.image_color_after_api_argb = $imageAfterHex
        if ($null -ne $imageHex -and $null -ne $imageAfterHex) {
            $result.image_color_changed_by_api = $imageHex -ne $imageAfterHex
        }
        if ($null -ne $imageHex) {
            $result.argb_matches_image_color = $nativeHex -eq $imageHex
            $result.alpha_matches_image_color = $nativeAlpha -eq $imageAlpha
            $result.rgb_matches_image_color = $nativeRgb -eq $imageRgb
        }
        if ($null -ne $imageAfterHex) {
            $result.argb_matches_image_color_after_api = $nativeHex -eq $imageAfterHex
            $result.alpha_matches_image_color_after_api = $nativeAlpha -eq $imageAfterAlpha
        }
        if ($null -ne $dwmRgb) {
            $result.rgb_matches_dwm_colorization = $nativeRgb -eq $dwmRgb
        }
    } catch {
        $result.status = 'native_api_unavailable'
        $result.error_type = $_.Exception.GetType().FullName
        if ($null -eq $result.hresult) {
            $result.hresult = Format-RegistryDword $_.Exception.HResult
        }
    }
    return $result
}

function Read-AccentCapture([string]$RequestedColor) {
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
    # The entered color may be normalized by Windows. Preserve both values
    # instead of rejecting exactly the samples needed to study normalization.
    $manualColorMatches = $null
    if ($RequestedColor) {
        $expectedManualColor = '#FF' + $RequestedColor.Substring(1).ToUpperInvariant()
        $manualColorMatches = $accentObserved -eq $expectedManualColor
    }

    $nativeWallpaperColor = Get-NativeWallpaperColor $second $registryMode $registryModeConflict

    return [ordered]@{
        schema_version = 5
        windows_build = "$($build.CurrentBuildNumber).$($build.UBR)"
        display_version = $build.DisplayVersion
        accent_mode_argument = $AccentMode
        accent_mode_registry = $registryMode
        accent_mode_registry_conflict = $registryModeConflict
        manual_color_argument = $RequestedColor
        manual_color_matches_observed = $manualColorMatches
        native_wallpaper_color_api = $nativeWallpaperColor
        accent_observed_from_ui_settings = $accentObserved
        manual_color_observed_from_ui_settings = $manualColorObserved
        appearance = $second
    }
}

function Test-PaletteRegistryAgreement($Sample) {
    $roles = 'AccentLight3', 'AccentLight2', 'AccentLight1', 'Accent',
             'AccentDark1', 'AccentDark2', 'AccentDark3'
    $raw = $Sample.appearance.registry.accent_palette_hex
    if ($Sample.appearance.registry.accent_palette_length_bytes -ne 32 -or
        $raw -notmatch '^[0-9A-Fa-f]{64}$') {
        return $false
    }
    for ($i = 0; $i -lt $roles.Count; $i++) {
        $value = $Sample.appearance.colors_argb.($roles[$i])
        if ($value -notmatch '^#FF[0-9A-Fa-f]{6}$' -or
            $raw.Substring($i * 8, 6) -ine $value.Substring(3)) {
            return $false
        }
    }
    return $true
}

if (-not $ManualPaletteBatch) {
    Read-AccentCapture $ManualColor | ConvertTo-Json -Depth 8
    return
}

# No settings or registry writes. Collect the remaining preset rows and
# independent samples immediately around the custom HSL/LAB boundaries.
# Keep all requested values distinct from normalized Windows output.
if ("$($build.CurrentBuildNumber).$($build.UBR)" -ne '26300.9974') {
    throw 'Use the project reference Windows build 26300.9974 for this batch.'
}
$presets = @(
        '#0063B1', '#0078D4', '#0099BC', '#00B294', '#00B7C3', '#00CC6A',
        '#018574', '#038387', '#107C10', '#10893E', '#2D7D9A', '#486860',
        '#498205', '#4A5459', '#4C4A48', '#515C6B', '#525E54', '#567C73',
        '#5D5A58', '#647C64', '#68768A', '#69797E', '#6B69D6', '#744DA9',
        '#767676', '#7A7574', '#7E735F', '#847545', '#8764B8', '#881798',
        '#8E8CD8', '#9A0089', '#B146C2', '#BF0077', '#C239B3', '#C30052',
        '#CA5010', '#D13438', '#DA3B01', '#E3008C', '#E74856', '#E81123',
        '#EA005E', '#EF6950', '#F7630C', '#FF4343', '#FF8C00', '#FFB900'
)
$boundaries = @(
    '#7F0000', '#800000', '#FF7F7F', '#FF8080',
    '#897866', '#8A7866', '#8B7866',
    '#3F3F3F', '#404040', '#7F7F7F', '#808080', '#BFBFBF', '#C0C0C0'
)
$targets = if ($BatchColors) {
    @($BatchColors | ForEach-Object { $_.ToUpperInvariant() } | Select-Object -Unique)
} else {
    @($presets | Where-Object { $_ -notin @('#0078D4', '#FF8C00') }) + $boundaries
}
$report = [ordered]@{
    schema_version = 1
    windows_build = "$($build.CurrentBuildNumber).$($build.UBR)"
    display_version = $build.DisplayVersion
    probe_set = 'ManualPaletteBatch'
    requested_colors = @($targets)
    samples = @()
    skipped_colors = @()
    completed = $false
}
$desktopPath = [Environment]::GetFolderPath('DesktopDirectory')
$reportPath = Join-Path $desktopPath ('windows-accent-batch-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (Test-Path -LiteralPath $reportPath) {
    throw 'The batch report already exists.'
}
function Save-PaletteBatch {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}
Save-PaletteBatch
Write-Host 'Open Settings > Personalization > Colors and choose Manual accent color.'
Write-Host 'Select the requested preset tile or enter the custom color exactly. The script does not change or restore settings.'
Write-Host ('Report: ' + $reportPath)
$stop = $false
foreach ($target in $targets) {
    $preset = $target -in $presets
    $kind = if ($preset) { 'preset tile' } else { 'custom RGB' }
    while ($true) {
        $answer = Read-Host ("Select {0} {1}, then Enter; S skips, Q saves and quits" -f $kind, $target)
        if ($answer -ieq 'Q') {
            $stop = $true
            break
        }
        if ($answer -ieq 'S') {
            $report.skipped_colors += $target
            break
        }
        if ($answer -ne '') {
            continue
        }
        try {
            $sample = Read-AccentCapture $target
            if ($sample.accent_mode_registry -ne 'Manual' -or
                $sample.accent_mode_registry_conflict -or
                -not (Test-PaletteRegistryAgreement $sample)) {
                throw 'Manual mode or the seven UISettings/registry roles could not be verified.'
            }
            if ($preset -and -not $sample.manual_color_matches_observed) {
                throw 'Observed base does not match the requested preset.'
            }
        } catch {
            Write-Warning $_.Exception.Message
            continue
        }
        $report.samples += [ordered]@{
            requested_color = $target
            input_kind = if ($preset) { 'preset' } else { 'custom' }
            input_confirmed_by_operator = $true
            capture = $sample
        }
        break
    }
    Save-PaletteBatch
    if ($stop) {
        break
    }
}
$report.completed = -not $stop -and $report.skipped_colors.Count -eq 0 -and
                    $report.samples.Count -eq $targets.Count
Save-PaletteBatch
Write-Host ("Saved {0}/{1} captures: {2}" -f $report.samples.Count, $targets.Count, $reportPath)
