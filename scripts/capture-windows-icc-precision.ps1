# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only native color conversion probe. No wallpaper, profile installation,
# display settings, registry writes, administrator rights, or external DLLs.
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'windows-icc-precision.json'),
    [switch]$FullRgb8,
    [switch]$CurveProfiles,
    [string[]]$SourceProfile = @(),
    [switch]$FamilyProfiles
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this diagnostic in Windows PowerShell on the reference Windows VM.'
}

$syntheticCount = 0
if ($CurveProfiles) { $syntheticCount += 2 }
if ($FamilyProfiles) {
    $FullRgb8 = $true
    $syntheticCount += 2
}
if (($SourceProfile.Count + $syntheticCount) -gt 4 -or
    (($SourceProfile.Count -gt 0 -or $CurveProfiles) -and -not $FullRgb8)) {
    throw 'Full RGB8 measurement allows four additional RGB profiles. CurveProfiles and FamilyProfiles each use two.'
}
if ($FullRgb8) {
    if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
        $name = if ($FamilyProfiles) { 'windows-icc-families.json' } else { 'windows-icc-full-rgb8.json' }
        $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $name
    }
    if (Test-Path -LiteralPath $OutputPath) {
        throw 'Full-domain report already exists. Choose a new OutputPath to preserve previous evidence.'
    }
}

if (-not ('WindowsModern.Reference.IccPrecisionV3.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace WindowsModern.Reference.IccPrecisionV3
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

        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern uint GetCMMInfo(IntPtr transform, uint info);
        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern bool CreateDeviceLinkProfile([In] IntPtr[] profiles, uint count,
            [In] uint[] intents, uint intentCount, uint flags, out IntPtr data, uint preferredCmm);
        [DllImport("kernel32.dll", ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr GlobalFree(IntPtr data);
        [DllImport("kernel32.dll", ExactSpelling=true, SetLastError=true)]
        private static extern UIntPtr GlobalSize(IntPtr data);

        public static byte[] MixedColors()
        {
            byte[] rgb = new byte[16*16*16*3];
            int p = 0;
            for (int r=0;r<16;r++) for (int g=0;g<16;g++) for (int b=0;b<16;b++)
            {
                rgb[p++]=(byte)(8+16*r); rgb[p++]=(byte)(4+16*g); rgb[p++]=(byte)(12+16*b);
            }
            return rgb;
        }
        public static Dictionary<string,object> Pack(byte[] bytes)
        {
            return new Dictionary<string,object>{{"status","ok"},{"length",bytes.Length},
                {"sha256",Hash(bytes)},{"base64",Convert.ToBase64String(bytes)}};
        }
        private static Dictionary<string,object> Error(Exception e)
        {
            Win32Exception w=e as Win32Exception;
            return new Dictionary<string,object>{{"status","error"},{"type",e.GetType().FullName},
                {"hresult",e.HResult},{"native_error",w==null?(object)null:w.NativeErrorCode}};
        }
        private static byte[] Expand16(byte[] rgb)
        {
            // 8-bit code n maps exactly to the 16-bit normalized code n*257.
            byte[] expanded=new byte[checked(rgb.Length*2)];
            for (int i=0;i<rgb.Length;i++) {expanded[2*i]=rgb[i]; expanded[2*i+1]=rgb[i];}
            return expanded;
        }
        private static byte[] Translate(IntPtr transform, byte[] rgb, uint inFormat, uint outFormat, int pixelBytes)
        {
            if (rgb.Length%3!=0) throw new ArgumentException("Bad RGB input");
            byte[] input=inFormat==10?Expand16(rgb):rgb;
            byte[] output=new byte[checked(rgb.Length/3*pixelBytes)];
            if (!TranslateBitmapBits(transform,input,inFormat,(uint)(rgb.Length/3),1,(uint)input.Length,
                output,outFormat,(uint)output.Length,IntPtr.Zero,IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return output;
        }
        private static Dictionary<string,object> Measure(IntPtr transform, byte[] rgb)
        {
            var result=new Dictionary<string,object>();
            result["cmm_ident"]=GetCMMInfo(transform,1).ToString("X8");
            result["cmm_dll_version"]=GetCMMInfo(transform,3);
            result["cmm_win_version"]=GetCMMInfo(transform,0);
            var outputs=new Dictionary<string,object>();
            foreach (uint inf in new uint[]{4,10})
            foreach (uint outf in new uint[]{4,9,10})
            {
                string key=(inf==4?"8":"16")+"to"+(outf==4?"8":outf==9?"10":"16");
                try {outputs[key]=Pack(Translate(transform,rgb,inf,outf,outf==4?3:outf==9?4:6));}
                catch(Exception e) {outputs[key]=Error(e);}
            }
            result["outputs"]=outputs;
            return result;
        }
        private static byte[] DeviceLink(IntPtr src, IntPtr dst, uint intent)
        {
            IntPtr data=IntPtr.Zero;
            try
            {
                if (!CreateDeviceLinkProfile(new IntPtr[]{src,dst},2,new uint[]{intent,intent},2,3,out data,0))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                if (data==IntPtr.Zero) throw new InvalidDataException("Missing link buffer");
                ulong allocated=GlobalSize(data).ToUInt64();
                if (allocated<132) throw new InvalidDataException("Invalid link allocation");
                byte[] header=new byte[128]; Marshal.Copy(data,header,0,128);
                uint size=((uint)header[0]<<24)|((uint)header[1]<<16)|((uint)header[2]<<8)|header[3];
                if (size<132 || size>16*1024*1024 || size>allocated || Encoding.ASCII.GetString(header,12,4)!="link"
                    || Encoding.ASCII.GetString(header,36,4)!="acsp") throw new InvalidDataException("Invalid ICC link header");
                byte[] link=new byte[checked((int)size)]; Marshal.Copy(data,link,0,link.Length); return link;
            }
            finally {if(data!=IntPtr.Zero) GlobalFree(data);}
        }
        public static byte[] RelativeLink(byte[] source, byte[] destination)
        {
            GCHandle srcPin=default(GCHandle), dstPin=default(GCHandle);
            IntPtr src=IntPtr.Zero, dst=IntPtr.Zero;
            try
            {
                srcPin=GCHandle.Alloc(source,GCHandleType.Pinned);
                dstPin=GCHandle.Alloc(destination,GCHandleType.Pinned);
                src=Open(source);
                dst=Open(destination);
                return DeviceLink(src,dst,1);
            }
            finally
            {
                if (dst!=IntPtr.Zero) CloseColorProfile(dst);
                if (src!=IntPtr.Zero) CloseColorProfile(src);
                if (dstPin.IsAllocated) dstPin.Free();
                if (srcPin.IsAllocated) srcPin.Free();
            }
        }
        public static Dictionary<string,object> Precision(byte[] rgb, byte[] source, byte[] destination, uint intent)
        {
            IntPtr src=IntPtr.Zero,dst=IntPtr.Zero,transform=IntPtr.Zero,linkProfile=IntPtr.Zero,linkTransform=IntPtr.Zero;
            // Retain both buffers until their handles have been closed.
            GCHandle srcPin=default(GCHandle),dstPin=default(GCHandle),linkPin=default(GCHandle);
            var result=new Dictionary<string,object>();
            try
            {
                srcPin=GCHandle.Alloc(source,GCHandleType.Pinned); dstPin=GCHandle.Alloc(destination,GCHandleType.Pinned);
                src=Open(source); dst=Open(destination);
                transform=CreateMultiProfileTransform(new IntPtr[]{src,dst},2,new uint[]{intent,intent},2,3,0);
                if (transform==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                result["status"]="ok"; result["direct"]=Measure(transform,rgb);
                try
                {
                    byte[] link=DeviceLink(src,dst,intent);
                    result["link_profile"]=Pack(link);
                    try
                    {
                        linkPin=GCHandle.Alloc(link,GCHandleType.Pinned);
                        linkProfile=Open(link);
                        linkTransform=CreateMultiProfileTransform(new IntPtr[]{linkProfile},1,new uint[]{intent},1,3,0);
                        if (linkTransform==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                        result["link_replay"]=Measure(linkTransform,rgb);
                    }
                    catch(Exception e) {result["link_replay"]=Error(e);}
                }
                catch(Exception e) {result["link_profile"]=Error(e);}
                return result;
            }
            catch(Exception e) {return Error(e);}
            finally
            {
                if(linkTransform!=IntPtr.Zero) DeleteColorTransform(linkTransform);
                if(linkProfile!=IntPtr.Zero) CloseColorProfile(linkProfile);
                if(transform!=IntPtr.Zero) DeleteColorTransform(transform);
                if(dst!=IntPtr.Zero) CloseColorProfile(dst);
                if(src!=IntPtr.Zero) CloseColorProfile(src);
                if(linkPin.IsAllocated) linkPin.Free();
                if(dstPin.IsAllocated) dstPin.Free();
                if(srcPin.IsAllocated) srcPin.Free();
            }
        }

        public static byte[] Wic(byte[] rgb, byte[] source, byte[] destination, string formatName)
        {
            return Wic(rgb,source,destination,formatName,(uint)(rgb.Length/3));
        }

        public static byte[] LocalRgbProfile(string path)
        {
            byte[] data=ReadProfile(path);
            if (data.Length<132 || Encoding.ASCII.GetString(data,36,4)!="acsp" ||
                Encoding.ASCII.GetString(data,16,4)!="RGB " ||
                ((uint)data[0]<<24 | (uint)data[1]<<16 | (uint)data[2]<<8 | data[3])!=(uint)data.Length)
                throw new InvalidDataException("Expected a complete RGB ICC profile.");
            string kind=Encoding.ASCII.GetString(data,12,4);
            if (kind!="scnr" && kind!="mntr" && kind!="prtr" && kind!="spac")
                throw new InvalidDataException("Unsupported source ICC profile class.");
            return data;
        }

        public static Dictionary<string,object> FullRgb8(byte[] source, byte[] destination)
        {
            // One 4096 x 4096 BGR24 bitmap. Each RGB code occurs once,
            // in ascending packed RGB order; only its output hash leaves memory.
            const int count=1<<24;
            byte[] rgb=new byte[count*3];
            for (int code=0,j=0;code<count;code++)
            {
                rgb[j++]=(byte)(code>>16); rgb[j++]=(byte)(code>>8); rgb[j++]=(byte)code;
            }
            byte[] output=Wic(rgb,source,destination,"BGR24",4096);
            if (output.Length!=rgb.Length) throw new InvalidDataException("Unexpected full RGB8 output length.");
            string[] redHashes=new string[256];
            using (SHA256 sha=SHA256.Create())
                for (int r=0;r<256;r++)
                    redHashes[r]=BitConverter.ToString(sha.ComputeHash(output,r*256*256*3,256*256*3)).Replace("-","");
            return new Dictionary<string,object>{{"status","ok"},{"color_count",count},
                {"order","ascending-rgb24"},{"sha256",Hash(output)},{"red_slice_sha256",redHashes}};
        }

        private static byte[] Wic(byte[] rgb, byte[] source, byte[] destination, string formatName, uint rowWidth)
        {
            if (rgb.Length%3!=0 || rowWidth==0 || (uint)(rgb.Length/3)%rowWidth!=0)
                throw new ArgumentException("Invalid WIC RGB dimensions");
            uint rowHeight=(uint)(rgb.Length/3)/rowWidth;
            string suffix=formatName=="BGR24"?"0c":formatName=="BGR32"?"0e":formatName=="BGRA32"?"0f":null;
            if (suffix==null) throw new ArgumentException("Unsupported WIC format");
            int channels=formatName=="BGR24"?3:4;
            Guid format=new Guid("6fddc324-4e03-4bfe-b185-3d77768dc9"+suffix);
            uint stride=checked(rowWidth*(uint)channels);
            byte[] output=WicPixels(ToBgr(rgb,channels),format,stride,rowWidth,rowHeight,
                source,destination,format,stride);
            return FromBgr(output,channels,formatName=="BGRA32");
        }

        public static byte[] GrayRamp(byte[] source, byte[] destination)
        {
            byte[] gray=new byte[256];
            for (int i=0;i<gray.Length;i++) gray[i]=(byte)i;
            Guid input=new Guid("6fddc324-4e03-4bfe-b185-3d77768dc908");
            Guid output=new Guid("6fddc324-4e03-4bfe-b185-3d77768dc90c");
            return FromBgr(WicPixels(gray,input,256,256,1,source,destination,output,768),3,false);
        }

        private static byte[] WicPixels(byte[] input, Guid inputFormat, uint inputStride,
            uint rowWidth, uint rowHeight, byte[] source, byte[] destination, Guid format, uint stride)
        {
            IWicFactory factory=null; IWicSource bitmap=null; IWicContext src=null,dst=null; IWicTransform transform=null;
            GCHandle inputPin=default(GCHandle), outputPin=default(GCHandle), sourcePin=default(GCHandle), destPin=default(GCHandle);
            byte[] output=new byte[checked((int)(stride*rowHeight))];
            try
            {
                inputPin=GCHandle.Alloc(input,GCHandleType.Pinned);
                outputPin=GCHandle.Alloc(output,GCHandleType.Pinned);
                sourcePin=GCHandle.Alloc(source,GCHandleType.Pinned);
                factory=(IWicFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("cacaf262-9370-4615-a13b-9f5539da4c0a")));
                factory.CreateBitmapFromMemory(rowWidth,rowHeight,ref inputFormat,inputStride,
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
                if (actual!=format || width!=rowWidth || height!=rowHeight)
                    throw new InvalidDataException("Unexpected WIC output format or dimensions.");
                transform.CopyPixels(IntPtr.Zero,stride,(uint)output.Length,outputPin.AddrOfPinnedObject());
                return output;
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
$nativeType = [WindowsModern.Reference.IccPrecisionV3.Native]
$sourceProfiles = [ordered]@{}
foreach ($name in $sourceData.Keys) {
    [byte[]]$data = [Convert]::FromBase64String($sourceData[$name])
    if ($nativeType::Hash($data) -ne $sourceHashes[$name]) { throw 'Synthetic ICC hash mismatch.' }
    $sourceProfiles[$name] = $data
}
$syntheticSources = [ordered]@{}
$controls = [ordered]@{}
if ($FamilyProfiles) {
    # Same identity and ZYX 2x2x2 mft2 controls as the PCS capture.
    $controls += [ordered]@{
        'D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4' = 'AAACZAAAAAACEAAAc3BhY1JHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAABiY3BydAAAASQAAAAzd3RwdAAAAVgAAAAUQTJCMAAAAWwAAAB8QjJBMAAAAegAAAB8ZGVzYwAAAAAAAAAIcmdiLXBjcwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRleHQAAAAAUHVibGljIGRvbWFpbiBzeW50aGV0aWMgZGlhZ25vc3RpYyBwcm9maWxlAABYWVogAAAAAAAA9tYAAQAAAADTLW1mdDIAAAAAAwMCAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAACAAIAAP//AAD//wAA//8AAAAAAAAAAAAA//8AAP//AAAAAP///////wAAAAD//wAA////////AAD///////8AAP//AAD//wAA//9tZnQyAAAAAAMDAgAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAgACAAD//wAA//8AAP//AAAAAAAAAAAAAP//AAD//wAAAAD///////8AAAAA//8AAP///////wAA////////AAD//wAA//8AAP//'
        '086832DEE2195FBFC5FAF48A48C30CF2301D70CBA9C92CA46C11E6257C5DBB18' = 'AAACaAAAAAACEAAAc3BhY1JHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAABmY3BydAAAASgAAAAzd3RwdAAAAVwAAAAUQTJCMAAAAXAAAAB8QjJBMAAAAewAAAB8ZGVzYwAAAAAAAAAMcmdiLXBjcy16eXgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1tZnQyAAAAAAMDAgAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAgACAAD//wAA//8AAP//AAAAAAAA//8AAAAAAAD//wAA/////wAAAAAAAP////8AAP//AAD/////////////AAD//wAA//8AAP//bWZ0MgAAAAADAwIAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAIAAgAA//8AAP//AAD//wAAAAAAAP//AAAAAAAA//8AAP////8AAAAAAAD/////AAD//wAA/////////////wAA//8AAP//AAD//w=='
    }
}
if ($CurveProfiles) {
    # Same v2.1 matrix colorants, with gamma and sampled TRC controls.
    $controls += [ordered]@{
        '3633820C700F656C83A23C1D0DAA20214E73D040AB13E6B87262CEF513D0B5CA' = 'AAACWAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABxY3BydAAAAWQAAAAzd3RwdAAAAZgAAAAUclhZWgAAAawAAAAUZ1hZWgAAAcAAAAAUYlhZWgAAAdQAAAAUclRSQwAAAegAAAAOZ1RSQwAAAfgAAABOYlRSQwAAAkgAAAAOZGVzYwAAAAAAAAAXTWF0cml4IHByb2JlIHNvdXJjZS12MgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1YWVogAAAAAAAAb6AAADj1AAADkFhZWiAAAAAAAABilwAAt4cAABjZWFlaIAAAAAAAACSfAAAPhAAAtsNjdXJ2AAAAAAAAAAECMwAAY3VydgAAAAAAAAAhAAAAgAG+A50GEAkPDJQQmhUdGhkfjCV0K80ylznPQXRJhFH+WuFkKm3bd/CCao1HmIekKLAqvIzJTdZt4+vxx///AABjdXJ2AAAAAAAAAAEBAAAA'
        '6A907D854C58B4625AADACA152438EE1BC857B46EE106D31381208493023B268' = 'AAACGAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABxY3BydAAAAWQAAAAzd3RwdAAAAZgAAAAUclhZWgAAAawAAAAUZ1hZWgAAAcAAAAAUYlhZWgAAAdQAAAAUclRSQwAAAegAAAAOZ1RSQwAAAfgAAAAOYlRSQwAAAggAAAAOZGVzYwAAAAAAAAAXTWF0cml4IHByb2JlIHNvdXJjZS12MgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1YWVogAAAAAAAAb6AAADj1AAADkFhZWiAAAAAAAABilwAAt4cAABjZWFlaIAAAAAAAACSfAAAPhAAAtsNjdXJ2AAAAAAAAAAECMwAAY3VydgAAAAAAAAABAjMAAGN1cnYAAAAAAAAAAQIzAAA='
    }
}
foreach ($digest in $controls.Keys) {
    [byte[]]$data = [Convert]::FromBase64String($controls[$digest])
    if ($nativeType::Hash($data) -cne $digest) { throw 'Synthetic RGB profile hash mismatch.' }
    $name = 'custom-' + $digest
    $sourceHashes[$name] = $digest
    $sourceProfiles[$name] = $data
    $syntheticSources[$name] = $nativeType::Pack($data)
}
foreach ($path in $SourceProfile) {
    [byte[]]$data = $nativeType::LocalRgbProfile([IO.Path]::GetFullPath($path))
    $digest = $nativeType::Hash($data)
    if ($sourceHashes.Values -contains $digest) { continue }
    $name = 'custom-' + $digest
    $sourceHashes[$name] = $digest
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

# Keep original calibration order, then append an independent RGB grid.
[byte[]]$mixed = $nativeType::MixedColors()
if ($mixed.Length -ne 12288) { throw 'Unexpected mixed RGB count.' }
[byte[]]$inputRgb = $rgb + $mixed
$target = $nativeType::RegisteredProfile(0x73524742)
$targetHash = '2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E'
if ($target.Length -ne 3144 -or $nativeType::Hash($target) -ne $targetHash) {
    throw 'Registered sRGB target differs from the reference profile.'
}
$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = '{0}.{1}' -f $version.CurrentBuildNumber,$version.UBR
if ($build -ne '26300.9974') { throw ('Unexpected reference build: ' + $build) }
$results = [ordered]@{}
foreach ($source in $sourceProfiles.Keys) {
    Write-Host ('Measuring ' + $source + ' ...')
    $wic = try { $nativeType::Pack($nativeType::Wic($inputRgb,$sourceProfiles[$source],$target,'BGR24')) }
           catch { [ordered]@{status='error';error=(Get-ProbeError $_)} }
    $modes = [ordered]@{}
    foreach ($intent in 0..2) {
        $modes[[string]$intent] = $nativeType::Precision($inputRgb,$sourceProfiles[$source],$target,[uint32]$intent)
    }
    $results[$source] = [ordered]@{wic=$wic;intents=$modes}
    if ($FullRgb8) {
        $results[$source].full_rgb8 = try { $nativeType::FullRgb8($sourceProfiles[$source],$target) }
            catch { [ordered]@{status='error';error=(Get-ProbeError $_)} }
    }
}
$report = [ordered]@{
    schema_version=$(if ($FullRgb8) { 2 } else { 1 }); windows_build=$build; calibration_count=1024; mixed_count=4096;
    calibration_sha256=$nativeType::Hash($rgb); input_rgb=$nativeType::Pack($inputRgb);
    sources=$sourceHashes; target_sha256=$targetHash; flags=3; results=$results
}
if ($syntheticSources.Count) { $report.synthetic_sources = $syntheticSources }
if ($FamilyProfiles) {
    # Embedded v2 Gray/XYZ monitor controls differ in their kTRC gamma.
    # The WIC input is one gray byte per pixel, not three repeated RGB bytes.
    $grayControls = [ordered]@{
        'gray-linear' = @{sha256='FCA615D30B83A208A33AFB4A4FF7EAE18AD3F9BB66EE2872619ACA101A044AC4'; base64='AAABdAAAAAACEAAAbW50ckdSQVlYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEZGVzYwAAALQAAABmY3BydAAAARwAAAAzd3RwdAAAAVAAAAAUa1RSQwAAAWQAAAAOZGVzYwAAAAAAAAAMZ3JheS1saW5lYXIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1jdXJ2AAAAAAAAAAEBAAAA'}
        'gray-gamma22' = @{sha256='CC2F4242F64AA4624D41A3853547F84BBF861A221C738D742959019169085B28'; base64='AAABdAAAAAACEAAAbW50ckdSQVlYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEZGVzYwAAALQAAABnY3BydAAAARwAAAAzd3RwdAAAAVAAAAAUa1RSQwAAAWQAAAAOZGVzYwAAAAAAAAANZ3JheS1nYW1tYTIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1jdXJ2AAAAAAAAAAECMwAA'}
    }
    $report.gray8 = [ordered]@{}
    foreach ($name in $grayControls.Keys) {
        $entry = $grayControls[$name]
        [byte[]]$data = [Convert]::FromBase64String($entry.base64)
        if ($nativeType::Hash($data) -cne $entry.sha256) { throw 'Synthetic gray profile hash mismatch.' }
        $wic = try { $nativeType::Pack($nativeType::GrayRamp($data,$target)) }
               catch { [ordered]@{status='error';error=(Get-ProbeError $_)} }
        $link = try { $nativeType::Pack($nativeType::RelativeLink($data,$target)) }
                catch { [ordered]@{status='error';error=(Get-ProbeError $_)} }
        $report.gray8[$name] = [ordered]@{
            profile=$nativeType::Pack($data); input_order='gray8-0-through-255';
            output_order='rgb24'; wic=$wic; relative_link=$link
        }
    }
}
$json = $report | ConvertTo-Json -Depth 16
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,(New-Object Text.UTF8Encoding($false)))
Write-Host ('Report: {0}' -f [IO.Path]::GetFullPath($OutputPath))
