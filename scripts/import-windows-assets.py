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
import tempfile
import wave

from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen

from native_assets_input import read_assets, source_manifest
from native_assets_index import IndexedResources


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


def png_svg(content, width, height):
    b64 = base64.b64encode(content).decode('ascii')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{width}" height="{height}" viewBox="0 0 {width} {height}"><image width="{width}" height="{height}" '
            f'xlink:href="data:image/png;base64,{b64}"/></svg>\n').encode()


def indexed_icon_svg(indexed, module, group):
    content, dimensions = indexed.preview(module, group)
    with Image.open(io.BytesIO(content)) as image:
        if image.format != 'PNG' or image.size != dimensions:
            raise ValueError(f'Unexpected preview image: {module}:{group}')
        image.verify()
    return png_svg(content, *dimensions)


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


def panel_glyph_transforms(font, groups, center_groups=()):
    """Common scale per family, with optical centers for independent states.

    Wi-Fi levels keep their relative signal-dot position; other status
    variants center their actual outlines rather than the whole family box.
    """
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    em = font['head'].unitsPerEm
    ascent = font['hhea'].ascent
    result = {}
    for group, codes in groups.items():
        bounds = {}
        for code in codes:
            name = cmap.get(int(code, 16))
            if name is None:
                continue
            pen = BoundsPen(glyphs)
            glyphs[name].draw(pen)
            if pen.bounds is None:
                continue
            left, bottom, right, top = pen.bounds
            offset = (em - font['hmtx'][name][0]) / 2
            bounds[code] = (left + offset, ascent - top, right + offset, ascent - bottom)
        if not bounds:
            continue
        boxes = list(bounds.values())
        x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
        x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
        extent = max(x1 - x0, y1 - y0)
        if extent <= 0:
            continue
        scale = (em * 23 / 24) / extent
        for code, box in bounds.items():
            left, top, right, bottom = box if group in center_groups else (x0, y0, x1, y1)
            tx = em / 2 - scale * (left + right) / 2
            ty = em / 2 - scale * (top + bottom) / 2
            result[code] = f'translate({tx:.8f} {ty:.8f}) scale({scale:.8f}) '
    return result


def glyph_svg(font, code, panel_transform=''):
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
            f'<path class="ColorScheme-Text" fill="currentColor" transform="{panel_transform}translate({(em-advance)/2} {ascent}) scale(1 -1)" d="{path}"/></svg>\n').encode()


def build(stage, data, mapping, indexed=None):
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
    modules = sorted(mapping['libraries'].values())
    libs = {} if indexed else {name: pe_resources(data['SystemResources/'+name]) for name in modules}
    font = TTFont(io.BytesIO(data['Fonts/SegoeIcons.ttf']))
    # A metadata-only inventory is useful for reviewing mappings without
    # moving or redistributing Microsoft font outlines, bitmaps or binaries.
    cmap = font.getBestCmap()
    catalog = {
        'font_version': font['name'].getDebugName(5),
        'glyph_codepoints': [f'{code:04x}' for code in sorted(cmap)],
        'mun_icon_groups': {
            name: (indexed.numeric_group_ids(name) if indexed else
                   sorted({key[1] for key in libs[name] if len(key) > 1 and key[0] == 14}))
            for name in modules
        },
    }
    # The owner archive is version 1.56; allow newly mapped symbols to
    # fall back to bundled art if an older archive lacks them. Required
    # previously verified resources still fail atomically if missing.
    panel_transforms = panel_glyph_transforms(font, mapping.get('panel_glyph_groups', {}),
                                              mapping.get('panel_glyph_center_groups', []))
    optional_glyphs = set(mapping.get('optional_glyphs', []))
    missing_optional_glyphs = []
    for source, names in mapping['icons'].items():
        if ':' in source:
            lib, group = source.split(':')
            module = mapping['libraries'][lib]
            content = indexed_icon_svg(indexed, module, int(group)) if indexed else icon_svg(libs[module], int(group))
        else:
            if source in optional_glyphs and int(source, 16) not in cmap:
                missing_optional_glyphs.append(source)
                print('Optional glyph unavailable: ' + source)
                continue
            content = glyph_svg(font, source)
        for name in names.split():
            rendered = content
            if source in panel_transforms and name.startswith('status/') and name.endswith('-symbolic'):
                rendered = glyph_svg(font, source, panel_transforms[source])
            write('icons/'+name+'.svg',rendered,source)
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
    report = {'font': 'Segoe Fluent Icons', 'sources': source_manifest(data), 'outputs': outputs, 'icon_names': sum(x.startswith('icons/') for x in outputs),
              'wallpaper_images':len(seen_wallpapers),'sound_events':sum(x.endswith('.wav') for x in outputs)}
    report['missing_optional_glyphs'] = missing_optional_glyphs
    report['resource_catalog'] = catalog
    if indexed:
        report['indexed_source'] = {'manifest_sha256': indexed.manifest_sha256,
                                    'source_archive': indexed.index['source_archive']}
    (stage/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, nargs='?', help='Windows resource ZIP/TAR archive, extracted Windows directory or indexed resource checkout')
    parser.add_argument('--reuse', action='store_true', help='Reimport from the source remembered by a successful local import')
    parser.add_argument('--catalog', type=Path, help='Export only resource IDs, source hashes and mapping coverage as JSON')
    parser.add_argument('--output', type=Path, default=Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'windows-modern/native-assets')
    args = parser.parse_args()
    dest = args.output.expanduser().absolute()
    if (args.source is None) == (not args.reuse):
        parser.error('Provide a source path or --reuse, not both.')
    if args.reuse:
        try:
            previous_manifest = json.loads((dest/'manifest.json').read_text(encoding='utf-8'))
            source = Path(previous_manifest['source_path'])
        except (OSError, ValueError, KeyError, TypeError):
            parser.error('No remembered source. Import once with its local path.')
    else:
        source = args.source
    source = source.expanduser().resolve()
    if not source.exists():
        parser.error(f'Resource source does not exist: {source}; import with its current path.')
    if source == dest or dest in source.parents or (source.is_dir() and source in dest.parents):
        parser.error('Keep the original resource source and the generated output in separate locations.')
    if args.catalog:
        catalog_path = args.catalog.expanduser().resolve()
        if catalog_path == source or catalog_path == dest or dest in catalog_path.parents or catalog_path.exists():
            parser.error('Catalog must be a new file outside the source archive and generated output.')
        if source.is_dir() and source in catalog_path.parents:
            parser.error('Do not write the catalog into the original resource directory.')
    mapping_file = Path(__file__).with_name('native-assets-map.json')
    mapping_bytes = mapping_file.read_bytes()
    mapping = json.loads(mapping_bytes)
    wanted = {'SystemResources/'+name for name in mapping['libraries'].values()} | {'Fonts/SegoeIcons.ttf'}
    wanted.update(name for _,_,source,dark in mapping['wallpapers'] for name in (source,dark) if name)
    wanted.update('Media/'+name+'.wav' for name in mapping['sounds'])
    indexed = IndexedResources(source) if source.is_dir() and (source / 'resource-manifest.json').is_file() else None
    data = indexed.read_originals(wanted) if indexed else read_assets(source,wanted)
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.native-assets-',dir=dest.parent) as temp:
        stage=Path(temp)/'new'
        stage.mkdir()
        report=build(stage,data,mapping,indexed)
        report['source_path'] = str(source)  # Local manifest only; never in the catalog.
        report['mapping_sha256'] = hashlib.sha256(mapping_bytes).hexdigest()
        (stage/'manifest.json').write_text(json.dumps(report,indent=2)+'\n', encoding='utf-8')
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
    if args.catalog:
        # Do not export the local path, actual icon contents, font outlines,
        # wallpapers or audio. Exclusive creation prevents overwriting files.
        catalog = {
            **report['resource_catalog'],
            'sources': report['sources'],
            'mapping_sha256': report['mapping_sha256'],
            'mapped_icon_paths': report['icon_names'],
            'missing_optional_glyphs': report['missing_optional_glyphs'],
        }
        catalog_path.parent.mkdir(parents=True, exist_ok=True)
        with catalog_path.open('x', encoding='utf-8') as file:
            json.dump(catalog, file, indent=2)
            file.write('\n')
        print(f'Exported metadata-only resource catalog to {catalog_path}')
    print('Run ./install.sh icons and ./install.sh themes, then ./install.sh sounds.')


if __name__ == '__main__':
    main()
