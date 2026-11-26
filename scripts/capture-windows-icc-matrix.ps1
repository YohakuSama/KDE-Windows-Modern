# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only native color conversion probe. No wallpaper, profile installation,
# display settings, registry writes, administrator rights, or external DLLs.
[CmdletBinding()]
param(
    [string]$OutputPath,
    [ValidateSet('Matrix','Pcs')][string]$ProbeSet = 'Matrix'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $OutputPath) {
    $file = if ($ProbeSet -eq 'Pcs') { 'windows-icc-pcs.json' } else { 'windows-icc-matrix.json' }
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $file
}
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this diagnostic in Windows PowerShell on the reference Windows VM.'
}

if (-not ('WindowsModern.Reference.IccMatrixV2.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace WindowsModern.Reference.IccMatrixV2
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

        [DllImport("mscms.dll", ExactSpelling=true, SetLastError=true)]
        private static extern bool TranslateColors(IntPtr transform, [In] byte[] input, uint count,
            uint inputType, [Out] byte[] output, uint outputType);

        public static Dictionary<string,object> PackPcs(byte[] bytes)
        {
            using (var stream=new MemoryStream())
            {
                using (var gzip=new System.IO.Compression.GZipStream(stream,
                    System.IO.Compression.CompressionMode.Compress,true)) gzip.Write(bytes,0,bytes.Length);
                return new Dictionary<string,object>{{"status","ok"},{"length",bytes.Length},
                    {"sha256",Hash(bytes)},{"gzip_base64",Convert.ToBase64String(stream.ToArray())}};
            }
        }

        public static byte[] PcsColors()
        {
            // Explicit little-endian, three 16-bit words per color. Asymmetric
            // markers first; then a normalized 32^3 grid; then three PCS axes.
            using (var stream=new MemoryStream())
            using (var writer=new BinaryWriter(stream))
            {
                ushort[] markers={0,0,0,1,12345,32768,32768,1,65535,1000,2000,3000,
                                  65535,0,0,0,65535,0,0,0,65535,65535,65535,65535};
                foreach(ushort v in markers) writer.Write(v);
                for(int r=0;r<32;r++) for(int g=0;g<32;g++) for(int b=0;b<32;b++)
                    foreach(int v in new int[]{r,g,b}) writer.Write((ushort)((v*65535+15)/31));
                for(int axis=0;axis<3;axis++) for(int q=0;q<=8192;q++)
                    for(int c=0;c<3;c++) writer.Write((ushort)(c==axis?q*4:0));
                return stream.ToArray();
            }
        }
        private static byte[] PcsTranslate(IntPtr transform, byte[] input, bool srcXyz, bool dstXyz, bool colorApi)
        {
            if(input.Length%6!=0) throw new ArgumentException("Expected three 16-bit words per color");
            // COLOR includes a pointer-alignment union member: 16 bytes on
            // Win64/ARM64, 8 on Win32. Only its first three words are exported.
            int stride=colorApi?(IntPtr.Size==8?16:8):6;
            byte[] output=new byte[input.Length];
            for(int start=0;start<input.Length/6;start+=1024)
            {
                int count=Math.Min(1024,input.Length/6-start);
                int bufferLength=colorApi?count*stride:((count*stride+3)&~3);
                byte[] a=new byte[bufferLength], b=new byte[bufferLength];
                for(int i=0;i<count;i++) Buffer.BlockCopy(input,(start+i)*6,a,i*stride,6);
                bool ok=colorApi?TranslateColors(transform,a,(uint)count,srcXyz?3u:2u,b,dstXyz?3u:2u):
                    TranslateBitmapBits(transform,a,srcXyz?0x0501u:10u,(uint)count,1,(uint)a.Length,
                        b,dstXyz?0x0501u:10u,(uint)b.Length,IntPtr.Zero,IntPtr.Zero);
                if(!ok) throw new Win32Exception(Marshal.GetLastWin32Error());
                for(int i=0;i<count;i++) Buffer.BlockCopy(b,i*stride,output,(start+i)*6,6);
            }
            return output;
        }
        public static Dictionary<string,object> PcsProbe(byte[] input, byte[] source, byte[] destination, bool srcXyz, bool dstXyz)
        {
            IntPtr src=IntPtr.Zero,dst=IntPtr.Zero,transform=IntPtr.Zero;
            GCHandle srcPin=default(GCHandle),dstPin=default(GCHandle);
            var row=new Dictionary<string,object>();
            try
            {
                srcPin=GCHandle.Alloc(source,GCHandleType.Pinned); dstPin=GCHandle.Alloc(destination,GCHandleType.Pinned);
                src=Open(source); dst=Open(destination);
                transform=CreateMultiProfileTransform(new IntPtr[]{src,dst},2,new uint[]{1,1},2,3,0);
                if(transform==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                row["status"]="ok";
                row["cmm_ident"]=GetCMMInfo(transform,1).ToString("X8");
                row["cmm_dll_version"]=GetCMMInfo(transform,3);
                row["cmm_win_version"]=GetCMMInfo(transform,0);
                try {row["color16"]=PackPcs(PcsTranslate(transform,input,srcXyz,dstXyz,true));}
                catch(Exception e) {row["color16"]=Error(e);}
                // Capture both APIs independently. Never infer word order from
                // the API format name; the identity and ZYX controls establish it.
                try {row["bitmap16"]=PackPcs(PcsTranslate(transform,input,srcXyz,dstXyz,false));}
                catch(Exception e) {row["bitmap16"]=Error(e);}
                try {row["link_profile"]=PackPcs(DeviceLink(src,dst,1));}
                catch(Exception e) {row["link_profile"]=Error(e);}
                return row;
            }
            catch(Exception e) {return Error(e);}
            finally
            {
                if(transform!=IntPtr.Zero) DeleteColorTransform(transform);
                if(dst!=IntPtr.Zero) CloseColorProfile(dst);
                if(src!=IntPtr.Zero) CloseColorProfile(src);
                if(dstPin.IsAllocated) dstPin.Free();
                if(srcPin.IsAllocated) srcPin.Free();
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
$nativeType = [WindowsModern.Reference.IccMatrixV2.Native]
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

# In-memory synthetic ICC v2.1 matrix profiles, linear TRCs and D50 white.
# The columns below are exact signed 16.16 ICC colorant codes. No system
# profile is modified or installed. These profiles are investigation inputs.
$matrixProfiles = [ordered]@{
    # Columns: [[63190, 0, 0], [0, 65536, 0], [0, 0, 54061]]
    'diagonal' = @{'sha256'='EA4E03FD6DE5B7FDE826920BA1AD0D23FE16A3756A2D35B412E6E387F222A850';'base64'='AAACFAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABwY3BydAAAAWAAAAAzd3RwdAAAAZQAAAAUclhZWgAAAagAAAAUZ1hZWgAAAbwAAAAUYlhZWgAAAdAAAAAUclRSQwAAAeQAAAAOZ1RSQwAAAfQAAAAOYlRSQwAAAgQAAAAOZGVzYwAAAAAAAAAWTWF0cml4IHByb2JlIGRpYWdvbmFsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRleHQAAAAAUHVibGljIGRvbWFpbiBzeW50aGV0aWMgZGlhZ25vc3RpYyBwcm9maWxlAABYWVogAAAAAAAA9tYAAQAAAADTLVhZWiAAAAAAAAD21gAAAAAAAAAAWFlaIAAAAAAAAAAAAAEAAAAAAABYWVogAAAAAAAAAAAAAAAAAADTLWN1cnYAAAAAAAAAAQEAAABjdXJ2AAAAAAAAAAEBAAAAY3VydgAAAAAAAAABAQAAAA=='}
    # Columns: [[49152, 8192, 2048], [10240, 49152, 8192], [3798, 8192, 43821]]
    'mixed' = @{'sha256'='5B3116A2C13082F54CD1DC7D15614B1A07CF9170B953CC7D44B8995C9048B829';'base64'='AAACFAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABtY3BydAAAAWAAAAAzd3RwdAAAAZQAAAAUclhZWgAAAagAAAAUZ1hZWgAAAbwAAAAUYlhZWgAAAdAAAAAUclRSQwAAAeQAAAAOZ1RSQwAAAfQAAAAOYlRSQwAAAgQAAAAOZGVzYwAAAAAAAAATTWF0cml4IHByb2JlIG1peGVkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRleHQAAAAAUHVibGljIGRvbWFpbiBzeW50aGV0aWMgZGlhZ25vc3RpYyBwcm9maWxlAABYWVogAAAAAAAA9tYAAQAAAADTLVhZWiAAAAAAAADAAAAAIAAAAAgAWFlaIAAAAAAAACgAAADAAAAAIABYWVogAAAAAAAADtYAACAAAACrLWN1cnYAAAAAAAAAAQEAAABjdXJ2AAAAAAAAAAEBAAAAY3VydgAAAAAAAAABAQAAAA=='}
    # Columns: [[49153, 8190, 2051], [10239, 49154, 8188], [3798, 8192, 43822]]
    'mixed-delta' = @{'sha256'='0C4CB39F7174458D06AE88D3123ADF7195BA60B1FA325A46CC207DA144F58B3E';'base64'='AAACGAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABzY3BydAAAAWQAAAAzd3RwdAAAAZgAAAAUclhZWgAAAawAAAAUZ1hZWgAAAcAAAAAUYlhZWgAAAdQAAAAUclRSQwAAAegAAAAOZ1RSQwAAAfgAAAAOYlRSQwAAAggAAAAOZGVzYwAAAAAAAAAZTWF0cml4IHByb2JlIG1peGVkLWRlbHRhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1YWVogAAAAAAAAwAEAAB/+AAAIA1hZWiAAAAAAAAAn/wAAwAIAAB/8WFlaIAAAAAAAAA7WAAAgAAAAqy5jdXJ2AAAAAAAAAAEBAAAAY3VydgAAAAAAAAABAQAAAGN1cnYAAAAAAAAAAQEAAAA='}
    # Columns: [[28576, 14581, 912], [25239, 46983, 6361], [9375, 3972, 46787]]
    'source-v2' = @{'sha256'='6EC51764DA076242F36221B786533ACF8EAB04A2FCA4C604E7C1644238A8CA37';'base64'='AAACGAAAAAACEAAAbW50clJHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABxY3BydAAAAWQAAAAzd3RwdAAAAZgAAAAUclhZWgAAAawAAAAUZ1hZWgAAAcAAAAAUYlhZWgAAAdQAAAAUclRSQwAAAegAAAAOZ1RSQwAAAfgAAAAOYlRSQwAAAggAAAAOZGVzYwAAAAAAAAAXTWF0cml4IHByb2JlIHNvdXJjZS12MgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1YWVogAAAAAAAAb6AAADj1AAADkFhZWiAAAAAAAABilwAAt4cAABjZWFlaIAAAAAAAACSfAAAPhAAAtsNjdXJ2AAAAAAAAAAEBAAAAY3VydgAAAAAAAAABAQAAAGN1cnYAAAAAAAAAAQEAAAA='}
}
$targetHash = '2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E'
[byte[]]$target = $nativeType::RegisteredProfile(0x73524742)
if ($target.Length -ne 3144 -or $nativeType::Hash($target) -ne $targetHash) {
    throw 'Registered sRGB target differs from the reference profile.'
}
$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = '{0}.{1}' -f $version.CurrentBuildNumber,$version.UBR
if ($build -ne '26300.9974') { throw ('Unexpected reference build: ' + $build) }
$profiles = [ordered]@{'linear-srgb'=$sourceProfiles['linear-srgb'];'registered-srgb'=$target}
$hashes = [ordered]@{'linear-srgb'=$sourceHashes['linear-srgb'];'registered-srgb'=$targetHash}
foreach ($name in $matrixProfiles.Keys) {
    [byte[]]$data = [Convert]::FromBase64String($matrixProfiles[$name]['base64'])
    if ($nativeType::Hash($data) -ne $matrixProfiles[$name]['sha256']) { throw 'Synthetic matrix profile hash mismatch.' }
    $profiles[$name] = $data
    $hashes[$name] = $matrixProfiles[$name]['sha256']
}
if ($nativeType::Hash($rgb) -ne 'DDFCE7C3B7CA3AEB95ADC28356EE50430CD0FEAB5530FA602D36FB0DEEC4B484') {
    throw 'Calibration input hash mismatch.'
}
if ($ProbeSet -eq 'Pcs') {
    # Identity and ZYX-permuted ICC v2.1 LUT bridges, no display profile installation.
    $pcsProfiles = [ordered]@{
        'xyz-identity' = @{'sha256'='B6E383B40B96A7BD0824C145B5761692B92851B4DF4BD16319157CCB21D19D77';'base64'='AAACaAAAAAACEAAAc3BhY1hZWiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAABnY3BydAAAASgAAAAzd3RwdAAAAVwAAAAUQTJCMAAAAXAAAAB8QjJBMAAAAewAAAB8ZGVzYwAAAAAAAAANeHl6LWlkZW50aXR5AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1tZnQyAAAAAAMDAgAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAgACAAD//wAA//8AAP//AAAAAAAAAAAAAP//AAD//wAAAAD///////8AAAAA//8AAP///////wAA////////AAD//wAA//8AAP//bWZ0MgAAAAADAwIAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAIAAgAA//8AAP//AAD//wAAAAAAAAAAAAD//wAA//8AAAAA////////AAAAAP//AAD///////8AAP///////wAA//8AAP//AAD//w=='}
        'rgb-pcs' = @{'sha256'='D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4';'base64'='AAACZAAAAAACEAAAc3BhY1JHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAABiY3BydAAAASQAAAAzd3RwdAAAAVgAAAAUQTJCMAAAAWwAAAB8QjJBMAAAAegAAAB8ZGVzYwAAAAAAAAAIcmdiLXBjcwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRleHQAAAAAUHVibGljIGRvbWFpbiBzeW50aGV0aWMgZGlhZ25vc3RpYyBwcm9maWxlAABYWVogAAAAAAAA9tYAAQAAAADTLW1mdDIAAAAAAwMCAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAACAAIAAP//AAD//wAA//8AAAAAAAAAAAAA//8AAP//AAAAAP///////wAAAAD//wAA////////AAD///////8AAP//AAD//wAA//9tZnQyAAAAAAMDAgAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAgACAAD//wAA//8AAP//AAAAAAAAAAAAAP//AAD//wAAAAD///////8AAAAA//8AAP///////wAA////////AAD//wAA//8AAP//'}
        'rgb-pcs-zyx' = @{'sha256'='086832DEE2195FBFC5FAF48A48C30CF2301D70CBA9C92CA46C11E6257C5DBB18';'base64'='AAACaAAAAAACEAAAc3BhY1JHQiBYWVogB9AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAABmY3BydAAAASgAAAAzd3RwdAAAAVwAAAAUQTJCMAAAAXAAAAB8QjJBMAAAAewAAAB8ZGVzYwAAAAAAAAAMcmdiLXBjcy16eXgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB0ZXh0AAAAAFB1YmxpYyBkb21haW4gc3ludGhldGljIGRpYWdub3N0aWMgcHJvZmlsZQAAWFlaIAAAAAAAAPbWAAEAAAAA0y1tZnQyAAAAAAMDAgAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAgACAAD//wAA//8AAP//AAAAAAAA//8AAAAAAAD//wAA/////wAAAAAAAP////8AAP//AAD/////////////AAD//wAA//8AAP//bWZ0MgAAAAADAwIAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAIAAgAA//8AAP//AAD//wAAAAAAAP//AAAAAAAA//8AAP////8AAAAAAAD/////AAD//wAA/////////////wAA//8AAP//AAD//w=='}
    }
    foreach ($name in $pcsProfiles.Keys) {
        [byte[]]$data = [Convert]::FromBase64String($pcsProfiles[$name]['base64'])
        if ($nativeType::Hash($data) -ne $pcsProfiles[$name]['sha256']) { throw 'PCS profile hash mismatch.' }
        $profiles[$name] = $data
        $hashes[$name] = $pcsProfiles[$name]['sha256']
    }
    [byte[]]$input16 = $nativeType::PcsColors()
    if ($input16.Length -ne ((8+32768+3*8193)*6) -or
        $nativeType::Hash($input16) -ne 'CE19EB355E773C647F28C7A7DD9FDE12B756955FC590C0B4CD51996B2ACD9997') {
        throw 'Unexpected PCS input length or hash.'
    }
    $pcsPairs = @(
        'xyz-identity|xyz-identity', 'rgb-pcs|rgb-pcs', 'rgb-pcs|rgb-pcs-zyx',
        'xyz-identity|rgb-pcs', 'rgb-pcs|xyz-identity',
        'linear-srgb|xyz-identity', 'mixed|xyz-identity', 'diagonal|xyz-identity',
        'xyz-identity|diagonal', 'xyz-identity|registered-srgb', 'xyz-identity|mixed', 'xyz-identity|mixed-delta',
        'linear-srgb|rgb-pcs', 'mixed|rgb-pcs', 'diagonal|rgb-pcs',
        'rgb-pcs|diagonal', 'rgb-pcs|registered-srgb', 'rgb-pcs|mixed', 'rgb-pcs|mixed-delta',
        'linear-srgb|rgb-pcs-zyx', 'rgb-pcs-zyx|registered-srgb',
        'linear-srgb|registered-srgb', 'diagonal|diagonal'
    )
    $results = [ordered]@{}
    foreach ($pair in $pcsPairs) {
        $names = $pair.Split('|')
        Write-Host ('Measuring ' + $pair + ' ...')
        $results[$pair] = $nativeType::PcsProbe($input16,$profiles[$names[0]],$profiles[$names[1]],
            ($names[0] -eq 'xyz-identity'),($names[1] -eq 'xyz-identity'))
    }
    $report = [ordered]@{
        schema_version=1; probe_set='Pcs'; windows_build=$build; flags=3; intent=1;
        marker_count=8; grid_count=32768; axis_count=8193; color_count=($input16.Length/6);
        input_words='little-endian three WORDs'; input16=$nativeType::PackPcs($input16);
        profiles=$hashes; matrix_profiles=$matrixProfiles; pcs_profiles=$pcsProfiles; results=$results
    }
    $json = $report | ConvertTo-Json -Depth 16
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,(New-Object Text.UTF8Encoding($false)))
    Write-Host ('Report: {0}' -f [IO.Path]::GetFullPath($OutputPath))
    $success = @($results.Values | Where-Object { $_['status'] -eq 'ok' }).Count
    Write-Host ('PCS transforms created: {0}/{1}' -f $success,$pcsPairs.Count)
    return
}

$pairs = @(
    'linear-srgb|registered-srgb', 'source-v2|registered-srgb',
    'diagonal|diagonal', 'linear-srgb|diagonal', 'diagonal|registered-srgb',
    'mixed|diagonal', 'diagonal|mixed', 'mixed-delta|diagonal', 'diagonal|mixed-delta'
)
$results = [ordered]@{}
foreach ($pair in $pairs) {
    $names = $pair.Split('|')
    Write-Host ('Measuring ' + $pair + ' ...')
    $row = $nativeType::Precision($rgb,$profiles[$names[0]],$profiles[$names[1]],[uint32]1)
    # Keep only the RGB8 baseline and the generated link. The prior tested
    # native helper also evaluates high-bit formats; do not export them here.
    if ($row['status'] -eq 'ok') {
        foreach ($key in @('direct','link_replay')) {
            if ($row.ContainsKey($key) -and $row[$key].ContainsKey('outputs')) {
                $outputs = $row[$key]['outputs']
                foreach ($fmt in @('8to10','8to16','16to8','16to10','16to16')) {
                    [void]$outputs.Remove($fmt)
                }
            }
        }
    }
    $results[$pair] = $row
}
$report = [ordered]@{
    schema_version=1; windows_build=$build; flags=3; intent=1;
    color_count=1024; input_rgb=$nativeType::Pack($rgb); profiles=$hashes;
    matrix_profiles=$matrixProfiles; results=$results
}
$json = $report | ConvertTo-Json -Depth 16
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,(New-Object Text.UTF8Encoding($false)))
Write-Host ('Report: {0}' -f [IO.Path]::GetFullPath($OutputPath))
