# SPDX-License-Identifier: GPL-3.0-or-later
# Optional reference collection in a disposable Windows VM, not a theme installer.
# Requires a static Picture background, one display and Automatic accent color.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$ApplyTemporarily,
    [ValidateSet('Basic', 'Refinement', 'Extraction', 'Boundary')]
    [string]$ProbeSet = 'Basic',
    [switch]$IncludeNativeWallpaperColor
)

$ErrorActionPreference = 'Stop'
if (-not $ApplyTemporarily) {
    throw 'This collection temporarily changes the wallpaper. Use -ApplyTemporarily in the reference VM.'
}
$captureScript = Join-Path $PSScriptRoot 'capture-windows-accent.ps1'
if (-not (Test-Path -LiteralPath $captureScript -PathType Leaf)) {
    throw 'Place capture-windows-accent.ps1 (schema 2 or newer) beside this script.'
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$screens = [System.Windows.Forms.Screen]::AllScreens
if ($screens.Count -ne 1) {
    throw 'Use a single display.'
}
$width = $screens[0].Bounds.Width
$height = $screens[0].Bounds.Height
if ($width -lt 64 -or $height -lt 64 -or ([long]$width * $height) -gt 16000000) {
    throw 'Unsupported display size for the controlled images.'
}

# Only the first two IDesktopWallpaper methods are needed. Use the public
# interface, not registry writes or a private shell colorization function.
# https://learn.microsoft.com/windows/win32/api/shobjidl_core/nn-shobjidl_core-idesktopwallpaper
if (-not ('WindowsModern.Reference.Wallpaper' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace WindowsModern.Reference
{
    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IDesktopWallpaper
    {
        [PreserveSig]
        int SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor,
                         [MarshalAs(UnmanagedType.LPWStr)] string path);
        [PreserveSig]
        int GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor,
                         out IntPtr path);
    }

    public sealed class Wallpaper : IDisposable
    {
        private IDesktopWallpaper api = (IDesktopWallpaper)Activator.CreateInstance(
            Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")));

        public string GetPath()
        {
            IntPtr path = IntPtr.Zero;
            try
            {
                int hr = api.GetWallpaper(null, out path);
                Marshal.ThrowExceptionForHR(hr);
                if (hr != 0 || path == IntPtr.Zero)
                    throw new InvalidOperationException("Select a single static Picture background.");
                return Marshal.PtrToStringUni(path);
            }
            finally
            {
                if (path != IntPtr.Zero) Marshal.FreeCoTaskMem(path);
            }
        }

        public void SetPath(string path)
        {
            int hr = api.SetWallpaper(null, path);
            Marshal.ThrowExceptionForHR(hr);
            if (hr != 0) throw new InvalidOperationException("Wallpaper change did not return S_OK.");
        }

        public void Dispose()
        {
            if (api != null)
            {
                Marshal.ReleaseComObject(api);
                api = null;
            }
        }
    }
}
'@
}

function Read-Capture([string]$Path, [switch]$WithNativeWallpaperColor) {
    $captureArguments = @{
        AccentMode = 'Automatic'
        SourceWallpaper = $Path
    }
    if ($WithNativeWallpaperColor) {
        $captureArguments.IncludeNativeWallpaperColor = $true
    }
    $sample = & $captureScript @captureArguments | ConvertFrom-Json
    if ($sample.schema_version -lt 2) {
        throw 'Use capture-windows-accent.ps1 schema 2 or newer.'
    }
    if ($ProbeSet -in @('Refinement', 'Extraction', 'Boundary') -and $sample.schema_version -lt 4) {
        throw 'Refinement, Extraction and Boundary require capture-windows-accent.ps1 schema 4 or newer.'
    }
    if ($WithNativeWallpaperColor -and $sample.schema_version -lt 5) {
        throw 'Native wallpaper diagnostics require capture-windows-accent.ps1 schema 5 or newer.'
    }
    return $sample
}

function Assert-Automatic($Sample) {
    if ($Sample.accent_mode_registry -ne 'Automatic' -or $Sample.accent_mode_registry_conflict) {
        throw 'Select Automatic accent color in Windows Settings and keep that mode during collection.'
    }
}

function Palette-Key($Sample) {
    return ($Sample.appearance.colors_argb | ConvertTo-Json -Compress)
}

function Assert-Context($Sample, $Baseline) {
    Assert-Automatic $Sample
    if ($Sample.windows_build -ne $Baseline.windows_build) {
        throw 'Windows build changed during collection.'
    }
    foreach ($key in 'apps_use_light_theme', 'system_uses_light_theme', 'transparency_raw',
                      'wallpaper_style_raw', 'tile_wallpaper_raw',
                      'reported_display_width', 'reported_display_height') {
        if ($Sample.appearance.$key -ne $Baseline.appearance.$key) {
            throw "Appearance context changed: $key"
        }
    }
}

function Add-NativeWallpaperDiagnostic($Capture, [string]$Path, $Baseline) {
    if (-not $IncludeNativeWallpaperColor) {
        return $Capture
    }
    if ($desktop.GetPath() -ine $Path) {
        throw 'Wallpaper changed before the native COM diagnostic.'
    }
    # Invoke the private method once, only after the ordinary capture has
    # settled. Do not call it on every two-second polling iteration.
    $nativeCapture = Read-Capture $Path -WithNativeWallpaperColor
    Assert-Context $nativeCapture $Baseline
    if ($desktop.GetPath() -ine $Path) {
        throw 'Wallpaper changed during the native COM diagnostic.'
    }
    $expectedAppearance = $Capture.appearance | ConvertTo-Json -Depth 8 -Compress
    $observedAppearance = $nativeCapture.appearance | ConvertTo-Json -Depth 8 -Compress
    if ($observedAppearance -cne $expectedAppearance) {
        throw 'Appearance changed during the native COM diagnostic.'
    }
    $Capture.native_wallpaper_color_api = $nativeCapture.native_wallpaper_color_api
    return $Capture
}

function Palette-AgreesWithRegistry($Sample) {
    $roles = 'AccentLight3', 'AccentLight2', 'AccentLight1', 'Accent',
             'AccentDark1', 'AccentDark2', 'AccentDark3'
    $raw = $Sample.appearance.registry.accent_palette_hex
    if ($Sample.appearance.registry.accent_palette_length_bytes -ne 32 -or
        $raw -notmatch '^[0-9a-fA-F]{64}$') {
        return $false
    }
    for ($i = 0; $i -lt $roles.Count; $i++) {
        $value = $Sample.appearance.colors_argb.($roles[$i])
        if ($value -notmatch '^#FF[0-9a-fA-F]{6}$' -or
            $raw.Substring($i * 8, 6) -ine $value.Substring(3)) {
            return $false
        }
    }
    return $true
}

function New-ProbeImage([string]$Path, $Probe) {
    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($Probe.background))
            if ($Probe.rectangle) {
                $brush = [System.Drawing.SolidBrush]::new(
                    [System.Drawing.ColorTranslator]::FromHtml($Probe.rectangle.color))
                try {
                    $graphics.FillRectangle($brush, [int]$Probe.rectangle.x, [int]$Probe.rectangle.y,
                        [int]$Probe.rectangle.width, [int]$Probe.rectangle.height)
                } finally {
                    $brush.Dispose()
                }
            }
        } finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $bitmap.Dispose()
    }
}

function Read-Settled([string]$Path, $Previous, $Baseline) {
    $candidate = $null
    $signature = $null
    $stable = 0
    $lastError = ''
    # A new path can appear before the color service updates. Require two
    # matching captures and check the registered image and palette changes.
    # Unchanged values after the bounded observation window stay ambiguous.
    for ($i = 0; $i -lt 18; $i++) {
        Start-Sleep -Seconds 2
        if ($desktop.GetPath() -ine $Path) {
            $candidate = $null
            $signature = $null
            $stable = 0
            continue
        }
        try {
            $sample = Read-Capture $Path
        } catch {
            $lastError = $_.Exception.Message
            $candidate = $null
            $signature = $null
            $stable = 0
            continue
        }
        Assert-Context $sample $Baseline
        if ($desktop.GetPath() -ine $Path -or -not (Palette-AgreesWithRegistry $sample)) {
            $candidate = $null
            $signature = $null
            $stable = 0
            continue
        }
        $nextSignature = $sample.appearance | ConvertTo-Json -Depth 8 -Compress
        if ($nextSignature -ceq $signature) {
            $stable++
        } else {
            $stable = 1
            $signature = $nextSignature
        }
        $candidate = $sample
        if ($stable -ge 2 -and
            (Palette-Key $candidate) -cne (Palette-Key $Previous) -and
            $candidate.appearance.registered_wallpaper_sha256 -ne $Previous.appearance.registered_wallpaper_sha256) {
            break
        }
    }
    if ($stable -lt 2 -or $null -eq $candidate) {
        throw "Could not obtain consistent automatic palette data: $lastError"
    }
    return [ordered]@{
        capture = $candidate
        stable_captures = $stable
        palette_changed_since_previous = ((Palette-Key $candidate) -cne (Palette-Key $Previous))
        registered_wallpaper_changed_since_previous = (
            $candidate.appearance.registered_wallpaper_sha256 -ne $Previous.appearance.registered_wallpaper_sha256)
    }
}

$desktop = [WindowsModern.Reference.Wallpaper]::new()
$attempted = $false
$reportPath = $null
$probePaths = @()
$probeHashes = @{}
$report = [ordered]@{
    schema_version = 2
    probe_set = $ProbeSet
    description = 'Controlled Windows automatic accent observations. Unchanged palette/image evidence is inconclusive.'
    baseline = $null
    samples = @()
    restoration = $null
}
try {
    $original = $desktop.GetPath()
    if (-not $original -or -not (Test-Path -LiteralPath $original -PathType Leaf)) {
        throw 'Select an existing static Picture wallpaper.'
    }
    $baseline = Read-Capture $original
    Assert-Automatic $baseline
    if ($desktop.GetPath() -ine $original -or -not (Palette-AgreesWithRegistry $baseline)) {
        throw 'The original wallpaper or palette is not stable.'
    }
    $baseline = Add-NativeWallpaperDiagnostic $baseline $original $baseline
    $report.baseline = $baseline

    $folder = Join-Path $PSScriptRoot ('wallpaper-probes-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
    New-Item -ItemType Directory -Path $folder | Out-Null
    $reportPath = Join-Path $folder 'wallpaper-probes.json'
    # Kept locally for recovery only. Never included in the shared JSON.
    $original | Set-Content -LiteralPath (Join-Path $folder 'restore-original-path.txt') -Encoding UTF8
    $rw = [int][Math]::Floor($width / 2)
    $rh = [int][Math]::Floor($height / 2)
    $cx = [int][Math]::Floor(($width - $rw) / 2)
    $cy = [int][Math]::Floor(($height - $rh) / 2)
    if ($ProbeSet -eq 'Refinement') {
        # The Basic samples established the shade stage. These vary one
        # image property at a time relative to the archived Basic inputs.
        # Interleave distinct hues to reduce unchanged-palette ambiguity.
        $probes = @(
            @{name='purple-dark'; background='#512E48'; rectangle=$null},
            @{name='purple-muted-05'; background='#83767F'; rectangle=$null},
            @{name='quarter-orange'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='purple-bright'; background='#D1AEC7'; rectangle=$null},
            @{name='purple-muted-12'; background='#8B6E83'; rectangle=$null},
            @{name='half-purple'; background='#FF8C00'; rectangle=@{
                color='#9F5A8C'; x=0; y=0; width=$rw; height=$height}},
            @{name='purple-strong'; background='#C1389B'; rectangle=$null},
            @{name='small-orange-on-gray'; background='#808482'; rectangle=@{
                color='#FF8C00'; x=0; y=0;
                width=[int][Math]::Floor($width / 4);
                height=[int][Math]::Floor($height / 4)}}
        )
    } elseif ($ProbeSet -eq 'Extraction') {
        # Hold approximate CIELAB lightness near 50. The vivid red, green
        # and blue also share HSL saturation 0.75; muted red keeps the hue
        # while reducing HSL saturation to 0.15. Mixed probes vary only
        # color proportion or rectangle position.
        $quarterWidth = [int][Math]::Floor($width / 4)
        $quarterHeight = [int][Math]::Floor($height / 4)
        $halfPercentWidth = [int][Math]::Floor($width / 14)
        $halfPercentHeight = [int][Math]::Floor($height / 14)
        $onePercentWidth = [int][Math]::Floor($width / 10)
        $onePercentHeight = [int][Math]::Floor($height / 10)
        $twoPercentWidth = [int][Math]::Floor($width / 7)
        $twoPercentHeight = [int][Math]::Floor($height / 7)
        $fourPercentWidth = [int][Math]::Floor($width / 5)
        $fourPercentHeight = [int][Math]::Floor($height / 5)
        $probes = @(
            @{name='solid-red-vivid'; background='#E13030'; rectangle=$null},
            @{name='solid-green-vivid'; background='#148A14'; rectangle=$null},
            @{name='solid-blue-vivid'; background='#6767E9'; rectangle=$null},
            @{name='solid-red-muted'; background='#936E6E'; rectangle=$null},
            # The patent lead describes a 1% minimum bucket population.
            # These orange patches are tested against a second chromatic
            # bucket so the denominator remains the non-filtered image area.
            @{name='orange-half-percent-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=$halfPercentWidth; height=$halfPercentHeight}},
            @{name='orange-one-percent-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=$onePercentWidth; height=$onePercentHeight}},
            @{name='orange-two-percent-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=$twoPercentWidth; height=$twoPercentHeight}},
            @{name='orange-four-percent-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=$fourPercentWidth; height=$fourPercentHeight}},
            @{name='vivid-red-small-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$quarterWidth; height=$quarterHeight}},
            @{name='vivid-red-quarter-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='vivid-red-half-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$rw; height=$height}},
            @{name='vivid-red-dominant-on-muted-red'; background='#E13030'; rectangle=@{
                color='#936E6E'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='red-quarter-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='red-dominant-on-green'; background='#E13030'; rectangle=@{
                color='#148A14'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='red-quarter-corner-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$rw; height=$rh}}
        )
    } elseif ($ProbeSet -eq 'Boundary') {
        # Bracket the population * channel-span tie points inferred from
        # the completed Extraction set. These are hypotheses, not constants.
        # Three solid red shades also distinguish native alpha offsets 124/125.
        $probes = @(
            @{name='solid-red-span-37'; background='#936E6E'; rectangle=$null},
            @{name='solid-red-span-48'; background='#936363'; rectangle=$null},
            @{name='solid-red-span-50'; background='#946262'; rectangle=$null},
            @{name='red-15pct-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.15); height=$height}},
            @{name='red-17_5pct-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.175); height=$height}},
            @{name='red-20pct-on-muted-red'; background='#936E6E'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.20); height=$height}},
            @{name='orange-20pct-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=[int][Math]::Floor($width * 0.20); height=$height}},
            @{name='orange-21_25pct-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=[int][Math]::Floor($width * 0.2125); height=$height}},
            @{name='orange-22_5pct-on-purple'; background='#9F5A8C'; rectangle=@{
                color='#FF8C00'; x=0; y=0; width=[int][Math]::Floor($width * 0.225); height=$height}},
            @{name='red-37_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.375); height=$height}},
            @{name='red-40pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='red-42_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.425); height=$height}}
        )
    } else {
        $probes = @(
            @{name='solid-purple'; background='#9F5A8C'; rectangle=$null},
            @{name='solid-orange'; background='#FF8C00'; rectangle=$null},
            @{name='center-purple'; background='#FF8C00'; rectangle=@{
                color='#9F5A8C'; x=$cx; y=$cy; width=$rw; height=$rh}},
            @{name='solid-gray'; background='#808482'; rectangle=$null},
            @{name='corner-purple'; background='#FF8C00'; rectangle=@{
                color='#9F5A8C'; x=0; y=0; width=$rw; height=$rh}},
            @{name='solid-blue'; background='#2475CE'; rectangle=$null}
        )
    }
    foreach ($probe in $probes) {
        $path = Join-Path $folder ($probe.name + '.bmp')
        New-ProbeImage $path $probe
        $probePaths += $path
        $probeHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }

    $previous = $baseline
    foreach ($probe in $probes) {
        $path = Join-Path $folder ($probe.name + '.bmp')
        $active = $desktop.GetPath()
        if ($active -ine $original -and $probePaths -inotcontains $active) {
            throw 'Wallpaper changed outside this collection.'
        }
        $expectedHash = $probeHashes[$path]
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'Probe image bytes changed before applying the wallpaper.'
        }
        Write-Host ('Collecting ' + $probe.name)
        $attempted = $true
        $desktop.SetPath($path)
        $result = Read-Settled $path $previous $baseline
        $result.capture = Add-NativeWallpaperDiagnostic $result.capture $path $baseline
        if ($result.capture.appearance.source_wallpaper_sha256 -ne $expectedHash -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'Probe image bytes changed.'
        }
        $report.samples += [ordered]@{
            image = $probe
            width = $width
            height = $height
            observation = $result
        }
        $previous = $result.capture
        $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    }
} finally {
    try {
        if ($attempted) {
            $active = $desktop.GetPath()
            if ($active -ine $original -and $probePaths -inotcontains $active) {
                throw 'Wallpaper changed outside this collection. Restore the saved original path manually.'
            }
            $desktop.SetPath($original)
            $restored = Read-Settled $original $previous $baseline
            $restored.capture = Add-NativeWallpaperDiagnostic $restored.capture $original $baseline
            $report.restoration = [ordered]@{
                wallpaper_path_verified = ($desktop.GetPath() -ieq $original)
                palette_matches_baseline = ((Palette-Key $restored.capture) -ceq (Palette-Key $baseline))
                observation = $restored
            }
        }
    } catch {
        $report.restoration = [ordered]@{
            wallpaper_path_verified = $false
            error = 'Restoration could not be verified; details were written to the local console.'
        }
        Write-Warning $_.Exception.Message
        Write-Warning 'Automatic restoration could not be verified. See restore-original-path.txt.'
    } finally {
        $desktop.Dispose()
        if ($reportPath) {
            $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $reportPath -Encoding UTF8
            Write-Host ("Report: " + $reportPath)
        }
    }
}
if (-not $report.restoration.wallpaper_path_verified) {
    throw 'Wallpaper restoration was not verified.'
}
if (-not $report.restoration.palette_matches_baseline) {
    Write-Warning 'The original wallpaper was restored, but its baseline palette was not reproduced during observation.'
}
