# SPDX-License-Identifier: GPL-3.0-or-later
# Unified one-command Windows 11 26H2 reference capture suite for Block 04:
#   - D02: Multi-hue + CIELAB/HSL near-gray manual accent ramp sweep (uxtheme + UISettings cross-check)
#   - D04 / D06-D08: Automatic multi-hue, luminance/chroma fallback, and WIC container/alpha wallpaper sweep
#   - D11 / D12: Forward RGB mft2 (3x4x5) / mft1 LUT, ICC v4 mAB (A2B0), and CMYK RSWOP.icm native transforms
#
# Usage (run in a regular non-admin PowerShell window on Windows 11 26H2):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\capture-windows-26h2-suite.ps1 -ApplyTemporarily
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'windows-26h2-capture-suite.json'),
    [switch]$ApplyTemporarily,
    [switch]$SkipWallpaperSweep,
    [switch]$SkipIccSweep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this script in Windows PowerShell on the Windows 11 26H2 reference machine.'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('WindowsModern.Suite26H2.NativeSuite' -as [type])) {
    Add-Type -ReferencedAssemblies @('System.Drawing.dll') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;
using System.Text;

namespace WindowsModern.Suite26H2
{
    [StructLayout(LayoutKind.Sequential)]
    public struct ImmersiveColorPreference
    {
        public uint crStartColor;
        public uint crAccentColor;
    }

    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IDesktopWallpaperPublic
    {
        [PreserveSig] int SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor, [MarshalAs(UnmanagedType.LPWStr)] string path);
        [PreserveSig] int GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor, out IntPtr path);
    }

    [ComImport, Guid("C182461F-DFAC-4375-AB6E-4CC45AA7F9CC"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IDesktopWallpaperPrivate
    {
        [PreserveSig] int SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [PreserveSig] int GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor, out IntPtr wallpaper);
        [PreserveSig] int GetMonitorDevicePathAt(uint index, out IntPtr monitor);
        [PreserveSig] int GetMonitorDevicePathCount(out uint count);
        [PreserveSig] int GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitor, IntPtr rect);
        [PreserveSig] int SetBackgroundColor(uint color);
        [PreserveSig] int GetBackgroundColor(out uint color);
        [PreserveSig] int SetPosition(int position);
        [PreserveSig] int GetPosition(out int position);
        [PreserveSig] int SetSlideshow(IntPtr items);
        [PreserveSig] int GetSlideshow(out IntPtr items);
        [PreserveSig] int SetSlideshowOptions(int options, uint interval);
        [PreserveSig] int GetSlideshowOptions(out int options, out uint interval);
        [PreserveSig] int AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitor, int direction);
        [PreserveSig] int GetStatus(out int state);
        [PreserveSig] int Enable(int enabled);
        [PreserveSig] int SetWallpaperNoGP([MarshalAs(UnmanagedType.LPWStr)] string monitor, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [PreserveSig] int PaintWallpaperThumbnail(long dc, int width, int height);
        [PreserveSig] int ComputeImageColorizationColor(out uint color);
        [PreserveSig] int GetMonitorNumber([MarshalAs(UnmanagedType.LPWStr)] string monitor, out uint number);
        [PreserveSig] int Flush();
        [PreserveSig] int PaintWallpaperBitmapFromShellTask();
    }

    [ComImport, Guid("00000120-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicSource
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
    }

    [ComImport, Guid("3b16811b-6a43-4ec9-a813-3d930c13b940"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicFrame
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
    }

    [ComImport, Guid("00000302-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicScaler
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
        void Initialize(IWicSource source, uint width, uint height, uint mode);
    }

    [ComImport, Guid("00000301-a8f2-4877-ba0a-fd2b6645fb94"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicConverter
    {
        void GetSize(out uint width, out uint height);
        void GetPixelFormat(out Guid format);
        void GetResolution(out double x, out double y);
        void CopyPalette(IntPtr palette);
        void CopyPixels(IntPtr rect, uint stride, uint size, IntPtr pixels);
        void Initialize(IWicSource source, ref Guid format, uint dither, IntPtr palette, double alphaThreshold, uint paletteType);
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

    [ComImport, Guid("9edde9e7-8dee-47ea-99df-e6faf2ed44bf"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
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

    [ComImport, Guid("ec5ec8a9-c395-4314-9c77-54d7a935ff70"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IWicFactory
    {
        void ReservedCreateDecoderFromFilename();
        void CreateDecoderFromStream(IStream stream, IntPtr vendor, uint options, out IWicDecoder decoder);
        void ReservedCreateDecoderFromFileHandle();
        void ReservedCreateComponentInfo();
        void ReservedCreateDecoder();
        void ReservedCreateEncoder();
        void ReservedCreatePalette();
        void CreateFormatConverter(out IWicConverter converter);
        void CreateBitmapScaler(out IWicScaler scaler);
        void ReservedCreateBitmapClipper();
        void ReservedCreateBitmapFlipRotator();
        void ReservedCreateStream();
        void CreateColorContext(out IWicContext context);
        void CreateColorTransformer(out IWicTransform transform);
        void ReservedCreateBitmap();
        void ReservedCreateBitmapFromSource();
        void ReservedCreateBitmapFromSourceRect();
        void CreateBitmapFromMemory(uint width, uint height, ref Guid format, uint stride, uint size, IntPtr pixels, out IWicSource bitmap);
    }

    public static class NativeSuite
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct MscmsProfile
        {
            public uint Type;
            public IntPtr Data;
            public uint Size;
        }

        [DllImport("uxtheme.dll", ExactSpelling = true)]
        public static extern int GetUserColorPreference(out ImmersiveColorPreference pref, [MarshalAs(UnmanagedType.I1)] bool forceReload);

        [DllImport("uxtheme.dll", EntryPoint = "#96", CharSet = CharSet.Unicode, ExactSpelling = true)]
        public static extern int GetImmersiveColorTypeFromName(string name);

        [DllImport("uxtheme.dll", ExactSpelling = true)]
        public static extern uint GetColorFromPreference(ref ImmersiveColorPreference pref, int colorType,
            [MarshalAs(UnmanagedType.I1)] bool ignoreHighContrast, int cacheMode);

        [DllImport("ole32.dll", PreserveSig = true)]
        private static extern int CoCreateInstance(ref Guid clsid, IntPtr outer, uint context, ref Guid iid, out IntPtr instance);

        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int SHCreateStreamOnFileEx(string path, uint mode, uint attributes,
            [MarshalAs(UnmanagedType.Bool)] bool create, IStream template, out IStream stream);

        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr OpenColorProfileW(ref MscmsProfile profile, uint access, uint share, uint creation);
        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool CloseColorProfile(IntPtr profile);
        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr CreateMultiProfileTransform([In] IntPtr[] profiles, uint count,
            [In] uint[] intents, uint intentCount, uint flags, uint preferredCmm);
        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool DeleteColorTransform(IntPtr transform);
        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool TranslateBitmapBits(IntPtr transform, [In] byte[] input, uint inputFormat,
            uint width, uint height, uint inputStride, [Out] byte[] output, uint outputFormat,
            uint outputStride, IntPtr callback, IntPtr callbackData);
        [DllImport("mscms.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool CreateDeviceLinkProfile([In] IntPtr[] profiles, uint count,
            [In] uint[] intents, uint intentCount, uint flags, out IntPtr data, uint preferredCmm);
        [DllImport("mscms.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern bool GetColorDirectoryW(string machine, StringBuilder name, ref uint size);
        [DllImport("mscms.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern bool GetStandardColorSpaceProfileW(string machine, uint space, StringBuilder name, ref uint size);
        [DllImport("kernel32.dll", ExactSpelling = true)]
        private static extern IntPtr GlobalFree(IntPtr data);
        [DllImport("kernel32.dll", ExactSpelling = true)]
        private static extern UIntPtr GlobalSize(IntPtr data);

        public static string Sha256Hex(byte[] data)
        {
            using (SHA256 sha = SHA256.Create())
            {
                return BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "");
            }
        }

        public static string ColorRefToArgbHex(uint colorRef)
        {
            uint a = (colorRef >> 24) & 0xFFu;
            uint b = (colorRef >> 16) & 0xFFu;
            uint g = (colorRef >> 8) & 0xFFu;
            uint r = colorRef & 0xFFu;
            return string.Format("#{0:X2}{1:X2}{2:X2}{3:X2}", a, r, g, b);
        }

        public static uint HexRgbToColorRef(string hexRgb)
        {
            string clean = hexRgb.TrimStart('#');
            uint rgb = Convert.ToUInt32(clean, 16);
            uint r = (rgb >> 16) & 0xFFu;
            uint g = (rgb >> 8) & 0xFFu;
            uint b = rgb & 0xFFu;
            return 0xFF000000u | (b << 16) | (g << 8) | r;
        }

        public static Dictionary<string, string> QueryRampForHex(string hexRgb, int[] typeIds, string[] roleNames)
        {
            uint cref = HexRgbToColorRef(hexRgb);
            ImmersiveColorPreference pref = new ImmersiveColorPreference { crStartColor = cref, crAccentColor = cref };
            return QueryRampForPref(pref, typeIds, roleNames);
        }

        public static Dictionary<string, string> QueryRampForPref(ImmersiveColorPreference pref, int[] typeIds, string[] roleNames)
        {
            Dictionary<string, string> result = new Dictionary<string, string>();
            for (int i = 0; i < roleNames.Length; i++)
            {
                uint raw = GetColorFromPreference(ref pref, typeIds[i], true, 1);
                result[roleNames[i]] = ColorRefToArgbHex(raw);
            }
            return result;
        }

        public static string GetCurrentWallpaper()
        {
            IDesktopWallpaperPublic api = (IDesktopWallpaperPublic)Activator.CreateInstance(
                Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")));
            IntPtr ptr = IntPtr.Zero;
            try
            {
                int hr = api.GetWallpaper(null, out ptr);
                Marshal.ThrowExceptionForHR(hr);
                if (ptr == IntPtr.Zero) return null;
                return Marshal.PtrToStringUni(ptr);
            }
            finally
            {
                if (ptr != IntPtr.Zero) Marshal.FreeCoTaskMem(ptr);
                if (api != null) Marshal.ReleaseComObject(api);
            }
        }

        public static void SetCurrentWallpaper(string path)
        {
            IDesktopWallpaperPublic api = (IDesktopWallpaperPublic)Activator.CreateInstance(
                Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")));
            try
            {
                int hr = api.SetWallpaper(null, path);
                Marshal.ThrowExceptionForHR(hr);
            }
            finally
            {
                if (api != null) Marshal.ReleaseComObject(api);
            }
        }

        public static Dictionary<string, object> ComputeNativeAutoColor()
        {
            Dictionary<string, object> info = new Dictionary<string, object>();
            IntPtr pointer = IntPtr.Zero;
            object instance = null;
            try
            {
                Guid clsid = new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD");
                Guid iid = new Guid("C182461F-DFAC-4375-AB6E-4CC45AA7F9CC");
                int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 0x4, ref iid, out pointer);
                info["hresult"] = string.Format("0x{0:X8}", (uint)hr);
                if (hr < 0)
                {
                    info["status"] = "failed";
                    return info;
                }
                instance = Marshal.GetObjectForIUnknown(pointer);
                IDesktopWallpaperPrivate priv = (IDesktopWallpaperPrivate)instance;
                uint color;
                int hr2 = priv.ComputeImageColorizationColor(out color);
                info["hresult"] = string.Format("0x{0:X8}", (uint)hr2);
                if (hr2 < 0)
                {
                    info["status"] = "failed";
                    return info;
                }
                info["status"] = "ok";
                info["argb_hex"] = string.Format("#{0:X8}", color);
                info["rgb_hex"] = string.Format("#{0:X6}", color & 0x00FFFFFFu);
                info["alpha"] = (int)((color >> 24) & 0xFFu);
                return info;
            }
            finally
            {
                if (instance != null && Marshal.IsComObject(instance))
                {
                    try { Marshal.ReleaseComObject(instance); } catch { }
                }
                if (pointer != IntPtr.Zero)
                {
                    try { Marshal.Release(pointer); } catch { }
                }
            }
        }

        public static Dictionary<string, object> InspectWicScaled256(string path)
        {
            IStream stream = null;
            IWicFactory factory = null;
            IWicDecoder decoder = null;
            IWicFrame frame = null;
            IWicScaler scaler = null;
            IWicConverter converter = null;
            GCHandle pin = default(GCHandle);
            try
            {
                Marshal.ThrowExceptionForHR(SHCreateStreamOnFileEx(path, 0x20, 0, false, null, out stream));
                factory = (IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                factory.CreateDecoderFromStream(stream, IntPtr.Zero, 0, out decoder);
                decoder.GetFrame(0, out frame);
                uint sw, sh;
                Guid srcFmt, scaledFmt;
                frame.GetSize(out sw, out sh);
                frame.GetPixelFormat(out srcFmt);
                uint tw = Math.Min(256u, sw);
                uint th = Math.Min(256u, sh);
                factory.CreateBitmapScaler(out scaler);
                scaler.Initialize((IWicSource)frame, tw, th, 1); // WICBitmapInterpolationModeLinear
                scaler.GetPixelFormat(out scaledFmt);
                factory.CreateFormatConverter(out converter);
                Guid bgr32 = new Guid("6fddc324-4e03-4bfe-b185-3d77768dc90e"); // GUID_WICPixelFormat32bppBGR
                converter.Initialize((IWicSource)scaler, ref bgr32, 0, IntPtr.Zero, 0.0, 0);
                byte[] pixels = new byte[checked((int)(tw * th * 4))];
                pin = GCHandle.Alloc(pixels, GCHandleType.Pinned);
                converter.CopyPixels(IntPtr.Zero, tw * 4, (uint)pixels.Length, pin.AddrOfPinnedObject());
                Dictionary<string, object> res = new Dictionary<string, object>();
                res["source_width"] = sw;
                res["source_height"] = sh;
                res["scaled_width"] = tw;
                res["scaled_height"] = th;
                res["source_pixel_format"] = srcFmt.ToString();
                res["scaled_pixel_format"] = scaledFmt.ToString();
                res["bgr32_sha256"] = Sha256Hex(pixels);
                res["sample_top_left_bgra"] = string.Format("{0:X2}{1:X2}{2:X2}{3:X2}", pixels[0], pixels[1], pixels[2], pixels[3]);
                int mid = ((int)(th / 2) * (int)tw + (int)(tw / 2)) * 4;
                res["sample_center_bgra"] = string.Format("{0:X2}{1:X2}{2:X2}{3:X2}", pixels[mid], pixels[mid + 1], pixels[mid + 2], pixels[mid + 3]);
                return res;
            }
            finally
            {
                if (pin.IsAllocated) pin.Free();
                foreach (object comObj in new object[] { converter, scaler, frame, decoder, factory, stream })
                {
                    if (comObj != null) Marshal.ReleaseComObject(comObj);
                }
            }
        }

        // Write straight-RGBA PNG preserving exact RGB bytes even where alpha == 0 (for D06-D08).
        private static void WriteU32BE(Stream s, uint v)
        {
            s.WriteByte((byte)(v >> 24));
            s.WriteByte((byte)(v >> 16));
            s.WriteByte((byte)(v >> 8));
            s.WriteByte((byte)v);
        }

        private static uint UpdateCrc(uint crc, byte[] buf)
        {
            for (int i = 0; i < buf.Length; i++)
            {
                crc ^= buf[i];
                for (int b = 0; b < 8; b++)
                    crc = (crc >> 1) ^ ((crc & 1u) != 0 ? 0xEDB88320u : 0u);
            }
            return crc;
        }

        private static void WritePngChunk(Stream s, string tag, byte[] data)
        {
            byte[] tagBytes = Encoding.ASCII.GetBytes(tag);
            WriteU32BE(s, (uint)data.Length);
            s.Write(tagBytes, 0, 4);
            s.Write(data, 0, data.Length);
            uint crc = UpdateCrc(UpdateCrc(0xFFFFFFFFu, tagBytes), data) ^ 0xFFFFFFFFu;
            WriteU32BE(s, crc);
        }

        public static void WriteControlledRgbaPng(string path, int width, int height,
            uint topRgba, uint bottomRgba, int splitRow)
        {
            int stride = width * 4 + 1;
            byte[] raw = new byte[stride * height];
            for (int y = 0; y < height; y++)
            {
                int rowOff = y * stride;
                raw[rowOff] = 0; // filter None
                uint c = (y < splitRow) ? topRgba : bottomRgba;
                byte r = (byte)((c >> 24) & 0xFF);
                byte g = (byte)((c >> 16) & 0xFF);
                byte b = (byte)((c >> 8) & 0xFF);
                byte a = (byte)(c & 0xFF);
                for (int x = 0; x < width; x++)
                {
                    int p = rowOff + 1 + x * 4;
                    raw[p] = r; raw[p + 1] = g; raw[p + 2] = b; raw[p + 3] = a;
                }
            }
            byte[] compressed;
            using (MemoryStream z = new MemoryStream())
            {
                z.WriteByte(0x78); z.WriteByte(0x9C);
                using (DeflateStream d = new DeflateStream(z, CompressionMode.Compress, true))
                {
                    d.Write(raw, 0, raw.Length);
                }
                uint s1 = 1, s2 = 0;
                for (int i = 0; i < raw.Length; i++)
                {
                    s1 = (s1 + raw[i]) % 65521u;
                    s2 = (s2 + s1) % 65521u;
                }
                WriteU32BE(z, (s2 << 16) | s1);
                compressed = z.ToArray();
            }
            using (FileStream fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            {
                byte[] sig = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
                fs.Write(sig, 0, sig.Length);
                using (MemoryStream ihdr = new MemoryStream())
                {
                    WriteU32BE(ihdr, (uint)width);
                    WriteU32BE(ihdr, (uint)height);
                    ihdr.WriteByte(8); ihdr.WriteByte(6); ihdr.WriteByte(0); ihdr.WriteByte(0); ihdr.WriteByte(0);
                    WritePngChunk(fs, "IHDR", ihdr.ToArray());
                }
                WritePngChunk(fs, "IDAT", compressed);
                WritePngChunk(fs, "IEND", new byte[0]);
            }
        }

        public static void WritePngBackedIco(string icoPath, string pngPath)
        {
            byte[] pngBytes = File.ReadAllBytes(pngPath);
            using (FileStream fs = new FileStream(icoPath, FileMode.Create, FileAccess.Write))
            using (BinaryWriter bw = new BinaryWriter(fs))
            {
                bw.Write((ushort)0);
                bw.Write((ushort)1);
                bw.Write((ushort)1);
                bw.Write((byte)0); // 256px
                bw.Write((byte)0); // 256px
                bw.Write((byte)0);
                bw.Write((byte)0);
                bw.Write((ushort)1);
                bw.Write((ushort)32);
                bw.Write((uint)pngBytes.Length);
                bw.Write((uint)22);
                bw.Write(pngBytes);
            }
        }

        // Uncompressed Baseline TIFF RGBA writer preserving straight unassociated alpha (ExtraSamples = 2).
        public static void WriteStraightRgbaTiff(string path, int width, int height,
            uint topRgba, uint bottomRgba, int splitRow)
        {
            byte[] pixels = new byte[width * height * 4];
            for (int y = 0; y < height; y++)
            {
                uint c = (y < splitRow) ? topRgba : bottomRgba;
                byte r = (byte)((c >> 24) & 0xFF);
                byte g = (byte)((c >> 16) & 0xFF);
                byte b = (byte)((c >> 8) & 0xFF);
                byte a = (byte)(c & 0xFF);
                for (int x = 0; x < width; x++)
                {
                    int p = (y * width + x) * 4;
                    pixels[p] = r; pixels[p + 1] = g; pixels[p + 2] = b; pixels[p + 3] = a;
                }
            }
            using (FileStream fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            using (BinaryWriter bw = new BinaryWriter(fs))
            {
                // Little-endian TIFF header: II, 42, IFD at offset 8
                bw.Write((byte)'I'); bw.Write((byte)'I');
                bw.Write((ushort)42);
                bw.Write((uint)8);
                ushort tagCount = 13;
                bw.Write(tagCount);
                uint afterIfd = 8u + 2u + (uint)tagCount * 12u + 4u;
                uint bpsOffset = afterIfd;        // 4 ushorts = 8 bytes
                uint xresOffset = bpsOffset + 8u; // 2 uints = 8 bytes
                uint yresOffset = xresOffset + 8u;// 2 uints = 8 bytes
                uint dataOffset = yresOffset + 8u;

                Action<ushort, ushort, uint, uint> entry = delegate(ushort tag, ushort type, uint count, uint valOrOff)
                {
                    bw.Write(tag); bw.Write(type); bw.Write(count); bw.Write(valOrOff);
                };
                entry(256, 4, 1, (uint)width);               // ImageWidth
                entry(257, 4, 1, (uint)height);              // ImageLength
                entry(258, 3, 4, bpsOffset);                 // BitsPerSample (8,8,8,8)
                entry(259, 3, 1, 1u);                        // Compression = None
                entry(262, 3, 1, 2u);                        // Photometric = RGB
                entry(273, 4, 1, dataOffset);                // StripOffsets
                entry(277, 3, 1, 4u);                        // SamplesPerPixel = 4
                entry(278, 4, 1, (uint)height);              // RowsPerStrip
                entry(279, 4, 1, (uint)pixels.Length);       // StripByteCounts
                entry(282, 5, 1, xresOffset);                // XResolution
                entry(283, 5, 1, yresOffset);                // YResolution
                entry(284, 3, 1, 1u);                        // PlanarConfiguration = Chunky
                entry(338, 3, 1, 2u);                        // ExtraSamples = 2 (Unassociated / straight alpha)
                bw.Write((uint)0);                           // Next IFD = 0
                bw.Write((ushort)8); bw.Write((ushort)8); bw.Write((ushort)8); bw.Write((ushort)8);
                bw.Write((uint)96); bw.Write((uint)1);
                bw.Write((uint)96); bw.Write((uint)1);
                bw.Write(pixels);
            }
        }

        // --- Synthetic ICC Builders for D11 (mft2 3x4x5, mft1 3x3x3) and D12 (ICC v4 mAB) ---
        private static byte[] BuildIccProfile(uint versionBcd, string devClass, string colorSpace, string pcs,
            List<KeyValuePair<string, byte[]>> tags)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                // 128-byte ICC header
                byte[] hdr = new byte[128];
                Action<int, uint> putU32 = delegate(int off, uint val)
                {
                    hdr[off] = (byte)(val >> 24);
                    hdr[off + 1] = (byte)(val >> 16);
                    hdr[off + 2] = (byte)(val >> 8);
                    hdr[off + 3] = (byte)val;
                };
                Action<int, string> putSig = delegate(int off, string sig)
                {
                    byte[] b = Encoding.ASCII.GetBytes(sig);
                    Buffer.BlockCopy(b, 0, hdr, off, 4);
                };
                putSig(4, "lcms");
                putU32(8, versionBcd);
                putSig(12, devClass);
                putSig(16, colorSpace);
                putSig(20, pcs);
                // Date 2026-01-01
                hdr[24] = 0x07; hdr[25] = 0xEA; hdr[27] = 1; hdr[29] = 1;
                putSig(36, "acsp");
                putSig(40, "MSFT");
                // D50 illuminant (0.9642, 1.0000, 0.8249 in s15Fixed16)
                putU32(68, 0x0000F6D6u);
                putU32(72, 0x00010000u);
                putU32(76, 0x0000D32Du);

                uint tagCount = (uint)tags.Count;
                uint offset = 128u + 4u + tagCount * 12u;
                List<uint> offsets = new List<uint>();
                List<uint> sizes = new List<uint>();
                for (int i = 0; i < tags.Count; i++)
                {
                    offsets.Add(offset);
                    uint sz = (uint)tags[i].Value.Length;
                    sizes.Add(sz);
                    offset += (sz + 3u) & ~3u;
                }
                putU32(0, offset);
                ms.Write(hdr, 0, 128);
                WriteU32BE(ms, tagCount);
                for (int i = 0; i < tags.Count; i++)
                {
                    byte[] sig = Encoding.ASCII.GetBytes(tags[i].Key);
                    ms.Write(sig, 0, 4);
                    WriteU32BE(ms, offsets[i]);
                    WriteU32BE(ms, sizes[i]);
                }
                for (int i = 0; i < tags.Count; i++)
                {
                    byte[] payload = tags[i].Value;
                    ms.Write(payload, 0, payload.Length);
                    int pad = (4 - (payload.Length % 4)) % 4;
                    for (int p = 0; p < pad; p++) ms.WriteByte(0);
                }
                return ms.ToArray();
            }
        }

        private static byte[] MakeDescTagV2(string asciiText)
        {
            byte[] ascii = Encoding.ASCII.GetBytes(asciiText + "\0");
            using (MemoryStream ms = new MemoryStream())
            {
                ms.Write(Encoding.ASCII.GetBytes("desc"), 0, 4);
                WriteU32BE(ms, 0);
                WriteU32BE(ms, (uint)ascii.Length);
                ms.Write(ascii, 0, ascii.Length);
                // Unicode + ScriptCode empty placeholders (4 + 4 + 2 + 1 + 67 = 78 bytes)
                ms.Write(new byte[78], 0, 78);
                return ms.ToArray();
            }
        }

        private static byte[] MakeMlucTag(string text)
        {
            byte[] utf16 = Encoding.BigEndianUnicode.GetBytes(text);
            using (MemoryStream ms = new MemoryStream())
            {
                ms.Write(Encoding.ASCII.GetBytes("mluc"), 0, 4);
                WriteU32BE(ms, 0);
                WriteU32BE(ms, 1);
                WriteU32BE(ms, 12);
                ms.Write(Encoding.ASCII.GetBytes("enUS"), 0, 4);
                WriteU32BE(ms, (uint)utf16.Length);
                WriteU32BE(ms, 28);
                ms.Write(utf16, 0, utf16.Length);
                return ms.ToArray();
            }
        }

        private static byte[] MakeXyzTag(uint x, uint y, uint z)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                ms.Write(Encoding.ASCII.GetBytes("XYZ "), 0, 4);
                WriteU32BE(ms, 0);
                WriteU32BE(ms, x);
                WriteU32BE(ms, y);
                WriteU32BE(ms, z);
                return ms.ToArray();
            }
        }

        private static ushort EncodePcsXyzU16(double v)
        {
            // ICC PCS XYZ u1.15 encoding: [0, 1 + 32767/32768] -> [0, 65535]
            int q = (int)Math.Round(v * 32768.0);
            if (q < 0) q = 0;
            if (q > 65535) q = 65535;
            return (ushort)q;
        }

        private static void SrgbLinearToD50Xyz(double rLin, double gLin, double bLin, out double X, out double Y, out double Z)
        {
            // D50-adapted sRGB matrix so CLUT outputs map cleanly inside sRGB gamut without clipping
            X = 0.4360747 * rLin + 0.3850649 * gLin + 0.1430804 * bLin;
            Y = 0.2225045 * rLin + 0.7168786 * gLin + 0.0606169 * bLin;
            Z = 0.0139322 * rLin + 0.0971045 * gLin + 0.7141733 * bLin;
        }

        // D11: Asymmetric 3x4x5 mft2 RGB->XYZ profile with non-linear curved CLUT nodes to expose
        // exact grid coordinate scaling and tetrahedral vs trilinear interpolation!
        public static byte[] BuildMft2AsymmetricProfile(int g0, int g1, int g2)
        {
            using (MemoryStream lut = new MemoryStream())
            {
                lut.Write(Encoding.ASCII.GetBytes("mft2"), 0, 4);
                WriteU32BE(lut, 0);
                lut.WriteByte(3); // in channels
                lut.WriteByte(3); // out channels
                lut.WriteByte((byte)g0); // uniform header grid field (mft2 uses uniform g; test g0 when g0==g1==g2)
                lut.WriteByte(0);
                // Identity 3x3 matrix
                uint[] mat = new uint[] {
                    0x00010000u, 0, 0,
                    0, 0x00010000u, 0,
                    0, 0, 0x00010000u
                };
                for (int i = 0; i < 9; i++) WriteU32BE(lut, mat[i]);
                // Input table entries = 256, Output table entries = 256
                Action<ushort> writeU16 = delegate(ushort v)
                {
                    lut.WriteByte((byte)(v >> 8));
                    lut.WriteByte((byte)v);
                };
                writeU16(256);
                writeU16(256);
                // Input curves: slightly curved (x^1.2) on R, identity on G, (x^0.85) on B
                for (int c = 0; c < 3; c++)
                {
                    for (int i = 0; i < 256; i++)
                    {
                        double t = i / 255.0;
                        double y = (c == 0) ? Math.Pow(t, 1.2) : ((c == 1) ? t : Math.Pow(t, 0.85));
                        writeU16((ushort)Math.Round(y * 65535.0));
                    }
                }
                int g = g0;
                for (int ir = 0; ir < g; ir++)
                for (int ig = 0; ig < g; ig++)
                for (int ib = 0; ib < g; ib++)
                {
                    double fr = ir / (double)(g - 1);
                    double fg = ig / (double)(g - 1);
                    double fb = ib / (double)(g - 1);
                    // Non-separable cross-term so tetrahedral vs trilinear differs by several 8-bit steps!
                    double rl = 0.10 + 0.75 * fr * fr + 0.10 * fg * fb;
                    double gl = 0.08 + 0.78 * fg + 0.08 * fr * (1.0 - fb);
                    double bl = 0.12 + 0.72 * Math.Sqrt(fb) + 0.10 * fr * fg;
                    double X, Y, Z;
                    SrgbLinearToD50Xyz(rl, gl, bl, out X, out Y, out Z);
                    writeU16(EncodePcsXyzU16(X));
                    writeU16(EncodePcsXyzU16(Y));
                    writeU16(EncodePcsXyzU16(Z));
                }
                // Output table: identity 0..65535
                for (int c = 0; c < 3; c++)
                {
                    for (int i = 0; i < 256; i++)
                    {
                        writeU16((ushort)(i * 257));
                    }
                }
                byte[] lutBytes = lut.ToArray();
                List<KeyValuePair<string, byte[]>> tags = new List<KeyValuePair<string, byte[]>>();
                tags.Add(new KeyValuePair<string, byte[]>("desc", MakeDescTagV2("wm-mft2-grid-" + g)));
                tags.Add(new KeyValuePair<string, byte[]>("cprt", MakeDescTagV2("public-domain")));
                tags.Add(new KeyValuePair<string, byte[]>("wtpt", MakeXyzTag(0x0000F6D6u, 0x00010000u, 0x0000D32Du)));
                tags.Add(new KeyValuePair<string, byte[]>("A2B0", lutBytes));
                return BuildIccProfile(0x02400000u, "mntr", "RGB ", "XYZ ", tags);
            }
        }

        // D11: mft1 (8-bit LUT) RGB->Lab profile (PCS = 'Lab ')
        public static byte[] BuildMft1LabProfile(int g)
        {
            using (MemoryStream lut = new MemoryStream())
            {
                lut.Write(Encoding.ASCII.GetBytes("mft1"), 0, 4);
                WriteU32BE(lut, 0);
                lut.WriteByte(3);
                lut.WriteByte(3);
                lut.WriteByte((byte)g);
                lut.WriteByte(0);
                uint[] mat = new uint[] {
                    0x00010000u, 0, 0,
                    0, 0x00010000u, 0,
                    0, 0, 0x00010000u
                };
                for (int i = 0; i < 9; i++) WriteU32BE(lut, mat[i]);
                for (int c = 0; c < 3; c++)
                    for (int i = 0; i < 256; i++)
                        lut.WriteByte((byte)i);
                for (int ir = 0; ir < g; ir++)
                for (int ig = 0; ig < g; ig++)
                for (int ib = 0; ib < g; ib++)
                {
                    double fr = ir / (double)(g - 1);
                    double fg = ig / (double)(g - 1);
                    double fb = ib / (double)(g - 1);
                    byte L = (byte)Math.Round((20.0 + 70.0 * (0.3 * fr + 0.5 * fg + 0.2 * fb)) * 255.0 / 100.0);
                    byte a = (byte)Math.Round(128.0 + 40.0 * (fr - fg));
                    byte b = (byte)Math.Round(128.0 + 40.0 * (fg - fb));
                    lut.WriteByte(L); lut.WriteByte(a); lut.WriteByte(b);
                }
                for (int c = 0; c < 3; c++)
                    for (int i = 0; i < 256; i++)
                        lut.WriteByte((byte)i);
                List<KeyValuePair<string, byte[]>> tags = new List<KeyValuePair<string, byte[]>>();
                tags.Add(new KeyValuePair<string, byte[]>("desc", MakeDescTagV2("wm-mft1-lab-" + g)));
                tags.Add(new KeyValuePair<string, byte[]>("cprt", MakeDescTagV2("public-domain")));
                tags.Add(new KeyValuePair<string, byte[]>("wtpt", MakeXyzTag(0x0000F6D6u, 0x00010000u, 0x0000D32Du)));
                tags.Add(new KeyValuePair<string, byte[]>("A2B0", lut.ToArray()));
                return BuildIccProfile(0x02400000u, "mntr", "RGB ", "Lab ", tags);
            }
        }

        // D12: ICC v4.3 'mAB ' profile with asymmetric per-axis grid [3, 4, 5], B-curves + CLUT + A-curves!
        public static byte[] BuildV4LutAToBProfile(int g0, int g1, int g2)
        {
            using (MemoryStream mab = new MemoryStream())
            {
                mab.Write(Encoding.ASCII.GetBytes("mAB "), 0, 4);
                WriteU32BE(mab, 0);
                mab.WriteByte(3); // in channels
                mab.WriteByte(3); // out channels
                mab.WriteByte(0); mab.WriteByte(0);
                // Header is 32 bytes: [0..11], [12..15]=BcurvesOff, [16..19]=MatrixOff, [20..23]=McurvesOff, [24..27]=CLUTOff, [28..31]=AcurvesOff
                // Each identity 'curv' (count=0) is 12 bytes (4-byte aligned); 3 curves = 36 bytes.
                uint aCurvesOff = 32u;
                uint clutOff = aCurvesOff + 36u;
                int clutPoints = g0 * g1 * g2 * 3;
                uint clutBytesLen = 20u + (uint)(clutPoints * 2);
                uint clutPaddedLen = (clutBytesLen + 3u) & ~3u;
                uint bCurvesOff = clutOff + clutPaddedLen;

                WriteU32BE(mab, bCurvesOff); // B curves
                WriteU32BE(mab, 0u);         // Matrix (unused)
                WriteU32BE(mab, 0u);         // M curves (unused)
                WriteU32BE(mab, clutOff);    // CLUT
                WriteU32BE(mab, aCurvesOff); // A curves

                Action writeThreeGammaCurves = delegate()
                {
                    ushort[] gammas = new ushort[] { 0x0100, 0x0133, 0x0180 }; // 1.0, ~1.2, 1.5 in u8Fixed8
                    for (int c = 0; c < 3; c++)
                    {
                        mab.Write(Encoding.ASCII.GetBytes("curv"), 0, 4);
                        WriteU32BE(mab, 0);
                        WriteU32BE(mab, 1);
                        mab.WriteByte((byte)(gammas[c] >> 8));
                        mab.WriteByte((byte)gammas[c]);
                        mab.WriteByte(0); mab.WriteByte(0); // 4-byte pad -> 16 bytes each? Wait: 4+4+4+2+2 = 16 bytes!
                    }
                };
                // Wait: 3 * 16 = 48 bytes -> adjust clutOff & bCurvesOff!
                mab.SetLength(0);
                aCurvesOff = 32u;
                clutOff = aCurvesOff + 48u;
                bCurvesOff = clutOff + clutPaddedLen;
                mab.Write(Encoding.ASCII.GetBytes("mAB "), 0, 4);
                WriteU32BE(mab, 0);
                mab.WriteByte(3); mab.WriteByte(3); mab.WriteByte(0); mab.WriteByte(0);
                WriteU32BE(mab, bCurvesOff);
                WriteU32BE(mab, 0u);
                WriteU32BE(mab, 0u);
                WriteU32BE(mab, clutOff);
                WriteU32BE(mab, aCurvesOff);

                writeThreeGammaCurves();

                // CLUT block: 16 bytes gridPoints + 1 byte precision (2 = u16) + 3 pad bytes + data
                byte[] gp = new byte[16];
                gp[0] = (byte)g0; gp[1] = (byte)g1; gp[2] = (byte)g2;
                mab.Write(gp, 0, 16);
                mab.WriteByte(2); mab.WriteByte(0); mab.WriteByte(0); mab.WriteByte(0);
                for (int ir = 0; ir < g0; ir++)
                for (int ig = 0; ig < g1; ig++)
                for (int ib = 0; ib < g2; ib++)
                {
                    double fr = ir / (double)(g0 - 1);
                    double fg = ig / (double)(g1 - 1);
                    double fb = ib / (double)(g2 - 1);
                    double rl = 0.08 + 0.76 * fr + 0.08 * fg * fb;
                    double gl = 0.10 + 0.74 * fg + 0.08 * fr * fb;
                    double bl = 0.12 + 0.70 * fb + 0.09 * fr * (1.0 - fg);
                    double X, Y, Z;
                    SrgbLinearToD50Xyz(rl, gl, bl, out X, out Y, out Z);
                    ushort ux = EncodePcsXyzU16(X);
                    ushort uy = EncodePcsXyzU16(Y);
                    ushort uz = EncodePcsXyzU16(Z);
                    mab.WriteByte((byte)(ux >> 8)); mab.WriteByte((byte)ux);
                    mab.WriteByte((byte)(uy >> 8)); mab.WriteByte((byte)uy);
                    mab.WriteByte((byte)(uz >> 8)); mab.WriteByte((byte)uz);
                }
                while ((mab.Length % 4) != 0) mab.WriteByte(0);

                // B curves: 3 identity curves (count = 0 -> 12 bytes each)
                for (int c = 0; c < 3; c++)
                {
                    mab.Write(Encoding.ASCII.GetBytes("curv"), 0, 4);
                    WriteU32BE(mab, 0);
                    WriteU32BE(mab, 0);
                }

                List<KeyValuePair<string, byte[]>> tags = new List<KeyValuePair<string, byte[]>>();
                tags.Add(new KeyValuePair<string, byte[]>("desc", MakeMlucTag(string.Format("wm-v4-mAB-{0}x{1}x{2}", g0, g1, g2))));
                tags.Add(new KeyValuePair<string, byte[]>("cprt", MakeMlucTag("Public domain diagnostic profile")));
                tags.Add(new KeyValuePair<string, byte[]>("wtpt", MakeXyzTag(0x0000F6D6u, 0x00010000u, 0x0000D32Du)));
                tags.Add(new KeyValuePair<string, byte[]>("A2B0", mab.ToArray()));
                return BuildIccProfile(0x04300000u, "mntr", "RGB ", "XYZ ", tags);
            }
        }

        public static byte[] CalibrationAndGridRgb()
        {
            // 1024 axis/ramp colors + 512 8x8x8 interior grid colors = 1536 RGB triplets (4608 bytes)
            List<byte> bytes = new List<byte>(4608);
            for (int i = 0; i < 256; i++)
            {
                bytes.Add((byte)i); bytes.Add((byte)i); bytes.Add((byte)i);
                bytes.Add((byte)i); bytes.Add(0); bytes.Add(0);
                bytes.Add(0); bytes.Add((byte)i); bytes.Add(0);
                bytes.Add(0); bytes.Add(0); bytes.Add((byte)i);
            }
            for (int r = 0; r < 8; r++)
            for (int g = 0; g < 8; g++)
            for (int b = 0; b < 8; b++)
            {
                bytes.Add((byte)(13 + r * 32));
                bytes.Add((byte)(21 + g * 31));
                bytes.Add((byte)(7 + b * 34));
            }
            return bytes.ToArray();
        }

        public static byte[] RegisteredSrgbProfile()
        {
            uint size = 0;
            GetStandardColorSpaceProfileW(null, 0x73524742u, null, ref size);
            StringBuilder sb = new StringBuilder(checked((int)size + 2));
            if (!GetStandardColorSpaceProfileW(null, 0x73524742u, sb, ref size))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            string p = sb.ToString();
            if (!Path.IsPathRooted(p))
            {
                uint dirSz = 0;
                GetColorDirectoryW(null, null, ref dirSz);
                StringBuilder dir = new StringBuilder(checked((int)dirSz + 2));
                if (!GetColorDirectoryW(null, dir, ref dirSz))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                p = Path.Combine(dir.ToString(), p);
            }
            return File.ReadAllBytes(p);
        }

        public static byte[] InstalledColorProfileIfPresent(string fileName)
        {
            uint dirSz = 0;
            GetColorDirectoryW(null, null, ref dirSz);
            StringBuilder dir = new StringBuilder(checked((int)dirSz + 2));
            if (!GetColorDirectoryW(null, dir, ref dirSz)) return null;
            string full = Path.Combine(dir.ToString(), fileName);
            if (!File.Exists(full)) return null;
            return File.ReadAllBytes(full);
        }

        private static IntPtr OpenMemProfile(byte[] data, out GCHandle pin)
        {
            pin = GCHandle.Alloc(data, GCHandleType.Pinned);
            MscmsProfile prof = new MscmsProfile { Type = 2, Data = pin.AddrOfPinnedObject(), Size = (uint)data.Length };
            IntPtr h = OpenColorProfileW(ref prof, 1, 1, 3);
            if (h == IntPtr.Zero)
            {
                int err = Marshal.GetLastWin32Error();
                pin.Free();
                throw new Win32Exception(err);
            }
            return h;
        }

        public static Dictionary<string, object> ProbeRgbIccProfile(byte[] sourceProfile, byte[] destSrgb, byte[] rgbInput)
        {
            Dictionary<string, object> result = new Dictionary<string, object>();
            result["profile_sha256"] = Sha256Hex(sourceProfile);
            result["profile_base64"] = Convert.ToBase64String(sourceProfile);

            // 1) WIC IWICColorTransform (BGR24)
            try
            {
                int count = rgbInput.Length / 3;
                byte[] bgrIn = new byte[rgbInput.Length];
                for (int i = 0; i < rgbInput.Length; i += 3)
                {
                    bgrIn[i] = rgbInput[i + 2];
                    bgrIn[i + 1] = rgbInput[i + 1];
                    bgrIn[i + 2] = rgbInput[i];
                }
                byte[] bgrOut = new byte[bgrIn.Length];
                GCHandle inPin = GCHandle.Alloc(bgrIn, GCHandleType.Pinned);
                GCHandle outPin = GCHandle.Alloc(bgrOut, GCHandleType.Pinned);
                GCHandle srcPin = GCHandle.Alloc(sourceProfile, GCHandleType.Pinned);
                GCHandle dstPin = GCHandle.Alloc(destSrgb, GCHandleType.Pinned);
                IWicFactory factory = null;
                IWicSource bitmap = null;
                IWicContext srcCtx = null, dstCtx = null;
                IWicTransform xform = null;
                try
                {
                    Guid fmt = new Guid("6fddc324-4e03-4bfe-b185-3d77768dc90c"); // 24bppBGR
                    factory = (IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                    factory.CreateBitmapFromMemory((uint)count, 1, ref fmt, (uint)bgrIn.Length, (uint)bgrIn.Length, inPin.AddrOfPinnedObject(), out bitmap);
                    factory.CreateColorContext(out srcCtx);
                    srcCtx.InitializeFromMemory(srcPin.AddrOfPinnedObject(), (uint)sourceProfile.Length);
                    factory.CreateColorContext(out dstCtx);
                    dstCtx.InitializeFromMemory(dstPin.AddrOfPinnedObject(), (uint)destSrgb.Length);
                    factory.CreateColorTransformer(out xform);
                    xform.Initialize(bitmap, srcCtx, dstCtx, ref fmt);
                    xform.CopyPixels(IntPtr.Zero, (uint)bgrOut.Length, (uint)bgrOut.Length, outPin.AddrOfPinnedObject());
                    byte[] rgbOut = new byte[bgrOut.Length];
                    for (int i = 0; i < bgrOut.Length; i += 3)
                    {
                        rgbOut[i] = bgrOut[i + 2];
                        rgbOut[i + 1] = bgrOut[i + 1];
                        rgbOut[i + 2] = bgrOut[i];
                    }
                    result["wic_bgr24"] = new Dictionary<string, object> {
                        { "status", "ok" },
                        { "sha256", Sha256Hex(rgbOut) },
                        { "base64", Convert.ToBase64String(rgbOut) }
                    };
                }
                finally
                {
                    foreach (object o in new object[] { xform, dstCtx, srcCtx, bitmap, factory })
                        if (o != null) Marshal.ReleaseComObject(o);
                    dstPin.Free(); srcPin.Free(); outPin.Free(); inPin.Free();
                }
            }
            catch (Exception ex)
            {
                result["wic_bgr24"] = new Dictionary<string, object> {
                    { "status", "error" }, { "type", ex.GetType().FullName }, { "hresult", ex.HResult }
                };
            }

            // 2) MSCMS direct transform (intents 0 and 1, flags=3 BEST_MODE|ENABLE_GAMUT_CHECKING) + DeviceLink
            Dictionary<string, object> mscms = new Dictionary<string, object>();
            foreach (uint intent in new uint[] { 0u, 1u })
            {
                GCHandle srcPin = default(GCHandle), dstPin = default(GCHandle);
                IntPtr hSrc = IntPtr.Zero, hDst = IntPtr.Zero, hXform = IntPtr.Zero, pLink = IntPtr.Zero;
                try
                {
                    hSrc = OpenMemProfile(sourceProfile, out srcPin);
                    hDst = OpenMemProfile(destSrgb, out dstPin);
                    hXform = CreateMultiProfileTransform(new IntPtr[] { hSrc, hDst }, 2, new uint[] { intent, intent }, 2, 3u, 0u);
                    if (hXform == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                    byte[] out8 = new byte[rgbInput.Length];
                    // BM_BGRTRIPLETS (0x04) in Windows SDK corresponds to R,G,B byte order in memory.
                    if (!TranslateBitmapBits(hXform, rgbInput, 4u, (uint)(rgbInput.Length / 3), 1u, (uint)rgbInput.Length,
                        out8, 4u, (uint)out8.Length, IntPtr.Zero, IntPtr.Zero))
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    Dictionary<string, object> entry = new Dictionary<string, object> {
                        { "status", "ok" },
                        { "rgb8_sha256", Sha256Hex(out8) },
                        { "rgb8_base64", Convert.ToBase64String(out8) }
                    };
                    if (CreateDeviceLinkProfile(new IntPtr[] { hSrc, hDst }, 2, new uint[] { intent, intent }, 2, 3u, out pLink, 0u) && pLink != IntPtr.Zero)
                    {
                        byte[] hdr = new byte[4];
                        Marshal.Copy(pLink, hdr, 0, 4);
                        uint sz = ((uint)hdr[0] << 24) | ((uint)hdr[1] << 16) | ((uint)hdr[2] << 8) | hdr[3];
                        ulong alloc = GlobalSize(pLink).ToUInt64();
                        if (sz >= 132 && sz <= alloc && sz <= 4 * 1024 * 1024)
                        {
                            byte[] linkBytes = new byte[(int)sz];
                            Marshal.Copy(pLink, linkBytes, 0, (int)sz);
                            entry["device_link_sha256"] = Sha256Hex(linkBytes);
                            entry["device_link_base64"] = Convert.ToBase64String(linkBytes);
                        }
                    }
                    mscms[intent.ToString()] = entry;
                }
                catch (Exception ex)
                {
                    mscms[intent.ToString()] = new Dictionary<string, object> {
                        { "status", "error" }, { "type", ex.GetType().FullName }, { "hresult", ex.HResult }
                    };
                }
                finally
                {
                    if (pLink != IntPtr.Zero) GlobalFree(pLink);
                    if (hXform != IntPtr.Zero) DeleteColorTransform(hXform);
                    if (hDst != IntPtr.Zero) CloseColorProfile(hDst);
                    if (hSrc != IntPtr.Zero) CloseColorProfile(hSrc);
                    if (dstPin.IsAllocated) dstPin.Free();
                    if (srcPin.IsAllocated) srcPin.Free();
                }
            }
            result["mscms"] = mscms;
            return result;
        }

        public static Dictionary<string, object> ProbeCmykProfile(byte[] cmykProfile, byte[] destSrgb)
        {
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["profile_sha256"] = Sha256Hex(cmykProfile);
            // 5x5x5x5 = 625 CMYK combinations (2500 bytes)
            byte[] cmykIn = new byte[625 * 4];
            int p = 0;
            int[] steps = new int[] { 0, 64, 128, 192, 255 };
            foreach (int c in steps)
            foreach (int m in steps)
            foreach (int y in steps)
            foreach (int k in steps)
            {
                cmykIn[p++] = (byte)c; cmykIn[p++] = (byte)m; cmykIn[p++] = (byte)y; cmykIn[p++] = (byte)k;
            }
            res["input_cmyk_sha256"] = Sha256Hex(cmykIn);

            // WIC 32bppCMYK -> 24bppBGR
            try
            {
                byte[] bgrOut = new byte[625 * 3];
                GCHandle inPin = GCHandle.Alloc(cmykIn, GCHandleType.Pinned);
                GCHandle outPin = GCHandle.Alloc(bgrOut, GCHandleType.Pinned);
                GCHandle srcPin = GCHandle.Alloc(cmykProfile, GCHandleType.Pinned);
                GCHandle dstPin = GCHandle.Alloc(destSrgb, GCHandleType.Pinned);
                IWicFactory factory = null; IWicSource bmp = null; IWicContext sc = null, dc = null; IWicTransform xf = null;
                try
                {
                    Guid fmtCmyk = new Guid("6fddc324-4e03-4bfe-b185-3d77768dc91c"); // 32bppCMYK
                    Guid fmtBgr = new Guid("6fddc324-4e03-4bfe-b185-3d77768dc90c");  // 24bppBGR
                    factory = (IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                    factory.CreateBitmapFromMemory(625u, 1u, ref fmtCmyk, (uint)cmykIn.Length, (uint)cmykIn.Length, inPin.AddrOfPinnedObject(), out bmp);
                    factory.CreateColorContext(out sc);
                    sc.InitializeFromMemory(srcPin.AddrOfPinnedObject(), (uint)cmykProfile.Length);
                    factory.CreateColorContext(out dc);
                    dc.InitializeFromMemory(dstPin.AddrOfPinnedObject(), (uint)destSrgb.Length);
                    factory.CreateColorTransformer(out xf);
                    xf.Initialize(bmp, sc, dc, ref fmtBgr);
                    xf.CopyPixels(IntPtr.Zero, (uint)bgrOut.Length, (uint)bgrOut.Length, outPin.AddrOfPinnedObject());
                    byte[] rgbOut = new byte[bgrOut.Length];
                    for (int i = 0; i < bgrOut.Length; i += 3)
                    {
                        rgbOut[i] = bgrOut[i + 2]; rgbOut[i + 1] = bgrOut[i + 1]; rgbOut[i + 2] = bgrOut[i];
                    }
                    res["wic_cmyk32_to_rgb24"] = new Dictionary<string, object> {
                        { "status", "ok" }, { "sha256", Sha256Hex(rgbOut) }, { "base64", Convert.ToBase64String(rgbOut) }
                    };
                }
                finally
                {
                    foreach (object o in new object[] { xf, dc, sc, bmp, factory })
                        if (o != null) Marshal.ReleaseComObject(o);
                    dstPin.Free(); srcPin.Free(); outPin.Free(); inPin.Free();
                }
            }
            catch (Exception ex)
            {
                res["wic_cmyk32_to_rgb24"] = new Dictionary<string, object> {
                    { "status", "error" }, { "type", ex.GetType().FullName }, { "hresult", ex.HResult }
                };
            }

            // MSCMS BM_CMYKQUADS (0x20) -> BM_BGRTRIPLETS (0x04)
            GCHandle sPin = default(GCHandle), dPin = default(GCHandle);
            IntPtr hS = IntPtr.Zero, hD = IntPtr.Zero, hT = IntPtr.Zero;
            try
            {
                hS = OpenMemProfile(cmykProfile, out sPin);
                hD = OpenMemProfile(destSrgb, out dPin);
                hT = CreateMultiProfileTransform(new IntPtr[] { hS, hD }, 2, new uint[] { 1u, 1u }, 2, 3u, 0u);
                if (hT == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                byte[] rgbOut = new byte[625 * 3];
                if (!TranslateBitmapBits(hT, cmykIn, 0x20u, 625u, 1u, (uint)cmykIn.Length,
                    rgbOut, 4u, (uint)rgbOut.Length, IntPtr.Zero, IntPtr.Zero))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                res["mscms_intent1"] = new Dictionary<string, object> {
                    { "status", "ok" }, { "sha256", Sha256Hex(rgbOut) }, { "base64", Convert.ToBase64String(rgbOut) }
                };
            }
            catch (Exception ex)
            {
                res["mscms_intent1"] = new Dictionary<string, object> {
                    { "status", "error" }, { "type", ex.GetType().FullName }, { "hresult", ex.HResult }
                };
            }
            finally
            {
                if (hT != IntPtr.Zero) DeleteColorTransform(hT);
                if (hD != IntPtr.Zero) CloseColorProfile(hD);
                if (hS != IntPtr.Zero) CloseColorProfile(hS);
                if (dPin.IsAllocated) dPin.Free();
                if (sPin.IsAllocated) sPin.Free();
            }
            return res;
        }
    }
}
'@
}

$ver = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$windowsBuild = '{0}.{1}' -f $ver.CurrentBuildNumber, $ver.UBR
$displayVersion = $ver.DisplayVersion
$native = [WindowsModern.Suite26H2.NativeSuite]

Write-Host ('==> KDE-Windows-Modern 26H2 Reference Capture Suite (Windows {0}, Build {1})' -f $displayVersion, $windowsBuild)

# ---------------------------------------------------------------------------
# Phase 1: D02 Multi-Hue + CIELAB/HSL Near-Gray Manual Accent Ramp Sweep
# ---------------------------------------------------------------------------
Write-Host '  [1/3] Capturing D02 multi-hue & near-gray accent ramps via uxtheme + UISettings...'

$roleNames = @('AccentLight3', 'AccentLight2', 'AccentLight1', 'Accent', 'AccentDark1', 'AccentDark2', 'AccentDark3')
$immersiveNames = @(
    'ImmersiveSystemAccentLight3',
    'ImmersiveSystemAccentLight2',
    'ImmersiveSystemAccentLight1',
    'ImmersiveSystemAccent',
    'ImmersiveSystemAccentDark1',
    'ImmersiveSystemAccentDark2',
    'ImmersiveSystemAccentDark3'
)
[int[]]$typeIds = @()
foreach ($imName in $immersiveNames) {
    $tid = $native::GetImmersiveColorTypeFromName($imName)
    if ($tid -lt 0) {
        throw ('Failed to resolve immersive color type: ' + $imName)
    }
    $typeIds += $tid
}

$ui = [Windows.UI.ViewManagement.UISettings, Windows.UI.ViewManagement, ContentType=WindowsRuntime]::new()
$uiColorType = [Windows.UI.ViewManagement.UIColorType, Windows.UI.ViewManagement, ContentType=WindowsRuntime]
$liveUiColors = [ordered]@{}
foreach ($rn in $roleNames) {
    $c = $ui.GetColorValue([System.Enum]::Parse($uiColorType, $rn))
    $liveUiColors[$rn] = '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $c.A, $c.R, $c.G, $c.B
}

$livePref = New-Object WindowsModern.Suite26H2.ImmersiveColorPreference
$hrPref = $native::GetUserColorPreference([ref]$livePref, $true)
$liveUxthemeRamp = $native::QueryRampForPref($livePref, $typeIds, $roleNames)
$liveAgreement = $true
foreach ($rn in $roleNames) {
    if ($liveUiColors[$rn] -cne $liveUxthemeRamp[$rn]) {
        $liveAgreement = $false
    }
}

function Convert-HslToHex([double]$H, [double]$S, [double]$L) {
    $c = (1.0 - [Math]::Abs(2.0 * $L - 1.0)) * $S
    $hp = ($H % 360.0) / 60.0
    $x = $c * (1.0 - [Math]::Abs(($hp % 2.0) - 1.0))
    $r1 = 0.0; $g1 = 0.0; $b1 = 0.0
    if ($hp -lt 1.0)      { $r1 = $c; $g1 = $x; $b1 = 0.0 }
    elseif ($hp -lt 2.0)  { $r1 = $x; $g1 = $c; $b1 = 0.0 }
    elseif ($hp -lt 3.0)  { $r1 = 0.0; $g1 = $c; $b1 = $x }
    elseif ($hp -lt 4.0)  { $r1 = 0.0; $g1 = $x; $b1 = $c }
    elseif ($hp -lt 5.0)  { $r1 = $x; $g1 = 0.0; $b1 = $c }
    else                  { $r1 = $c; $g1 = 0.0; $b1 = $x }
    $m = $L - $c / 2.0
    $r = [Math]::Min(255, [Math]::Max(0, [int][Math]::Round(($r1 + $m) * 255.0)))
    $g = [Math]::Min(255, [Math]::Max(0, [int][Math]::Round(($g1 + $m) * 255.0)))
    $b = [Math]::Min(255, [Math]::Max(0, [int][Math]::Round(($b1 + $m) * 255.0)))
    return '#{0:X2}{1:X2}{2:X2}' -f $r, $g, $b
}

$colorSet = New-Object 'System.Collections.Generic.HashSet[string]'
$colorList = New-Object 'System.Collections.Generic.List[object]'
function Add-SweepColor([string]$Hex, [string]$Group) {
    $u = $Hex.ToUpperInvariant()
    if ($colorSet.Add($u)) {
        $colorList.Add([ordered]@{
            input_rgb = $u
            group = $Group
            ramp = $native::QueryRampForHex($u, $typeIds, $roleNames)
        })
    }
}

# 1a. All 48 Windows preset tiles
foreach ($p in @(
    '#FFB900','#FF8C00','#F7630C','#CA5010','#DA3B01','#EF6950','#D13438','#FF4343',
    '#E74856','#E81123','#EA005E','#C30052','#E3008C','#BF0077','#C239B3','#9A0089',
    '#0078D4','#0063B1','#8E8CD8','#6B69D6','#8764B8','#744DA9','#B146C2','#881798',
    '#0099BC','#2D7D9A','#00B7C3','#038387','#00B294','#018574','#00CC6A','#10893E',
    '#7A7574','#5D5A58','#68768A','#515C6B','#567C73','#486860','#498205','#107C10',
    '#767676','#4C4A48','#69797E','#4A5459','#647C64','#525E54','#847545','#7E735F'
)) {
    Add-SweepColor $p 'preset'
}

# 1b. 24 hues (every 15 deg) x 8 saturation/lightness combinations
$slGrid = @(
    @(1.00, 0.50), @(1.00, 0.32), @(1.00, 0.72),
    @(0.75, 0.50), @(0.50, 0.50), @(0.25, 0.50),
    @(0.12, 0.35), @(0.12, 0.70)
)
for ($hue = 0; $hue -lt 360; $hue += 15) {
    foreach ($sl in $slGrid) {
        Add-SweepColor (Convert-HslToHex $hue $sl[0] $sl[1]) 'multi_hue_grid'
    }
}

# 1c. Near-gray HSL vs CIELAB boundary sweep + neutral grays + channel rounding boundaries
foreach ($g in @(0, 1, 15, 16, 31, 32, 48, 63, 64, 96, 119, 120, 127, 128, 160, 191, 192, 224, 240, 254, 255)) {
    Add-SweepColor ('#{0:X2}{0:X2}{0:X2}' -f $g) 'neutral_gray'
}
foreach ($base in @(48, 96, 120, 160, 208)) {
    for ($delta = 1; $delta -le 18; $delta++) {
        $hi = [Math]::Min(255, $base + $delta)
        $lo = [Math]::Max(0, $base - $delta)
        $mid = $base
        Add-SweepColor ('#{0:X2}{1:X2}{2:X2}' -f $hi, $mid, $lo) 'chroma_boundary_warm'
        Add-SweepColor ('#{0:X2}{1:X2}{2:X2}' -f $lo, $mid, $hi) 'chroma_boundary_cool'
        Add-SweepColor ('#{0:X2}{1:X2}{2:X2}' -f $lo, $hi, $mid) 'chroma_boundary_green'
        Add-SweepColor ('#{0:X2}{1:X2}{2:X2}' -f $hi, $lo, $hi) 'chroma_boundary_magenta'
    }
}
foreach ($b in @('#7F0000','#800000','#FF7F7F','#FF8080','#897866','#8A7866','#8B7866')) {
    Add-SweepColor $b 'explicit_boundary'
}

$d02Section = [ordered]@{
    type_ids = $typeIds
    live_user_preference_hresult = ('0x{0:X8}' -f [uint32]$hrPref)
    live_ui_settings_matches_uxtheme = $liveAgreement
    sample_count = $colorList.Count
    samples = $colorList
}

# ---------------------------------------------------------------------------
# Phase 2: D04 / D06-D08 Automatic Wallpaper Multi-Hue & WIC Container/Alpha Sweep
# ---------------------------------------------------------------------------
$d04WallpaperSection = [ordered]@{
    status = 'skipped'
    reason = $null
    samples = @()
}

if ($SkipWallpaperSweep) {
    $d04WallpaperSection.reason = 'SkipWallpaperSweep specified'
} elseif (-not $ApplyTemporarily) {
    $d04WallpaperSection.reason = 'Pass -ApplyTemporarily to run the automatic temporary wallpaper sweep (auto-restores original wallpaper).'
} else {
    Write-Host '  [2/3] Running D04/D06-D08 synthetic multi-hue & WIC container/alpha wallpaper sweep (will restore original wallpaper)...'
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $originalWallpaper = $native::GetCurrentWallpaper()
    if ([string]::IsNullOrWhiteSpace($originalWallpaper) -or -not (Test-Path -LiteralPath $originalWallpaper -PathType Leaf)) {
        throw 'Please set a static Picture desktop background before running -ApplyTemporarily so it can be restored afterwards.'
    }
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('wm-26h2-suite-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($tempDir) | Out-Null

    function Save-TwoBandGdiImage([string]$Path, [System.Drawing.Imaging.ImageFormat]$Format,
                                  [string]$TopHex, [string]$BottomHex, [int]$SplitRow) {
        $bmp = New-Object System.Drawing.Bitmap(1280, 800, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $topColor = [System.Drawing.ColorTranslator]::FromHtml($TopHex)
                $botColor = [System.Drawing.ColorTranslator]::FromHtml($BottomHex)
                $bTop = New-Object System.Drawing.SolidBrush($topColor)
                $bBot = New-Object System.Drawing.SolidBrush($botColor)
                try {
                    $g.FillRectangle($bTop, 0, 0, 1280, $SplitRow)
                    $g.FillRectangle($bBot, 0, $SplitRow, 1280, 800 - $SplitRow)
                } finally {
                    $bTop.Dispose(); $bBot.Dispose()
                }
            } finally {
                $g.Dispose()
            }
            $bmp.Save($Path, $Format)
        } finally {
            $bmp.Dispose()
        }
    }

    try {
        $probeSpecs = @(
            @{ id = 'hue-red';            kind = 'png';  top = 0xE81123FFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-orange';         kind = 'png';  top = 0xF7630CFFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-amber';          kind = 'png';  top = 0xFFB900FFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-green';          kind = 'png';  top = 0x10893EFFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-teal';           kind = 'png';  top = 0x00B7C3FFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-blue';           kind = 'png';  top = 0x0078D4FFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-purple';         kind = 'png';  top = 0x881798FFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'hue-magenta';        kind = 'png';  top = 0xE3008CFFu; bot = 0x1E1E1EFFu; split = 600 },
            @{ id = 'pair-blue-orange';   kind = 'png';  top = 0x0078D4FFu; bot = 0xF7630CFFu; split = 460 },
            @{ id = 'pair-teal-magenta';  kind = 'png';  top = 0x00B294FFu; bot = 0xEA005EFFu; split = 440 },
            @{ id = 'pair-green-purple';  kind = 'png';  top = 0x107C10FFu; bot = 0x744DA9FFu; split = 400 },
            @{ id = 'pair-amber-crimson'; kind = 'png';  top = 0xFFB900FFu; bot = 0xD13438FFu; split = 480 },
            @{ id = 'dark-fallback';      kind = 'png';  top = 0x05080EFFu; bot = 0x040404FFu; split = 500 },
            @{ id = 'dark-edge-blue';     kind = 'png';  top = 0x0C1D36FFu; bot = 0x080808FFu; split = 500 },
            @{ id = 'bright-pastel-cyan'; kind = 'png';  top = 0xD8F6FAFFu; bot = 0xF2F2F2FFu; split = 500 },
            @{ id = 'low-chroma-gray';    kind = 'png';  top = 0x7A7A7AFFu; bot = 0x505050FFu; split = 500 },
            @{ id = 'near-gray-warm';     kind = 'png';  top = 0x827C76FFu; bot = 0x484848FFu; split = 500 },
            # D06-D08: Alpha & container probes (hidden crimson at alpha=0 vs semitransparent blue at alpha=128)
            @{ id = 'alpha-png-zero-red'; kind = 'png';  top = 0xFF000000u; bot = 0x0078D480u; split = 400 },
            @{ id = 'alpha-tiff-rgba';    kind = 'tiff'; top = 0xFF000000u; bot = 0x0078D480u; split = 400 },
            @{ id = 'format-bmp24';       kind = 'bmp';  topHex = '#00B294'; botHex = '#202020'; split = 520 },
            @{ id = 'format-jpeg';        kind = 'jpg';  topHex = '#00B294'; botHex = '#202020'; split = 520 },
            @{ id = 'format-gif';         kind = 'gif';  topHex = '#00B294'; botHex = '#202020'; split = 520 },
            @{ id = 'format-ico-png';     kind = 'ico';  top = 0xFF000000u; bot = 0x10893E80u; split = 128 }
        )

        $wpSamples = New-Object 'System.Collections.Generic.List[object]'
        $idx = 0
        foreach ($spec in $probeSpecs) {
            $idx++
            $ext = switch ($spec.kind) {
                'tiff' { '.tif' }
                'bmp'  { '.bmp' }
                'jpg'  { '.jpg' }
                'gif'  { '.gif' }
                'ico'  { '.ico' }
                default { '.png' }
            }
            $filePath = Join-Path $tempDir ('probe-{0:D2}-{1}{2}' -f $idx, $spec.id, $ext)
            switch ($spec.kind) {
                'png'  { $native::WriteControlledRgbaPng($filePath, 1280, 800, [uint32]$spec.top, [uint32]$spec.bot, [int]$spec.split) }
                'tiff' { $native::WriteStraightRgbaTiff($filePath, 1280, 800, [uint32]$spec.top, [uint32]$spec.bot, [int]$spec.split) }
                'bmp'  { Save-TwoBandGdiImage $filePath ([System.Drawing.Imaging.ImageFormat]::Bmp) $spec.topHex $spec.botHex $spec.split }
                'jpg'  { Save-TwoBandGdiImage $filePath ([System.Drawing.Imaging.ImageFormat]::Jpeg) $spec.topHex $spec.botHex $spec.split }
                'gif'  { Save-TwoBandGdiImage $filePath ([System.Drawing.Imaging.ImageFormat]::Gif) $spec.topHex $spec.botHex $spec.split }
                'ico'  {
                    $tmpPng = Join-Path $tempDir ('ico-src-{0:D2}.png' -f $idx)
                    $native::WriteControlledRgbaPng($tmpPng, 256, 256, [uint32]$spec.top, [uint32]$spec.bot, [int]$spec.split)
                    $native::WritePngBackedIco($filePath, $tmpPng)
                }
            }

            $fileSha = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
            $wicInfo = try { $native::InspectWicScaled256($filePath) } catch { @{ status = 'wic_error'; message = $_.Exception.Message } }

            $setStatus = 'ok'
            $autoColor = $null
            $uiSnap = $null
            try {
                $native::SetCurrentWallpaper($filePath)
                Start-Sleep -Milliseconds 650
                $autoColor = $native::ComputeNativeAutoColor()
                Start-Sleep -Milliseconds 250
                $uiNow = [ordered]@{}
                foreach ($rn in $roleNames) {
                    $cv = $ui.GetColorValue([System.Enum]::Parse($uiColorType, $rn))
                    $uiNow[$rn] = '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $cv.A, $cv.R, $cv.G, $cv.B
                }
                $uiSnap = $uiNow
            } catch {
                $setStatus = 'error: ' + $_.Exception.Message
            }

            $wpSamples.Add([ordered]@{
                id = $spec.id
                container = $spec.kind
                file_sha256 = $fileSha
                set_wallpaper_status = $setStatus
                native_auto_color = $autoColor
                ui_settings_ramp = $uiSnap
                wic_scaled_256 = $wicInfo
            })
        }

        $d04WallpaperSection.status = 'ok'
        $d04WallpaperSection.display_count = $screens.Count
        $d04WallpaperSection.primary_bounds = @{ width = $screens[0].Bounds.Width; height = $screens[0].Bounds.Height }
        $d04WallpaperSection.samples = $wpSamples
    } finally {
        try {
            $native::SetCurrentWallpaper($originalWallpaper)
            [void]$native::ComputeNativeAutoColor()
        } catch {
            Write-Warning ('Could not automatically restore original wallpaper: ' + $_.Exception.Message)
        }
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Phase 3: D11 / D12 Read-Only Native ICC LUT & Profile Family Sweep
# ---------------------------------------------------------------------------
$iccSection = [ordered]@{
    status = 'skipped'
    profiles = [ordered]@{}
}

if (-not $SkipIccSweep) {
    Write-Host '  [3/3] Measuring D11/D12 forward mft2/mft1 LUT, ICC v4 mAB (3x4x5), and CMYK RSWOP.icm transforms...'
    [byte[]]$destSrgb = $native::RegisteredSrgbProfile()
    [byte[]]$rgbInput = $native::CalibrationAndGridRgb()
    $iccSection.status = 'ok'
    $iccSection.dest_srgb_sha256 = $native::Sha256Hex($destSrgb)
    $iccSection.dest_srgb_bytes = $destSrgb.Length
    $iccSection.input_rgb_count = ($rgbInput.Length / 3)
    $iccSection.input_rgb_sha256 = $native::Sha256Hex($rgbInput)
    $iccSection.input_rgb_base64 = [Convert]::ToBase64String($rgbInput)

    $iccSection.profiles['mft2_xyz_grid3'] = $native::ProbeRgbIccProfile($native::BuildMft2AsymmetricProfile(3, 3, 3), $destSrgb, $rgbInput)
    $iccSection.profiles['mft2_xyz_grid5'] = $native::ProbeRgbIccProfile($native::BuildMft2AsymmetricProfile(5, 5, 5), $destSrgb, $rgbInput)
    $iccSection.profiles['mft2_xyz_grid9'] = $native::ProbeRgbIccProfile($native::BuildMft2AsymmetricProfile(9, 9, 9), $destSrgb, $rgbInput)
    $iccSection.profiles['mft1_lab_grid5'] = $native::ProbeRgbIccProfile($native::BuildMft1LabProfile(5), $destSrgb, $rgbInput)
    $iccSection.profiles['v4_mab_xyz_3x4x5'] = $native::ProbeRgbIccProfile($native::BuildV4LutAToBProfile(3, 4, 5), $destSrgb, $rgbInput)

    [byte[]]$rswop = $native::InstalledColorProfileIfPresent('RSWOP.icm')
    if ($null -ne $rswop) {
        $iccSection.profiles['cmyk_rswop'] = $native::ProbeCmykProfile($rswop, $destSrgb)
    } else {
        $iccSection.profiles['cmyk_rswop'] = @{ status = 'missing_rswop_icm' }
    }
}

$desktopReg = Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue
$personalizeReg = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue

$report = [ordered]@{
    schema_version = 1
    suite = 'windows-26h2-capture-suite'
    captured_utc = [DateTime]::UtcNow.ToString('o')
    windows_build = $windowsBuild
    display_version = $displayVersion
    session_flags = [ordered]@{
        auto_colorization_raw = $(if ($null -ne $desktopReg) { $desktopReg.AutoColorization } else { $null })
        apps_use_light_theme = $(if ($null -ne $personalizeReg) { $personalizeReg.AppsUseLightTheme } else { $null })
        system_uses_light_theme = $(if ($null -ne $personalizeReg) { $personalizeReg.SystemUsesLightTheme } else { $null })
    }
    d02_manual_accent_sweep = $d02Section
    d04_d08_wallpaper_sweep = $d04WallpaperSection
    d11_d12_icc_sweep = $iccSection
}

$fullOut = [IO.Path]::GetFullPath($OutputPath)
$jsonText = $report | ConvertTo-Json -Depth 16
[IO.File]::WriteAllText($fullOut, $jsonText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ('==> Done! Saved report to: ' + $fullOut)
