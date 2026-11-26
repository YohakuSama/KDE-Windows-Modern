# SPDX-License-Identifier: GPL-3.0-or-later
# Optional reference collection in a disposable Windows VM, not a theme installer.
# Requires a static Picture background, one display and Automatic accent color.
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$ApplyTemporarily)

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

function Read-Capture([string]$Path) {
    $sample = & $captureScript -AccentMode Automatic -SourceWallpaper $Path | ConvertFrom-Json
    if ($sample.schema_version -lt 2) {
        throw 'Use capture-windows-accent.ps1 schema 2 or newer.'
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
    schema_version = 1
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
