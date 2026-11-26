# SPDX-License-Identifier: GPL-3.0-or-later
# Optional reference collection in a disposable Windows VM, not a theme installer.
# Requires a static Picture background, one display and Automatic accent color.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$ApplyTemporarily,
    [ValidateSet('Basic', 'Refinement', 'Extraction', 'Boundary', 'Scoring', 'ScoringRefinement', 'CacheIsolation', 'BitmapBoundary')]
    [string]$ProbeSet = 'Basic',
    [switch]$IncludeNativeWallpaperColor
)

$ErrorActionPreference = 'Stop'
if (-not $ApplyTemporarily) {
    throw 'This collection temporarily changes the wallpaper. Use -ApplyTemporarily in the reference VM.'
}
$isolated = $ProbeSet -in @('CacheIsolation', 'BitmapBoundary')
if ($isolated -and -not $IncludeNativeWallpaperColor) {
    throw 'CacheIsolation and BitmapBoundary require -IncludeNativeWallpaperColor.'
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
if ($ProbeSet -eq 'BitmapBoundary' -and ($width -ne 1280 -or $height -ne 800)) {
    throw 'BitmapBoundary reproduces the recorded 1280x800 reference. Set that display size before collecting.'
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

# Public WIC recreation for unrotated synthetic probes only.
# This is not an interception of shell32's internal bitmap.
if ($ProbeSet -eq 'BitmapBoundary' -and -not ('WindowsModern.Reference.WicBoundary' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;

namespace WindowsModern.Reference
{
    // The inherited bitmap-source slots are explicitly repeated for COM.
    [ComImport, Guid("00000120-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicSource
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size,
            [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex=2)] byte[] pixels);
    }

    [ComImport, Guid("3b16811b-6a43-4ec9-a813-3d930c13b940"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicFrame
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size,
            [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex=2)] byte[] pixels);
    }

    [ComImport, Guid("00000302-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicScaler
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size,
            [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex=2)] byte[] pixels);
        void Initialize(IWicSource source, uint width, uint height, uint mode);
    }

    [ComImport, Guid("00000301-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicConverter
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size,
            [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex=2)] byte[] pixels);
        void Initialize(IWicSource source, ref Guid format, uint dither,
                        IntPtr palette, double alphaThreshold, uint paletteType);
    }

    // Unused slots preserve SDK vtable order and are never invoked.
    [ComImport, Guid("9edde9e7-8dee-47ea-99df-e6faf2ed44bf"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicDecoder
    {
        void ReservedQueryCapability();
        void ReservedInitialize();
        void ReservedGetContainerFormat();
        void ReservedGetDecoderInfo();
        void ReservedCopyPalette();
        void ReservedGetMetadataQueryReader();
        void ReservedGetPreview();
        void ReservedGetColorContexts();
        void ReservedGetThumbnail();
        void GetFrameCount(out uint count);
        void GetFrame(uint index, out IWicFrame frame);
    }

    [ComImport, Guid("ec5ec8a9-c395-4314-9c77-54d7a935ff70"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicFactory
    {
        void ReservedCreateDecoderFromFilename();
        void CreateDecoderFromStream(IStream stream, IntPtr vendor, uint options,
                                     out IWicDecoder decoder);
        void ReservedCreateDecoderFromFileHandle();
        void ReservedCreateComponentInfo();
        void ReservedCreateDecoder();
        void ReservedCreateEncoder();
        void ReservedCreatePalette();
        void CreateFormatConverter(out IWicConverter converter);
        void CreateBitmapScaler(out IWicScaler scaler);
    }

    public sealed class WicBuffer
    {
        public uint SourceWidth, SourceHeight, Width, Height;
        public string Sha256, GzipBase64;
    }

    public static class WicBoundary
    {
        [DllImport("shlwapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
        private static extern int SHCreateStreamOnFileEx(
            string path, uint mode, uint attributes,
            [MarshalAs(UnmanagedType.Bool)] bool create, IStream template,
            out IStream stream);

        public static WicBuffer Read(string path)
        {
            IStream stream = null;
            IWicFactory factory = null;
            IWicDecoder decoder = null;
            IWicFrame frame = null;
            IWicScaler scaler = null;
            IWicConverter converter = null;
            try
            {
                // STGM_READ | STGM_SHARE_DENY_WRITE.
                Marshal.ThrowExceptionForHR(SHCreateStreamOnFileEx(path, 0x20, 0,
                    false, null, out stream));
                factory = (IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(
                    new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                factory.CreateDecoderFromStream(stream, IntPtr.Zero, 0, out decoder);
                decoder.GetFrame(0, out frame);
                uint sw, sh;
                frame.GetSize(out sw, out sh);
                if (sw != 1280 || sh != 800)
                    throw new InvalidDataException("Unexpected WIC source dimensions.");
                uint w = Math.Min(256u, sw), h = Math.Min(256u, sh);
                factory.CreateBitmapScaler(out scaler);
                // The target shell passes WICBitmapInterpolationModeLinear (1).
                scaler.Initialize((IWicSource)frame, w, h, 1);
                factory.CreateFormatConverter(out converter);
                Guid format = new Guid("6fddc324-4e03-4bfe-b185-3d77768dc90e");
                converter.Initialize((IWicSource)scaler, ref format, 0, IntPtr.Zero, 0, 0);
                Guid actual;
                converter.GetPixelFormat(out actual);
                uint cw, ch;
                converter.GetSize(out cw, out ch);
                if (actual != format || cw != w || ch != h)
                    throw new InvalidDataException("Unexpected converted WIC bitmap.");
                byte[] pixels = new byte[checked((int)(w * h * 4))];
                converter.CopyPixels(IntPtr.Zero, w * 4, (uint)pixels.Length, pixels);
                string hash;
                using (var sha = SHA256.Create())
                    hash = BitConverter.ToString(sha.ComputeHash(pixels)).Replace("-", "");
                string compressed;
                using (var memory = new MemoryStream())
                {
                    using (var gzip = new GZipStream(memory, CompressionMode.Compress, true))
                        gzip.Write(pixels, 0, pixels.Length);
                    compressed = Convert.ToBase64String(memory.ToArray());
                }
                return new WicBuffer { SourceWidth=sw, SourceHeight=sh,
                    Width=w, Height=h, Sha256=hash, GzipBase64=compressed };
            }
            finally
            {
                foreach (object item in new object[] { converter, scaler, frame, decoder, factory, stream })
                    if (item != null) Marshal.ReleaseComObject(item);
            }
        }
    }
}
'@
}

function Read-WicBoundaryBuffer([string]$Path, [string]$ExpectedHash) {
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $ExpectedHash) {
        throw 'The WIC input changed before reading.'
    }
    $image = [System.Drawing.Bitmap]::new($Path)
    try {
        if ($image.PropertyIdList -contains 0x112) {
            $orientation = $image.GetPropertyItem(0x112).Value
            if ($orientation.Length -ne 2 -or [BitConverter]::ToUInt16($orientation, 0) -ne 1) {
                throw 'Unexpected orientation metadata in the synthetic probe.'
            }
        }
    } finally {
        $image.Dispose()
    }
    $buffer = [WindowsModern.Reference.WicBoundary]::Read($Path)
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $ExpectedHash) {
        throw 'The WIC input changed while reading.'
    }
    return [ordered]@{
        source_sha256 = $ExpectedHash
        source_width = $buffer.SourceWidth
        source_height = $buffer.SourceHeight
        width = $buffer.Width
        height = $buffer.Height
        interpolation_mode = 1
        pixel_format = '32bppBGR'
        order = 'top-down BGRX'
        bitmap_sha256 = $buffer.Sha256
        gzip_base64 = $buffer.GzipBase64
    }
}

function Assert-ProbeCacheColor([string]$Observed, [string]$Expected) {
    if ($Observed -notmatch '^#[0-9A-Fa-f]{6}$') {
        throw 'Missing sampled cache color.'
    }
    $a = [System.Drawing.ColorTranslator]::FromHtml($Observed)
    $b = [System.Drawing.ColorTranslator]::FromHtml($Expected)
    foreach ($channel in @('R', 'G', 'B')) {
        if ([Math]::Abs([int]($a.$channel) - [int]($b.$channel)) -gt 12) {
            throw 'Cache pixels do not match the controlled probe colors.'
        }
    }
}

function Read-WicBoundaryEvidence([string]$Path, [string]$ExpectedHash, $Probe, $Result) {
    # Never export original reference wallpaper pixels. The cache must be
    # changed, have the expected dimensions and match the probe's colors.
    $cache = $Result.cache_observation.transcoded
    $reference = $Result.isolation_reference.caches.transcoded
    if (-not $Result.native_argb_changed_from_reference -or
        $cache.status -ne 'ok' -or -not $cache.is_jpeg -or
        $reference.status -ne 'ok' -or $cache.sha256 -ceq $reference.sha256 -or
        $cache.width -ne $width -or $cache.height -ne $height) {
        throw 'No independently verified synthetic JPEG cache for WIC capture.'
    }
    Assert-ProbeCacheColor $cache.background_rgb $Probe.background
    Assert-ProbeCacheColor $cache.patch_rgb $Probe.rectangle.color
    $cachePath = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper'
    return [ordered]@{
        source = (Read-WicBoundaryBuffer $Path $ExpectedHash)
        transcoded = (Read-WicBoundaryBuffer $cachePath $cache.sha256)
    }
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
    if ($ProbeSet -in @('Refinement', 'Extraction', 'Boundary', 'Scoring', 'ScoringRefinement', 'CacheIsolation', 'BitmapBoundary') -and $sample.schema_version -lt 4) {
        throw 'Refinement, Extraction, Boundary, Scoring, ScoringRefinement, CacheIsolation and BitmapBoundary require capture-windows-accent.ps1 schema 4 or newer.'
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

function Get-ProbePixelValidation([string]$Path, $Probe) {
    $bitmap = [System.Drawing.Bitmap]::new($Path)
    try {
        $expectedBackground = [System.Drawing.ColorTranslator]::FromHtml($Probe.background)
        $actualBackground = $bitmap.GetPixel(($width - 1), ($height - 1))
        $expectedBackgroundHex = '#{0:X2}{1:X2}{2:X2}' -f $expectedBackground.R, $expectedBackground.G, $expectedBackground.B
        $actualBackgroundHex = '#{0:X2}{1:X2}{2:X2}' -f $actualBackground.R, $actualBackground.G, $actualBackground.B
        $validation = [ordered]@{
            background_expected_rgb = $expectedBackgroundHex
            background_actual_rgb = $actualBackgroundHex
            background_matches = $expectedBackgroundHex -ceq $actualBackgroundHex
            patch_expected_rgb = $null
            patch_actual_rgb = $null
            patch_matches = $null
        }
        if ($Probe.rectangle) {
            $expectedPatch = [System.Drawing.ColorTranslator]::FromHtml($Probe.rectangle.color)
            $patchX = [int]$Probe.rectangle.x + [int][Math]::Floor([int]$Probe.rectangle.width / 2)
            $patchY = [int]$Probe.rectangle.y + [int][Math]::Floor([int]$Probe.rectangle.height / 2)
            $actualPatch = $bitmap.GetPixel($patchX, $patchY)
            $expectedPatchHex = '#{0:X2}{1:X2}{2:X2}' -f $expectedPatch.R, $expectedPatch.G, $expectedPatch.B
            $actualPatchHex = '#{0:X2}{1:X2}{2:X2}' -f $actualPatch.R, $actualPatch.G, $actualPatch.B
            $validation.patch_expected_rgb = $expectedPatchHex
            $validation.patch_actual_rgb = $actualPatchHex
            $validation.patch_matches = $expectedPatchHex -ceq $actualPatchHex
        }
        if (-not $validation.background_matches -or
            ($Probe.rectangle -and -not $validation.patch_matches)) {
            throw "Generated BMP pixel validation failed for $Path."
        }
        return $validation
    } finally {
        $bitmap.Dispose()
    }
}

# Read-only rendered-cache evidence, without exporting image bytes or
# personal paths. A matching cache does not prove the extractor used it.
function Read-WallpaperCache([string]$Path, $Probe) {
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return [ordered]@{status='missing'}
        }
        $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        $bitmap = [System.Drawing.Bitmap]::new($Path)
        try {
            $info = [ordered]@{
                status = 'ok'
                sha256 = $hash
                width = $bitmap.Width
                height = $bitmap.Height
                format_guid = $bitmap.RawFormat.Guid.ToString()
                is_jpeg = ($bitmap.RawFormat.Guid -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid)
            }
            if ($null -ne $Probe) {
                # CacheIsolation rectangles leave the bottom-right interior
                # in the background. Use normalized sample coordinates.
                $bx = [int][Math]::Floor($bitmap.Width * 0.875)
                $by = [int][Math]::Floor($bitmap.Height * 0.875)
                $pixel = $bitmap.GetPixel($bx, $by)
                $info.background_rgb = '#{0:X2}{1:X2}{2:X2}' -f $pixel.R, $pixel.G, $pixel.B
                if ($Probe.rectangle) {
                    $px = [int][Math]::Floor(($Probe.rectangle.x + $Probe.rectangle.width / 2.0) * $bitmap.Width / $width)
                    $py = [int][Math]::Floor(($Probe.rectangle.y + $Probe.rectangle.height / 2.0) * $bitmap.Height / $height)
                    $pixel = $bitmap.GetPixel($px, $py)
                    $info.patch_rgb = '#{0:X2}{1:X2}{2:X2}' -f $pixel.R, $pixel.G, $pixel.B
                } else {
                    # Sample uniformity at nine interior points, not all pixels.
                    $colors = @(foreach ($fy in 0.125, 0.5, 0.875) {
                        foreach ($fx in 0.125, 0.5, 0.875) {
                            $pixel = $bitmap.GetPixel(([int][Math]::Floor($bitmap.Width * $fx)),
                                ([int][Math]::Floor($bitmap.Height * $fy)))
                            '#{0:X2}{1:X2}{2:X2}' -f $pixel.R, $pixel.G, $pixel.B
                        }
                    })
                    $info.sampled_solid_rgb = $colors
                    $info.sampled_uniform = (@($colors | Select-Object -Unique).Count -eq 1)
                    if ($info.sampled_uniform) {
                        $rgb = $bitmap.GetPixel($bx, $by)
                        $range = @([int]$rgb.R, [int]$rgb.G, [int]$rgb.B) | Measure-Object -Minimum -Maximum
                        $info.alpha_from_sampled_span = [int][Math]::Min(175, (125 + $range.Maximum - $range.Minimum))
                    }
                }
            }
        } finally {
            $bitmap.Dispose()
        }
        if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $hash) {
            return [ordered]@{status='changed_during_read'}
        }
        return $info
    } catch {
        return [ordered]@{status='unreadable'; error_type=$_.Exception.GetType().Name}
    }
}

function Read-WallpaperCaches($Probe) {
    $themes = Join-Path $env:APPDATA 'Microsoft\Windows\Themes'
    $displayDir = Join-Path $themes 'CachedFiles'
    $pattern = 'CachedImage_{0}_{1}_POS*.jpg' -f $width, $height
    $cacheFiles = @(Get-ChildItem -LiteralPath $displayDir -Filter $pattern -File -ErrorAction SilentlyContinue)
    $displayCache = [ordered]@{status='missing'}
    if ($cacheFiles.Count -eq 1) {
        $displayCache = Read-WallpaperCache ($cacheFiles[0].FullName) $Probe
    } elseif ($cacheFiles.Count -gt 1) {
        $displayCache = [ordered]@{status='ambiguous'; count=$cacheFiles.Count}
    }
    return [ordered]@{
        transcoded = (Read-WallpaperCache (Join-Path $themes 'TranscodedWallpaper') $Probe)
        display_cache = $displayCache
    }
}

function Assert-NativeColorEvidence($Capture) {
    $native = $Capture.native_wallpaper_color_api
    if ($null -eq $native -or $native.status -ne 'ok' -or
        $native.hresult -ne '0x00000000' -or
        -not $native.argb_matches_image_color -or
        -not $native.argb_matches_image_color_after_api -or
        -not $native.rgb_matches_dwm_colorization -or
        $native.image_color_changed_by_api) {
        throw 'CacheIsolation requires consistent native ARGB evidence.'
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
    } elseif ($ProbeSet -eq 'Scoring') {
        # The first pair keeps L* near 50 and varies the red population
        # around the squared-channel-span prediction (30.77%).
        # The second pair keeps L* near 48 and varies orange population
        # around the squared-span prediction (15.67%); this removes the
        # large lightness mismatch in the earlier orange/purple probes.
        # The final solid colors keep L* near 50 and hue near 20 degrees
        # while varying the authored RGB channel span for native-alpha work.
        $probes = @(
            @{name='red-30pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.30); height=$height}},
            @{name='red-31_25pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.3125); height=$height}},
            @{name='red-32_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.325); height=$height}},
            @{name='red-35pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.35); height=$height}},
            @{name='red-37_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.375); height=$height}},
            @{name='orange-14pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.14); height=$height}},
            @{name='orange-15pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.15); height=$height}},
            @{name='orange-16pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.16); height=$height}},
            @{name='orange-17_5pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.175); height=$height}},
            @{name='orange-20pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.20); height=$height}},
            @{name='orange-22_5pct-on-purple-l48'; background='#9F5A8C'; rectangle=@{
                color='#AB5E0B'; x=0; y=0; width=[int][Math]::Floor($width * 0.225); height=$height}},
            @{name='alpha-l50-span-12'; background='#807474'; rectangle=$null},
            @{name='alpha-l50-span-24'; background='#897171'; rectangle=$null},
            @{name='alpha-l50-span-36'; background='#926E6F'; rectangle=$null},
            @{name='alpha-l50-span-37'; background='#936E6E'; rectangle=$null},
            @{name='alpha-l50-span-47'; background='#9A6B6C'; rectangle=$null},
            @{name='alpha-l50-span-49'; background='#9B6A6B'; rectangle=$null},
            @{name='alpha-l50-span-50'; background='#9C6A6B'; rectangle=$null},
            @{name='alpha-l50-span-51'; background='#9D6A6B'; rectangle=$null}
        )
    } elseif ($ProbeSet -eq 'ScoringRefinement') {
        # Red/green winner boundary: refine the observed 32.5%-35% interval.
        # Similarity pairs keep CIELAB L* near 50 and channel span near 100,
        # varying hue distance and the per-channel RGB delta.
        # Alpha samples keep L* near 50 and hue near zero while varying span.
        $probes = @(
            @{name='red-33pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.33); height=$height}},
            @{name='red-33_25pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.3325); height=$height}},
            @{name='red-33_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.335); height=$height}},
            @{name='red-33_75pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.3375); height=$height}},
            @{name='red-34pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.34); height=$height}},
            @{name='red-34_25pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.3425); height=$height}},
            @{name='red-34_5pct-on-green'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=[int][Math]::Floor($width * 0.345); height=$height}},
            @{name='similarity-solid-hue0'; background='#BC5858'; rectangle=$null},
            @{name='similarity-solid-hue180'; background='#208484'; rectangle=$null},
            @{name='similarity-hue30-patch40'; background='#BC5858'; rectangle=@{
                color='#9F6C3A'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue60-patch40'; background='#BC5858'; rectangle=@{
                color='#7B7B17'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue90-patch40'; background='#BC5858'; rectangle=@{
                color='#528420'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue120-patch40'; background='#BC5858'; rectangle=@{
                color='#258925'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue150-patch40'; background='#BC5858'; rectangle=@{
                color='#238755'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue165-patch40'; background='#BC5858'; rectangle=@{
                color='#22866D'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue180-patch40'; background='#BC5858'; rectangle=@{
                color='#208484'; x=0; y=0; width=[int][Math]::Floor($width * 0.40); height=$height}},
            @{name='similarity-hue150-patch60'; background='#BC5858'; rectangle=@{
                color='#238755'; x=0; y=0; width=[int][Math]::Floor($width * 0.60); height=$height}},
            @{name='similarity-hue180-patch60'; background='#BC5858'; rectangle=@{
                color='#208484'; x=0; y=0; width=[int][Math]::Floor($width * 0.60); height=$height}},
            @{name='alpha-l50-span-32'; background='#8F6F6F'; rectangle=$null},
            @{name='alpha-l50-span-34'; background='#916F6F'; rectangle=$null},
            @{name='alpha-l50-span-35'; background='#916E6E'; rectangle=$null},
            @{name='alpha-l50-span-38'; background='#946E6E'; rectangle=$null},
            @{name='alpha-l50-span-40'; background='#956D6D'; rectangle=$null},
            @{name='alpha-l50-span-44'; background='#986C6C'; rectangle=$null},
            @{name='alpha-l50-span-46'; background='#996B6B'; rectangle=$null},
            @{name='alpha-l50-span-47'; background='#9A6B6B'; rectangle=$null},
            @{name='alpha-l50-span-48'; background='#9B6B6B'; rectangle=$null},
            @{name='alpha-l50-span-49'; background='#9B6A6A'; rectangle=$null},
            @{name='alpha-l50-span-52'; background='#9D6969'; rectangle=$null}
        )
    } elseif ($isolated) {
        # Recheck the winner interval in both directions and rotate the
        # split. All rectangles leave a background region at bottom right.
        $redLow = [int][Math]::Floor($width * 0.345)
        $redHigh = [int][Math]::Floor($width * 0.35)
        $cyanWide = [int][Math]::Floor($width * 0.60)
        $probes = @(
            @{name='isolated-red-low-left'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$redLow; height=$height}},
            @{name='isolated-red-high-left'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$redHigh; height=$height}},
            @{name='isolated-red-low-right'; background='#E13030'; rectangle=@{
                color='#148A14'; x=0; y=0; width=($width - $redLow); height=$height}},
            @{name='isolated-red-high-right'; background='#E13030'; rectangle=@{
                color='#148A14'; x=0; y=0; width=($width - $redHigh); height=$height}},
            @{name='isolated-red-high-top'; background='#148A14'; rectangle=@{
                color='#E13030'; x=0; y=0; width=$width; height=[int][Math]::Floor($height * 0.35)}},
            @{name='isolated-cyan-60-left'; background='#BC5858'; rectangle=@{
                color='#208484'; x=0; y=0; width=$cyanWide; height=$height}},
            @{name='isolated-cyan-60-right'; background='#208484'; rectangle=@{
                color='#BC5858'; x=0; y=0; width=($width - $cyanWide); height=$height}},
            @{name='isolated-cyan-60-top'; background='#BC5858'; rectangle=@{
                color='#208484'; x=0; y=0; width=$width; height=[int][Math]::Floor($height * 0.60)}},
            @{name='isolated-cyan-75-left'; background='#BC5858'; rectangle=@{
                color='#208484'; x=0; y=0; width=[int][Math]::Floor($width * 0.75); height=$height}},
            @{name='isolated-cyan-solid'; background='#208484'; rectangle=$null},
            @{name='isolated-alpha-span-34'; background='#916F6F'; rectangle=$null},
            @{name='isolated-alpha-span-35'; background='#916E6E'; rectangle=$null},
            @{name='isolated-alpha-span-48'; background='#9B6B6B'; rectangle=$null},
            @{name='isolated-alpha-span-49'; background='#9B6A6A'; rectangle=$null},
            @{name='isolated-fallback-span-28'; background='#8B6F6F'; rectangle=$null},
            @{name='isolated-fallback-span-30'; background='#8D6F6F'; rectangle=$null}
        )
        if ($ProbeSet -eq 'BitmapBoundary') {
            $probes = @($probes | Where-Object {
                $_.name -in @('isolated-red-high-left', 'isolated-red-high-right', 'isolated-red-high-top')
            })
        }
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
        $probe.pixel_validation = Get-ProbePixelValidation $path $probe
        $probePaths += $path
        $probeHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }

    $previous = $baseline
    if ($isolated) {
        Assert-NativeColorEvidence $baseline
        if ($baseline.appearance.source_wallpaper_sha256 -ne $baseline.appearance.registered_wallpaper_sha256) {
            throw 'The original source and registered wallpaper must match for CacheIsolation.'
        }
    }
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
        $attempted = $true
        if ($isolated) {
            # Independently re-establish the original wallpaper before
            # every target, rather than inheriting the preceding probe.
            if ($active -ine $original) {
                $desktop.SetPath($original)
                $reset = Read-Settled $original $previous $baseline
                $previous = Add-NativeWallpaperDiagnostic $reset.capture $original $baseline
            }
            Assert-NativeColorEvidence $previous
            if ($desktop.GetPath() -ine $original -or
                (Palette-Key $previous) -cne (Palette-Key $baseline) -or
                $previous.native_wallpaper_color_api.argb -cne $baseline.native_wallpaper_color_api.argb -or
                $previous.appearance.source_wallpaper_sha256 -cne $baseline.appearance.source_wallpaper_sha256 -or
                $previous.appearance.registered_wallpaper_sha256 -cne $baseline.appearance.registered_wallpaper_sha256) {
                throw 'Could not re-establish the original reference before the next probe.'
            }
            $reference = [ordered]@{
                native_argb = $previous.native_wallpaper_color_api.argb
                accent = $previous.accent_observed_from_ui_settings
                wallpaper_sha256 = $previous.appearance.registered_wallpaper_sha256
                caches = (Read-WallpaperCaches $null)
            }
            if ($desktop.GetPath() -ine $original) {
                throw 'Wallpaper changed while reading reference caches.'
            }
        }
        Write-Host ('Collecting ' + $probe.name)
        $desktop.SetPath($path)
        $result = Read-Settled $path $previous $baseline
        $result.capture = Add-NativeWallpaperDiagnostic $result.capture $path $baseline
        if ($result.capture.appearance.source_wallpaper_sha256 -ne $expectedHash -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'Probe image bytes changed.'
        }
        if ($isolated) {
            Assert-NativeColorEvidence $result.capture
            if ($result.capture.appearance.registered_wallpaper_sha256 -cne $expectedHash) {
                throw 'Registered wallpaper does not match the generated probe.'
            }
            $result.isolation_reference = $reference
            $result.native_argb_changed_from_reference = (
                $result.capture.native_wallpaper_color_api.argb -cne $reference.native_argb)
            $result.cache_observation = Read-WallpaperCaches $probe
            if ($ProbeSet -eq 'BitmapBoundary') {
                if ($desktop.GetPath() -ine $path) {
                    throw 'Wallpaper changed before reading WIC buffers.'
                }
                $result.wic_boundary = Read-WicBoundaryEvidence $path $expectedHash $probe $result
            }
            if ($desktop.GetPath() -ine $path) {
                throw 'Wallpaper changed while reading probe caches.'
            }
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
