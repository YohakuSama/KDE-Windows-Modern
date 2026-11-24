#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import the owner's Windows resources locally; never extract the full archive."""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import tarfile
import tempfile
import wave

from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen


def read_assets(source, wanted):
    data = {}
    if source.is_dir():
        root = source / 'Windows' if (source / 'Windows').is_dir() else source
        for name in wanted:
            path = root / name
            if path.is_file():
                data[name] = path.read_bytes()
    else:
        with tarfile.open(source, 'r|*') as archive:
            for member in archive:
                parts = member.name.split('/')
                if not member.isfile() or 'Windows' not in parts:
                    continue
                name = '/'.join(parts[parts.index('Windows') + 1:])
                if name not in wanted:
                    continue
                if name in data or member.size > 64 * 1024 * 1024:
                    raise ValueError('Duplicate or oversized member: ' + name)
                data[name] = archive.extractfile(member).read()
    missing = wanted - data.keys()
    if missing:
        raise ValueError('Missing resources: ' + ', '.join(sorted(missing)))
    return data


def pe_resources(data):
    def u16(pos):
        return struct.unpack_from('<H', data, pos)[0]
    def u32(pos):
        return struct.unpack_from('<I', data, pos)[0]
    pe = u32(0x3c)
    if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0':
        raise ValueError('Not a PE resource library')
    opt = pe + 24
    magic = u16(opt)
    if magic not in (0x10b, 0x20b):
        raise ValueError('Unknown PE optional header')
    dd = opt + (112 if magic == 0x20b else 96)
    sections = []
    for i in range(u16(pe + 6)):
        p = opt + u16(pe + 20) + 40*i
        sections.append((u32(p+12), u32(p+16), u32(p+20)))
    def offset(rva):
        for addr, size, pos in sections:
            if addr <= rva < addr + size:
                return pos + rva - addr
        raise ValueError('Unmapped resource RVA')
    base = offset(u32(dd+16))
    result = {}
    def walk(rel, path):
        if len(path) > 3:
            raise ValueError('Invalid resource tree depth')
        o = base + rel
        for i in range(u16(o+12) + u16(o+14)):
            name, child = struct.unpack_from('<II', data, o+16+8*i)
            if name & 0x80000000:
                continue
            key = path + (name,)
            if child & 0x80000000:
                walk(child & 0x7fffffff, key)
            else:
                rva, size = struct.unpack_from('<II', data, base+child)
                start = offset(rva)
                if start+size > len(data):
                    raise ValueError('Truncated resource')
                result[key] = data[start:start+size]
    walk(0, ())
    return result


def icon_svg(resources, group):
    key = sorted(k for k in resources if k[:2] == (14, group))[0]
    g = resources[key]
    candidates = []
    for i in range(struct.unpack_from('<H', g, 4)[0]):
        w, h, c, r, planes, bpp, size, rid = struct.unpack_from('<BBBBHHIH', g, 6+14*i)
        keys = sorted(k for k in resources if k[:2] == (3, rid))
        if not keys:
            continue
        raw = resources.get((3, rid, key[-1]), resources[keys[0]])
        candidates.append(((w or 256)*(h or 256), bpp, (w,h,c,r,planes,bpp), raw))
    for _, _, fields, raw in sorted(candidates, key=lambda x: x[:2], reverse=True):
        try:
            ico = struct.pack('<HHH',0,1,1) + struct.pack('<BBBBHHII',*fields,len(raw),22) + raw
            image = Image.open(io.BytesIO(ico)).convert('RGBA')
            out = io.BytesIO()
            image.save(out, format='PNG')
            b64 = base64.b64encode(out.getvalue()).decode('ascii')
            w,h = image.size
            return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                    f'width="{w}" height="{h}" viewBox="0 0 {w} {h}"><image width="{w}" height="{h}" '
                    f'xlink:href="data:image/png;base64,{b64}"/></svg>\n').encode()
        except (OSError, ValueError):
            continue
    raise ValueError(f'No decodable icon in group {group}')


def glyph_svg(font, code):
    glyphs = font.getGlyphSet()
    name = font.getBestCmap()[int(code,16)]
    pen = SVGPathPen(glyphs)
    glyphs[name].draw(pen)
    path = pen.getCommands()
    if not path:
        raise ValueError('Empty glyph ' + code)
    em = font['head'].unitsPerEm
    advance = font['hmtx'][name][0]
    ascent = font['hhea'].ascent
    # Preserve the original em box and relative glyph sizes, including
    # signal levels and chevrons. KDE recolors the semantic text class.
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 {em} {em}">'
            '<defs><style id="current-color-scheme" type="text/css">.ColorScheme-Text {color:#232629;}</style></defs>'
            f'<path class="ColorScheme-Text" fill="currentColor" transform="translate({(em-advance)/2} {ascent}) scale(1 -1)" d="{path}"/></svg>\n').encode()


def build(stage, data, mapping):
    hashes = {}
    outputs = {}
    def write(relative, content, source):
        p = stage / relative
        if relative in outputs:
            raise ValueError('Conflicting output: ' + relative)
        digest = hashlib.sha256(content).hexdigest()
        p.parent.mkdir(parents=True, exist_ok=True)
        if digest in hashes:
            os.link(hashes[digest], p)
        else:
            p.write_bytes(content)
            hashes[digest] = p
        outputs[relative] = {'source': source, 'sha256': digest}
    libs = {name: pe_resources(data['SystemResources/'+name]) for name in mapping['libraries'].values()}
    font = TTFont(io.BytesIO(data['Fonts/SegoeIcons.ttf']))
    for source, names in mapping['icons'].items():
        if ':' in source:
            lib, group = source.split(':')
            content = icon_svg(libs[mapping['libraries'][lib]], int(group))
        else:
            content = glyph_svg(font, source)
        for name in names.split():
            write('icons/'+name+'.svg',content,source)
    font.close()
    seen_wallpapers = set()
    for package, label, source, dark in mapping['wallpapers']:
        images = [('images',source)] + ([('images_dark',dark)] if dark else [])
        digests = [hashlib.sha256(data[name]).hexdigest() for _,name in images]
        if any(d in seen_wallpapers for d in digests):
            continue
        seen_wallpapers.update(digests)
        for (folder,name),digest in zip(images,digests):
            with Image.open(io.BytesIO(data[name])) as image:
                width,height = image.size
                image.verify()
            write(f'wallpapers/{package}/contents/{folder}/{width}x{height}.jpg',data[name],name)
        meta = {'KPlugin': {'Id':package,'Name':label,'Description':'Local Windows reference image','Authors':[{'Name':'Microsoft'}]}}
        write(f'wallpapers/{package}/metadata.json',json.dumps(meta,indent=2).encode(),'metadata')
    sounddir = 'sounds/windows-modern'
    write(sounddir+'/index.theme',b'[Sound Theme]\nName=Windows Modern (local)\nComment=Imported Windows system sounds\nInherits=freedesktop\nDirectories=stereo\n\n[stereo]\nOutputProfile=stereo\n','metadata')
    for source,names in mapping['sounds'].items():
        name = 'Media/'+source+'.wav'
        with wave.open(io.BytesIO(data[name])) as wav:
            if wav.getnframes() == 0:
                raise ValueError('Empty audio: '+name)
        for event in names.split():
            write(sounddir+'/stereo/'+event+'.wav',data[name],name)
    report = {'font': 'Segoe Fluent Icons', 'outputs': outputs, 'icon_names': sum(x.startswith('icons/') for x in outputs),
              'wallpaper_images':len(seen_wallpapers),'sound_events':sum(x.endswith('.wav') for x in outputs)}
    (stage/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Windows-resources.tar.gz or extracted Windows directory')
    parser.add_argument('--output', type=Path, default=Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'windows-modern/native-assets')
    args = parser.parse_args()
    mapping = json.loads(Path(__file__).with_name('native-assets-map.json').read_text())
    wanted = {'SystemResources/'+name for name in mapping['libraries'].values()} | {'Fonts/SegoeIcons.ttf'}
    wanted.update(name for _,_,source,dark in mapping['wallpapers'] for name in (source,dark) if name)
    wanted.update('Media/'+name+'.wav' for name in mapping['sounds'])
    data = read_assets(args.source,wanted)
    dest = args.output.expanduser().absolute()
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.native-assets-',dir=dest.parent) as temp:
        stage=Path(temp)/'new'
        stage.mkdir()
        report=build(stage,data,mapping)
        previous=Path(temp)/'previous'
        if dest.exists():
            if not (dest/'manifest.json').is_file():
                raise ValueError('Refusing to replace an unrelated directory: '+str(dest))
            dest.rename(previous)
        try:
            stage.rename(dest)
        except OSError:
            if previous.exists():
                previous.rename(dest)
            raise
    print(f"Imported {report['icon_names']} icon names, {report['wallpaper_images']} unique wallpapers, {report['sound_events']} sound events into {dest}")
    print('Run ./install.sh icons and ./install.sh themes, then ./install.sh sounds.')


if __name__ == '__main__':
    main()
