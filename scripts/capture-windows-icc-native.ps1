# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only native color conversion probe. No wallpaper, profile installation,
# display settings, registry writes, administrator rights, or external DLLs.
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'windows-icc-native.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this diagnostic in Windows PowerShell on the reference Windows VM.'
}

if (-not ('WindowsModern.Reference.IccProbeV1.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace WindowsModern.Reference.IccProbeV1
{
    [ComImport, Guid("00000120-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicSource
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
    }
    [ComImport, Guid("3c613a02-34b2-44ea-9a7c-45aea9c6fd6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicContext
    {
        void ReservedInitializeFromFilename();
        void InitializeFromMemory(IntPtr bytes, uint size);
        void InitializeFromExifColorSpace(uint value);
    }
    [ComImport, Guid("b66f034f-d0e2-40ab-b436-6de39e321a94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicTransform
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
        void Initialize(IWicSource source, IWicContext sourceContext, IWicContext destContext, ref Guid format);
    }
    [ComImport, Guid("ec5ec8a9-c395-4314-9c77-54d7a935ff70"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicFactory
    {
        // Unused slots preserve the SDK vtable order.
        void ReservedCreateDecoderFromFilename();
        void ReservedCreateDecoderFromStream();
        void ReservedCreateDecoderFromFileHandle();
        void ReservedCreateComponentInfo();
        void ReservedCreateDecoder();
        void ReservedCreateEncoder();
        void ReservedCreatePalette();
        void ReservedCreateFormatConverter();
        void ReservedCreateBitmapScaler();
        void ReservedCreateBitmapClipper();
        void ReservedCreateBitmapFlipRotator();
        void ReservedCreateStream();
        void CreateColorContext(out IWicContext context);
        void CreateColorTransformer(out IWicTransform transform);
        void ReservedCreateBitmap();
        void ReservedCreateBitmapFromSource();
        void ReservedCreateBitmapFromSourceRect();
        void CreateBitmapFromMemory(uint width, uint height, ref Guid format, uint stride,
                                    uint size, IntPtr pixels, out IWicSource bitmap);
    }

    public static class Native
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct Profile
        {
            public uint Type;
            public IntPtr Data;
            public uint Size;
        }

        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr OpenColorProfileW(ref Profile profile, uint access, uint share, uint creation);
        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern bool CloseColorProfile(IntPtr profile);
        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr CreateMultiProfileTransform([In] IntPtr[] profiles, uint count,
            [In] uint[] intents, uint intentCount, uint flags, uint preferredCmm);
        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern bool DeleteColorTransform(IntPtr transform);
        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern bool TranslateBitmapBits(IntPtr transform, [In] byte[] input, uint inputFormat,
            uint width, uint height, uint inputStride, [Out] byte[] output, uint outputFormat,
            uint outputStride, IntPtr callback, IntPtr callbackData);
        [DllImport("mscms.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        private static extern bool GetStandardColorSpaceProfileW(string machine, uint space, StringBuilder name, ref uint size);
        [DllImport("mscms.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        private static extern bool GetColorDirectoryW(string machine, StringBuilder name, ref uint size);

        public static string Hash(byte[] data)
        {
            using (SHA256 sha = SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "");
        }
        public static byte[] CalibrationColors()
        {
            SortedSet<int> colors = new SortedSet<int>();
            for (int i=0; i<256; i++)
            {
                colors.Add(i * 0x010101);
                colors.Add(i << 16);
                colors.Add(i << 8);
                colors.Add(i);
            }
            colors.Add(0x148a14);
            colors.Add(0xe13030);
            colors.Add(0xff00ff);
            byte[] result = new byte[colors.Count * 3];
            int p=0;
            foreach (int rgb in colors)
            {
                result[p++] = (byte)(rgb >> 16);
                result[p++] = (byte)(rgb >> 8);
                result[p++] = (byte)rgb;
            }
            return result;
        }

        private static string ColorDirectory()
        {
            uint size=0;
            GetColorDirectoryW(null, null, ref size);
            if (size == 0 || size > 65536) throw new Win32Exception(Marshal.GetLastWin32Error());
            StringBuilder path = new StringBuilder(checked((int)size + 1));
            if (!GetColorDirectoryW(null, path, ref size)) throw new Win32Exception(Marshal.GetLastWin32Error());
            return path.ToString();
        }
        public static byte[] RegisteredProfile(uint space)
        {
            uint size=0;
            GetStandardColorSpaceProfileW(null, space, null, ref size);
            if (size == 0 || size > 65536) throw new Win32Exception(Marshal.GetLastWin32Error());
            StringBuilder path = new StringBuilder(checked((int)size + 1));
            if (!GetStandardColorSpaceProfileW(null, space, path, ref size))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            string file=path.ToString();
            if (!Path.IsPathRooted(file)) file=Path.Combine(ColorDirectory(), file);
            return ReadProfile(file);
        }
        public static byte[] InstalledSrgb()
        {
            return ReadProfile(Path.Combine(ColorDirectory(), "sRGB Color Space Profile.icm"));
        }
        private static byte[] ReadProfile(string file)
        {
            FileInfo info = new FileInfo(file);
            if (!info.Exists || info.Length < 1 || info.Length > 16 * 1024 * 1024)
                throw new InvalidDataException("Profile missing or outside the diagnostic size bound.");
            return File.ReadAllBytes(file);
        }

        private static IntPtr Open(byte[] data)
        {
            GCHandle pin=GCHandle.Alloc(data, GCHandleType.Pinned);
            try
            {
                Profile profile=new Profile {Type=2, Data=pin.AddrOfPinnedObject(), Size=(uint)data.Length};
                // PROFILE_MEMBUFFER, PROFILE_READ, OPEN_EXISTING.
                IntPtr handle=OpenColorProfileW(ref profile, 1, 1, 3);
                if (handle==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                return handle;
            }
            finally {pin.Free();}
        }
        private static byte[] ToBgr(byte[] rgb, int channels)
        {
            byte[] pixels=new byte[rgb.Length/3*channels];
            for (int i=0,j=0; i<rgb.Length; i+=3,j+=channels)
            {
                pixels[j]=rgb[i+2]; pixels[j+1]=rgb[i+1]; pixels[j+2]=rgb[i];
                if (channels==4) pixels[j+3]=255;
            }
            return pixels;
        }
        private static byte[] FromBgr(byte[] pixels, int channels, bool checkAlpha)
        {
            byte[] rgb=new byte[pixels.Length/channels*3];
            for (int i=0,j=0; i<pixels.Length; i+=channels,j+=3)
            {
                if (checkAlpha && pixels[i+3]!=255) throw new InvalidDataException("Opaque alpha was changed.");
                rgb[j]=pixels[i+2]; rgb[j+1]=pixels[i+1]; rgb[j+2]=pixels[i];
            }
            return rgb;
        }

        public static byte[] Icm(byte[] rgb, byte[] source, byte[] destination, uint intent, uint flags, bool bgrx)
        {
            IntPtr src=IntPtr.Zero, dst=IntPtr.Zero, transform=IntPtr.Zero;
            try
            {
                src=Open(source);
                dst=Open(destination);
                transform=CreateMultiProfileTransform(new IntPtr[]{src,dst},2,
                    new uint[]{intent,intent},2,flags,0);
                if (transform==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                // SDK BM_BGRTRIPLETS (0x4) is RGB byte order; BM_xRGBQUADS (0x8) is BGRX.
                byte[] input=bgrx?ToBgr(rgb,4):rgb;
                byte[] output=new byte[input.Length];
                uint format=bgrx?8u:4u;
                if (!TranslateBitmapBits(transform,input,format,(uint)(rgb.Length/3),1,(uint)input.Length,
                    output,format,(uint)output.Length,IntPtr.Zero,IntPtr.Zero))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                return bgrx?FromBgr(output,4,false):output;
            }
            finally
            {
                if (transform!=IntPtr.Zero) DeleteColorTransform(transform);
                if (dst!=IntPtr.Zero) CloseColorProfile(dst);
                if (src!=IntPtr.Zero) CloseColorProfile(src);
            }
        }

        public static byte[] Wic(byte[] rgb, byte[] source, byte[] destination, string formatName)
        {
            IWicFactory factory=null; IWicSource bitmap=null; IWicContext src=null,dst=null; IWicTransform transform=null;
            GCHandle inputPin=default(GCHandle), outputPin=default(GCHandle), sourcePin=default(GCHandle), destPin=default(GCHandle);
            try
            {
                string suffix=formatName=="BGR24"?"0c":formatName=="BGR32"?"0e":formatName=="BGRA32"?"0f":null;
                if (suffix==null) throw new ArgumentException("Unsupported WIC format");
                int channels=formatName=="BGR24"?3:4;
                Guid format=new Guid("6fddc324-4e03-4bfe-b185-3d77768dc9"+suffix);
                byte[] input=ToBgr(rgb,channels), output=new byte[input.Length];
                inputPin=GCHandle.Alloc(input,GCHandleType.Pinned);
                outputPin=GCHandle.Alloc(output,GCHandleType.Pinned);
                sourcePin=GCHandle.Alloc(source,GCHandleType.Pinned);
                factory=(IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                factory.CreateBitmapFromMemory((uint)(rgb.Length/3),1,ref format,(uint)input.Length,
                    (uint)input.Length,inputPin.AddrOfPinnedObject(),out bitmap);
                factory.CreateColorContext(out src);
                src.InitializeFromMemory(sourcePin.AddrOfPinnedObject(),(uint)source.Length);
                factory.CreateColorContext(out dst);
                if (destination==null)
                    dst.InitializeFromExifColorSpace(1); // EXIF sRGB
                else
                {
                    destPin=GCHandle.Alloc(destination,GCHandleType.Pinned);
                    dst.InitializeFromMemory(destPin.AddrOfPinnedObject(),(uint)destination.Length);
                }
                factory.CreateColorTransformer(out transform);
                transform.Initialize(bitmap,src,dst,ref format);
                Guid actual; uint width,height;
                transform.GetPixelFormat(out actual); transform.GetSize(out width,out height);
                if (actual!=format || width!=(uint)(rgb.Length/3) || height!=1)
                    throw new InvalidDataException("Unexpected WIC output format or dimensions.");
                transform.CopyPixels(IntPtr.Zero,(uint)output.Length,(uint)output.Length,outputPin.AddrOfPinnedObject());
                return FromBgr(output,channels,formatName=="BGRA32");
            }
            finally
            {
                foreach (object item in new object[]{transform,dst,src,bitmap,factory})
                    if (item!=null) Marshal.ReleaseComObject(item);
                if (destPin.IsAllocated) destPin.Free();
                if (sourcePin.IsAllocated) sourcePin.Free();
                if (outputPin.IsAllocated) outputPin.Free();
                if (inputPin.IsAllocated) inputPin.Free();
            }
        }
    }
}
'@
}

# Exact synthetic profiles from DecodeProfile, decoded from the original
# collector payloads. No machine or display profile is embedded or exported.
$sourceData = [ordered]@{
    'srgb' = 'AAACTGxjbXMEQAAAbW50clJHQiBYWVogB+oACwAaAAsABgA2YWNzcEFQUEwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPbWAAEAAAAA0y1sY21zAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALZGVzYwAAAQgAAAA2Y3BydAAAAUAAAABMd3RwdAAAAYwAAAAUY2hhZAAAAaAAAAAsclhZWgAAAcwAAAAUYlhZWgAAAeAAAAAUZ1hZWgAAAfQAAAAUclRSQwAAAggAAAAgZ1RSQwAAAggAAAAgYlRSQwAAAggAAAAgY2hybQAAAigAAAAkbWx1YwAAAAAAAAABAAAADGVuVVMAAAAaAAAAHABzAFIARwBCACAAYgB1AGkAbAB0AC0AaQBuAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAADAAAAAcAE4AbwAgAGMAbwBwAHkAcgBpAGcAaAB0ACwAIAB1AHMAZQAgAGYAcgBlAGUAbAB5WFlaIAAAAAAAAPbWAAEAAAAA0y1zZjMyAAAAAAABDEIAAAXe///zJQAAB5MAAP2Q///7of///aIAAAPcAADAblhZWiAAAAAAAABvoAAAOPUAAAOQWFlaIAAAAAAAACSfAAAPhAAAtsNYWVogAAAAAAAAYpcAALeHAAAY2XBhcmEAAAAAAAMAAAACZmYAAPKnAAANWQAAE9AAAApbY2hybQAAAAAAAwAAAACj1wAAVHsAAEzNAACZmgAAJmYAAA9c'
    'linear-srgb' = 'AAACOGxjbXMEMAAAbW50clJHQiBYWVogB+oACwAaAAsACQAaYWNzcEFQUEwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPbWAAEAAAAA0y1sY21zAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALZGVzYwAAAQgAAAA0Y3BydAAAATwAAABMd3RwdAAAAYgAAAAUY2hhZAAAAZwAAAAsclhZWgAAAcgAAAAUYlhZWgAAAdwAAAAUZ1hZWgAAAfAAAAAUclRSQwAAAgQAAAAQZ1RSQwAAAgQAAAAQYlRSQwAAAgQAAAAQY2hybQAAAhQAAAAkbWx1YwAAAAAAAAABAAAADGVuVVMAAAAYAAAAHABSAEcAQgAgAGIAdQBpAGwAdAAtAGkAbm1sdWMAAAAAAAAAAQAAAAxlblVTAAAAMAAAABwATgBvACAAYwBvAHAAeQByAGkAZwBoAHQALAAgAHUAcwBlACAAZgByAGUAZQBsAHlYWVogAAAAAAAA9tYAAQAAAADTLXNmMzIAAAAAAAEMQgAABd7///MlAAAHkwAA/ZD///uh///9ogAAA9wAAMBuWFlaIAAAAAAAAG+gAAA49QAAA5BYWVogAAAAAAAAJJ8AAA+EAAC2w1hZWiAAAAAAAABilwAAt4cAABjZcGFyYQAAAAAAAAAAAAEAAGNocm0AAAAAAAMAAAAAo9cAAFR7AABMzQAAmZoAACZmAAAPXA=='
}
$sourceHashes = [ordered]@{
    'srgb' = '47FDA5236B74B9F11DA23C9834FAE1DBF0C0E195DEBEB22EFD147268C1CEC98C'
    'linear-srgb' = 'BC77188D9AABAF2F17730FBE0C3B3954579190954C6E273C35C33D52CFB193B6'
}
$nativeType = [WindowsModern.Reference.IccProbeV1.Native]
$sourceProfiles = [ordered]@{}
foreach ($name in $sourceData.Keys) {
    [byte[]]$data = [Convert]::FromBase64String($sourceData[$name])
    if ($nativeType::Hash($data) -ne $sourceHashes[$name]) { throw 'Synthetic ICC hash mismatch.' }
    $sourceProfiles[$name] = $data
}
[byte[]]$rgb = $nativeType::CalibrationColors()
if ($rgb.Length -ne 3072) { throw 'Unexpected calibration color count.' }

# Record error types and native error codes without leaking local paths.
function Get-ProbeError($Record) {
    $e = $Record.Exception
    while ($null -ne $e.InnerException) { $e = $e.InnerException }
    [ordered]@{ error_type = $e.GetType().FullName; hresult = $e.HResult;
        native_error = $(if ($e -is [ComponentModel.Win32Exception]) { $e.NativeErrorCode } else { $null }) }
}

$targets = [ordered]@{}
$targetProfiles = [ordered]@{}
$hashToTarget = @{}
foreach ($target in @('registered-srgb','registered-windows','installed-srgb','synthetic-srgb')) {
    try {
        [byte[]]$data = switch ($target) {
            'registered-srgb' { $nativeType::RegisteredProfile(0x73524742) }
            'registered-windows' { $nativeType::RegisteredProfile(0x57696e20) }
            'installed-srgb' { $nativeType::InstalledSrgb() }
            'synthetic-srgb' { $sourceProfiles['srgb'] }
        }
        $hash = $nativeType::Hash($data)
        $targets[$target] = [ordered]@{status='ok';sha256=$hash;length=$data.Length;alias_of=$null}
        if ($hashToTarget.ContainsKey($hash)) {
            $targets[$target]['alias_of'] = $hashToTarget[$hash]
        } else {
            $hashToTarget[$hash] = $target
            $targetProfiles[$target] = $data
        }
    } catch {
        $targets[$target] = [ordered]@{status='error';sha256=$null;error=(Get-ProbeError $_)}
    }
}
$targets['exif-srgb'] = [ordered]@{status='ok';sha256=$null;length=$null;alias_of=$null}
$targetProfiles['exif-srgb'] = $null

$candidates = New-Object 'System.Collections.Generic.List[object]'
function Add-Candidate([string]$source, [string]$target, [string]$api, [string]$format, $intent, $flags) {
    $row = [ordered]@{source=$source;target=$target;target_sha256=$targets[$target]['sha256'];
        api=$api;format=$format;intent=$intent;flags=$flags;status='ok'}
    try {
        [byte[]]$output = if ($api -eq 'WIC') {
            $nativeType::Wic($rgb,$sourceProfiles[$source],$targetProfiles[$target],$format)
        } else {
            $nativeType::Icm($rgb,$sourceProfiles[$source],$targetProfiles[$target],
                [uint32]$intent,[uint32]$flags,($format -eq 'BGRX32'))
        }
        if ($output.Length -ne $rgb.Length) { throw 'Unexpected transform output length.' }
        $row['output_rgb_sha256'] = $nativeType::Hash($output)
        $row['output_rgb_base64'] = [Convert]::ToBase64String($output)
    } catch {
        $row['status'] = 'error'
        $row['error'] = Get-ProbeError $_
    }
    $candidates.Add($row)
}

foreach ($source in $sourceProfiles.Keys) {
    foreach ($target in $targetProfiles.Keys) {
        foreach ($format in @('BGR24','BGR32','BGRA32')) {
            Add-Candidate $source $target 'WIC' $format $null $null
        }
        if ($target -eq 'exif-srgb') { continue }
        foreach ($intent in 0..3) {
            # Default path and WCS_ALWAYS; zero/default, proof, normal, best quality.
            foreach ($flag in @(0,1,2,3,0x00200000,0x00200001,0x00200002,0x00200003)) {
                foreach ($format in @('RGB24','BGRX32')) {
                    Add-Candidate $source $target 'ICM' $format $intent $flag
                }
            }
        }
    }
}

$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version=1
    windows_build=('{0}.{1}' -f $version.CurrentBuildNumber,$version.UBR)
    color_count=1024
    input_rgb_sha256=$nativeType::Hash($rgb)
    input_rgb_base64=[Convert]::ToBase64String($rgb)
    sources=$sourceHashes
    targets=$targets
    candidates=$candidates.ToArray()
}
$json = $report | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,(New-Object Text.UTF8Encoding($false)))
$success = @($candidates | Where-Object { $_['status'] -eq 'ok' }).Count
Write-Host ('Native ICC probe: {0} successful / {1} candidates.' -f $success,$candidates.Count)
Write-Host ('Report: {0}' -f [IO.Path]::GetFullPath($OutputPath))
if ($success -eq 0) { throw 'No candidate succeeded; inspect the diagnostic report.' }
