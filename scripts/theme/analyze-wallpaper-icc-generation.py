#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline ICC table construction experiments, not a runtime color engine."""
import argparse
import hashlib
from io import BytesIO
from functools import lru_cache
import json
from pathlib import Path
import runpy
import struct

import numpy as np
from PIL import Image, ImageCms

ROOT = Path(__file__).resolve().parents[2]


def shared_trc(profile):
    tag = profile[b'rTRC']
    if tag != profile[b'gTRC'] or tag != profile[b'bTRC']:
        raise ValueError('Expected shared RGB tone curves')
    return tag


def linear_gamma_tag(tag):
    # ICC v2 curveType, one u8Fixed8 gamma value (1.0).
    return (len(tag) == 14 and tag[:4] == b'curv'
            and struct.unpack_from('>IH', tag, 8) == (1, 256))


def interpolate_anchors(anchors, codes, indices, step):
    k = np.minimum(indices//step, len(codes)-2)
    span = codes[k+1]-codes[k]
    rem = indices-codes[k]
    # Interpolate integer endpoints, round half up, including the short tail.
    return anchors[k]+((anchors[k+1]-anchors[k])*rem*2+span)//(2*span)


def input_curves(profile, _decode):
    """Share the installed source curve generator with offline diagnostics."""
    generator = matrix_runtime()['matrix_input_curve']
    return np.asarray([generator(profile[key]) for key in (b'rTRC',b'gTRC',b'bTRC')],
                      dtype=np.int64)


def output_curves(profile):
    """Measured shared sampled sRGB or v2 unity-gamma inverse curve."""
    tag = shared_trc(profile)
    if linear_gamma_tag(tag):
        # Unity gamma: native 16-code anchor spacing and a final 15-code span.
        codes = np.r_[np.arange(0,1024,16),1023]
        anchors = (2*codes*65535+1023)//(2*1023)
        out = interpolate_anchors(anchors,codes,np.arange(1024),16)
        return np.tile(out,(3,1))
    if (tag[:4]!=b'curv' or len(tag)!=12+2048 or struct.unpack_from('>I',tag,8)[0]!=1024):
        raise ValueError('Expected a measured linear or 1024-point sampled curve')
    curve = np.frombuffer(tag[12:],'>u2').astype(np.int64)
    if curve[0]!=0 or curve[-1]!=65535 or np.any(np.diff(curve)<=0):
        raise ValueError('Expected a strictly increasing full-range target curve')
    x = (np.arange(1024,dtype=np.int64)*65535+511)//1023
    # At exact interior nodes use the preceding segment, not the next one.
    k = np.clip(np.searchsorted(curve,x,side='left')-1,0,1022)
    delta = curve[k+1]-curve[k]
    out = k*65536//1023+(x-curve[k])*65536//(delta*1023)
    return np.tile(out.clip(0,65535),(3,1))


def integer_fixed14_grid(source, target):
    """Reproduce the exploratory fixed14 model without floating-point rounding.

    Restricted to the measured small, nonsingular ICC colorant matrices.
    This model is not a verified replacement for the native CLUT.
    """
    matrices = []
    for m in (source, target):
        a = m*65536
        if (a.shape != (3,3) or not np.isfinite(a).all() or np.any(np.abs(a)>131072)
                or np.any(a!=np.floor(a))):
            raise ValueError('Expected small signed 16.16 ICC colorants')
        matrices.append(a.astype(np.int64))
    src, dst = matrices
    adj = np.array([np.cross(dst[:,1],dst[:,2]),np.cross(dst[:,2],dst[:,0]),
                    np.cross(dst[:,0],dst[:,1])])
    det = int(dst[:,0]@adj[0])
    if det <= 0:
        raise ValueError('Expected a positive destination determinant')
    # Python integers are required for the Q16 rounding numerator.
    coeff = [[(2*int(v)*65536**2+det)//(2*det) for v in row] for row in adj]
    if any(abs(v)>16*65536 for row in coeff for v in row):
        raise ValueError('Destination inverse exceeds diagnostic bounds')
    inverse = np.array(coeff,dtype=np.int64)
    nodes = np.indices((32,32,32),dtype=np.int64).reshape(3,-1).T
    coordinate = (nodes*16384+15)//31
    source_q = (src+2)//4
    xyz_q13 = (coordinate@source_q.T+16384)//32768
    raw = (xyz_q13@inverse.T)*65535//(1<<29)
    return raw.clip(0,65535).reshape(32,32,32,3)


@lru_cache(maxsize=1)
def matrix_runtime():
    return runpy.run_path(str(ROOT / 'scripts/theme/wallpaper-icc.py'))


def staged_matrix_grid(source, target):
    """Use the same exact-integer staged grid as the installed decoder."""
    matrices = []
    for matrix in (source, target):
        values = matrix * 65536
        if (values.shape != (3, 3) or not np.isfinite(values).all()
                or np.any(np.abs(values) > 131072) or np.any(values != np.rint(values))):
            raise ValueError('Expected small signed 16.16 ICC colorants')
        matrices.append(tuple(tuple(int(v) for v in row) for row in values))
    grid = matrix_runtime()['build_matrix_grid'](*matrices)
    return np.asarray(grid, dtype=np.int64).reshape(32,32,32,3)


def candidate_grids(source, target):
    """Compare historical approximations with the measured staged model."""
    nodes = np.indices((32,32,32)).reshape(3,-1).T/31
    inverse = np.linalg.inv(target)
    direct = np.floor(nodes@source.T@inverse.T*65535+0.5)
    # Exploratory model: quantized source matrix, XYZ, inverse matrix.
    source_q = np.floor(source*16384+0.5)/16384
    xyz = np.floor(nodes@source_q.T*8192+0.5)/8192
    inverse_q = np.floor(inverse*65536+0.5)/65536
    fixed = np.floor(xyz@inverse_q.T*65535)
    return {**{name:value.clip(0,65535).astype(np.int64).reshape(32,32,32,3)
               for name,value in (('matrix',direct),('fixed13',fixed))},
            'fixed14_integer':integer_fixed14_grid(source,target),
            'staged_matrix':staged_matrix_grid(source,target)}


def table_metrics(actual, reference, sha):
    if actual.shape!=reference.shape:
        raise ValueError('Table shape mismatch')
    error = np.abs(actual.astype(np.int64)-reference.astype(np.int64))
    return {'sha256':sha(actual.astype('>u2').tobytes()), 'entries':int(error.size),
            'different_entries':int(np.count_nonzero(error)),
            'absolute_error_sum':int(error.sum()), 'max_error':int(error.max())}


def exhaustive_rgb8(candidate_tables, native_tables, execute, native_full=None):
    """Compare generated and measured-table replays in bounded RGB8 batches.

    With schema 2 evidence, verify the measured-table output against each
    observed WIC red slice and the complete native output hash. Without
    it, results describe only a comparison of two portable replays.
    """
    counts = np.zeros(256,dtype=np.int64)
    colors = 0
    candidate_sha = hashlib.sha256()
    native_sha = hashlib.sha256()
    worst = None
    maximum = -1
    different_red_slices = []
    for start in range(0,1<<24,1<<18):
        codes = np.arange(start,min(start+(1<<18),1<<24),dtype=np.uint32)
        pixels = np.column_stack((codes>>16,(codes>>8)&255,codes&255)).astype(np.uint8)
        a = execute(*candidate_tables,pixels)
        b = execute(*native_tables,pixels)
        candidate_sha.update(a.tobytes())
        native_sha.update(b.tobytes())
        if native_full is not None:
            for offset in range(0,len(pixels),1<<16):
                red = (start+offset)>>16
                end = offset+(1<<16)
                expected = native_full['red_slice_sha256'][red]
                if hashlib.sha256(b[offset:end].tobytes()).hexdigest().upper()!=expected:
                    raise ValueError(f'Native-table replay differs from measured WIC at red slice {red}')
                if hashlib.sha256(a[offset:end].tobytes()).hexdigest().upper()!=expected:
                    different_red_slices.append(red)
        error = np.abs(a.astype(np.int16)-b.astype(np.int16))
        colors += int(np.count_nonzero(error.any(axis=1)))
        counts += np.bincount(error.ravel(),minlength=256)
        k,c = np.unravel_index(int(error.argmax()),error.shape)
        if int(error[k,c])>maximum:
            maximum = int(error[k,c])
            worst = {'input':pixels[k].tolist(),'candidate':a[k].tolist(),'native_replay':b[k].tolist()}
    native_digest = native_sha.hexdigest().upper()
    if native_full is not None and native_digest != native_full['sha256']:
        raise ValueError('Native-table replay differs from complete measured WIC hash')
    result = {'color_count':1<<24,'different_colors':colors,
            'different_channels':int(counts[1:].sum()),
            'absolute_error_sum':int(counts@np.arange(256)),
            'max_channel_error':maximum,'channel_error_histogram':{
                str(i):int(v) for i,v in enumerate(counts) if v},
            'candidate_rgb_sha256':candidate_sha.hexdigest().upper(),
            'native_replay_rgb_sha256':native_digest,
            'worst_witness':worst}
    if native_full is not None:
        result.update(native_wic_hash_verified=True,
                      different_red_slices=different_red_slices,
                      matches_native=(colors==0 and not different_red_slices
                                      and result['candidate_rgb_sha256']==native_digest))
    return result


def analyze(root, report, target_path, full_rgb8=False):
    precision = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    engine = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
    evidence = json.loads((root/'docs/windows11-26h2-icc-native-matches.json').read_text())
    # Validate the earlier reference, all successful raw buffers and native links.
    verification = precision['analyze'](report,evidence)
    target, _, sources, _ = engine['inputs'](root,target_path)
    cache = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc.py'))
    samples,_,prepare,rows,layout,colors,_,_,cache_refs = cache['reference_data'](root)
    runtime = runpy.run_path(str(root/'scripts/theme/sync-accent.py'))
    tags, matrix, decode, sha = (engine[k] for k in ('tags','matrix','decode','sha'))
    read, execute, checked, rgb, partitions = (precision[k] for k in
        ('read_rgb8_tables','execute_rgb8_tables','checked','rgb','partitions'))
    target_tags = tags(target)
    destination = output_curves(target_tags)
    pixels = rgb(checked(report['input_rgb']),8)
    n = report['calibration_count']
    if [tuple(pixel) for pixel in pixels[:n].tolist()] != colors:
        raise ValueError('Cache calibration and RGB8 input order differ')
    def bitmap_metrics(bitmap,name):
        result = cache['metrics'](bitmap,cache_refs[name])
        seed, alpha = runtime['derive_weighted_wallpaper_bitmaps'](((256,256,bitmap),))
        candidate = runtime['normalize_weighted_wallpaper_seed'](seed)
        capture = samples[name]['observation']['capture']
        measured = capture['native_wallpaper_color_api']
        if measured['status'] != 'ok':
            raise ValueError('Missing native colorization reference')
        argb = f'0x{alpha:02X}{candidate[1:]}'
        palette = runtime['derive_automatic_palette'](candidate)
        native_palette = {}
        for role in ('Accent', *runtime['PRESET_SHADE_ROLES']):
            value = capture['appearance']['colors_argb'][role]
            if len(value)!=9 or value[:3].upper()!='#FF':
                raise ValueError('Expected opaque native shade')
            native_palette[role] = runtime['rgb']('#'+value[3:])
        differences = {role:{'candidate':palette[role],'native':value}
                       for role,value in native_palette.items() if palette[role]!=value}
        return {**result,'weighted_seed':seed,'colorization_argb':argb,
                'native_colorization_argb':measured['argb'],
                'matches_native_colorization':argb==measured['argb'],
                'palette':palette,'native_palette':native_palette,
                'different_palette_roles':differences,
                'mode_accent_matches':{'dark':palette['AccentLight2']==native_palette['AccentLight2'],
                                       'light':palette['AccentDark1']==native_palette['AccentDark1']}}

    def cache_metrics(prediction,name):
        mapping = {color:bytes(pixel) for color,pixel in zip(colors,prediction[:n])}
        return bitmap_metrics(cache['bitmap'](rows,layout,mapping,prepare),name)

    source_rows = [b''.join(map(bytes,row)) for row in rows]
    source_rgb = b''.join(source_rows[i] for i in layout)
    result = {'windows_build':report['windows_build'],'target_sha256':sha(target),'sources':{}}
    for name, data in sources.items():
        profile = tags(data)
        source = input_curves(profile,decode)
        item = report['results'][name]
        reference = rgb(checked(item['wic'],len(pixels)*3),8)
        native_links = [read(checked(item['intents'][intent]['link_profile'])) for intent in ('0','1','2')]
        native_source, native_grid, native_destination = native_links[0]
        if any(not np.array_equal(a,b) for link in native_links[1:] for a,b in zip(link,native_links[0])):
            raise ValueError('Native table differs across measured intents')
        if any(verification['results'][name][intent]['portable_rgb8']['vs_wic'][part]['max_channel_error']
               for intent in ('0','1','2') for part in ('calibration','mixed')):
            raise ValueError('Native replay did not reproduce reference')
        curves_only = execute(source,native_grid,destination,pixels)
        if not np.array_equal(source,native_source) or not np.array_equal(destination,native_destination):
            raise ValueError('Generated curves do not reproduce measured tables')
        native_cache = cache_metrics(curves_only,name)
        if native_cache['different_pixels']:
            raise ValueError('Native table replay does not reproduce archived cache')
        # Little CMS is an explicitly labelled research comparator only.
        with Image.frombytes('RGB',(1280,800),source_rgb) as image:
            with ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(BytesIO(data)),
                    ImageCms.createProfile('sRGB'), renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC,
                    outputMode='RGB') as converted:
                width,height,baseline = prepare(converted.tobytes(),converted.width,converted.height)
        if (width,height)!=(256,256):
            raise ValueError('Unexpected baseline bitmap dimensions')
        row = {'native_replay_cache':native_cache,'offline_lcms_cache':bitmap_metrics(baseline,name),'input_curve':table_metrics(source,native_source,sha),
               'output_curve':table_metrics(destination,native_destination,sha),
               'generated_curves_native_grid':partitions(curves_only,reference,n), 'grids':{}}
        for model, grid in candidate_grids(matrix(profile),matrix(target_tags)).items():
            prediction = execute(source,grid,destination,pixels)
            row['grids'][model] = {'table':table_metrics(grid,native_grid,sha),
                                  'fully_generated_rgb8':partitions(prediction,reference,n),
                                  'wallpaper_cache':cache_metrics(prediction,name)}
            # Nonnegative tetrahedral weights sum to one. A vertex-error
            # bound of less than 64 raw units changes the output index by
            # at most one (one step spans 64 raw units).
            max_vertex_error = row['grids'][model]['table']['max_error']
            if max_vertex_error < 64:
                row['grids'][model]['rgb8_error_bound'] = int(np.abs(np.diff(destination>>8,axis=1)).max())
            if full_rgb8 and model=='staged_matrix':
                row['grids'][model]['full_rgb8_replay_comparison'] = exhaustive_rgb8(
                    (source,grid,destination),(source,native_grid,destination),execute)
        result['sources'][name] = row
    return result


def analyze_full_generation(root, report, target_path, source_paths, full_rgb8=False):
    """Separate source curves, CLUT generation, and output curves for schema 2.

    Additional matrix profiles are provided explicitly, identified by the
    exact native source hash. No private source profile or link is published.
    """
    precision = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    engine = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
    evidence = json.loads((root/'docs/windows11-26h2-icc-native-matches.json').read_text())
    # Reuse the full-domain diagnostic instead of introducing a second
    # verifier or treating the native-link replay as fresh native data.
    verification = precision['analyze_full_rgb8'](report,evidence)
    target, _, sources, _ = engine['inputs'](root,target_path)
    tags,matrix,decode,sha = (engine[k] for k in ('tags','matrix','decode','sha'))
    read,execute,checked,rgb,partitions = (precision[k] for k in
        ('read_rgb8_tables','execute_rgb8_tables','checked','rgb','partitions'))
    synthetic_hashes = {
        '3633820C700F656C83A23C1D0DAA20214E73D040AB13E6B87262CEF513D0B5CA',
        '6A907D854C58B4625AADACA152438EE1BC857B46EE106D31381208493023B268',
    }
    for name, item in report.get('synthetic_sources', {}).items():
        digest = report['sources'].get(name)
        if digest not in synthetic_hashes or name != 'custom-'+digest:
            raise ValueError('Unexpected embedded synthetic curve profile')
        data = checked(item)
        if data is None or sha(data)!=digest:
            raise ValueError('Synthetic curve profile failed identity check')
        sources[name] = data
    for path in source_paths:
        with path.open('rb') as stream:
            data = stream.read(16*1024*1024+1)
        if len(data)>16*1024*1024:
            raise ValueError('Oversized source ICC profile')
        digest = sha(data)
        matches = [name for name,value in report['sources'].items() if value==digest]
        if len(matches)!=1:
            raise ValueError('Source ICC is not identified in the native report')
        sources[matches[0]] = data
    target_tags = tags(target)
    destination = output_curves(target_tags)
    target_matrix = matrix(target_tags)
    pixels = rgb(checked(report['input_rgb']),8)
    n = report['calibration_count']
    result = {'windows_build':report['windows_build'],'target_sha256':sha(target),
              'missing_source_profiles':sorted(set(report['sources'])-set(sources)),
              'sources':{}}
    for name,data in sources.items():
        measured = verification['full_rgb8'][name]
        row = {'source_sha256':sha(data),'native_full_rgb8':measured}
        result['sources'][name] = row
        if measured.get('status')!='compared':
            row['status'] = 'native-link-unavailable'
            continue
        profile = tags(data)
        # Restrict the matrix candidate to the matrix/TRC path. An ICC LUT
        # profile may have fallback colorants that do not describe its CMM.
        if (data[16:24]!=b'RGB XYZ ' or any(key.startswith(
                (b'A2B',b'B2A',b'D2B',b'B2D')) for key in profile)
                or any(len(profile.get(key,b''))!=20 or profile[key][:4]!=b'XYZ '
                       for key in (b'rXYZ',b'gXYZ',b'bXYZ'))):
            row['status'] = 'unsupported-matrix-profile'
            continue
        try:
            source = input_curves(profile,decode)
            grid = staged_matrix_grid(matrix(profile),target_matrix)
        except (KeyError,ValueError,struct.error) as error:
            row.update(status='unsupported-matrix-profile',reason=str(error))
            continue
        item = report['results'][name]
        native_source,native_grid,native_destination = read(checked(item['intents']['1']['link_profile']))
        runtime = matrix_runtime()
        try:
            runtime_tables = runtime['generate_matrix_tables'](data)
        except runtime['UnsupportedMatrixProfile'] as error:
            row['installed_generator'] = {'status':'unsupported','reason':str(error)}
        else:
            references = (native_source,native_grid,native_destination)
            row['installed_generator'] = {
                'status':'compared',
                'tables':[table_metrics(np.asarray(table,dtype=np.int64).reshape(reference.shape),
                                        reference,sha)
                          for table,reference in zip(runtime_tables,references)]}
        native_output = checked(item['wic'],len(pixels)*3)
        if native_output is None:
            row['status'] = 'missing-native-calibration'
            continue
        reference = rgb(native_output,8)
        stages = {
            'source_curve_only': (source,native_grid,native_destination),
            'clut_only': (native_source,grid,native_destination),
            'output_curve_only': (native_source,native_grid,destination),
            'all_generated': (source,grid,destination),
        }
        row.update(status='compared',
                   source_curve=table_metrics(source,native_source,sha),
                   source_curve_channels={
                       channel:table_metrics(source[i],native_source[i],sha)
                       for i,channel in enumerate(('red','green','blue'))},
                   clut_model='staged_matrix',
                   clut=table_metrics(grid,native_grid,sha),
                   output_curve=table_metrics(destination,native_destination,sha),
                   all_tables_identical=all(np.array_equal(a,b) for a,b in zip(
                       (source,grid,destination),(native_source,native_grid,native_destination))),
                   calibration_and_mixed={key:partitions(execute(*tables,pixels),reference,n)
                                          for key,tables in stages.items()})
        if full_rgb8:
            native = item['full_rgb8']
            if measured['matches_full_rgb8']:
                # Numeric differences are measured against the portable
                # reference only after proving it matches every WIC slice.
                row['generated_full_rgb8'] = exhaustive_rgb8(
                    stages['all_generated'], (native_source,native_grid,native_destination),
                    execute, native)
                row['generated_full_rgb8']['matches_native'] &= all(
                    not part['different_colors'] for part in
                    row['calibration_and_mixed']['all_generated'].values())
            else:
                # A generated hash is still useful, but replay differences
                # cannot be attributed to native WIC if its proof failed.
                digest,slices = precision['full_rgb8_hash'](stages['all_generated'])
                different = [i for i,(a,b) in enumerate(zip(slices,native['red_slice_sha256'])) if a!=b]
                row['generated_full_rgb8'] = {
                    'candidate_rgb_sha256':digest,'different_red_slices':different,
                    'native_wic_hash_verified':False,
                    'matches_native':digest==native['sha256'] and not different
                        and all(not part['different_colors'] for part in
                                row['calibration_and_mixed']['all_generated'].values())}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--full-rgb8',action='store_true',
                        help='Compare the generated RGB8 domain with the available reference')
    parser.add_argument('--source-profile',action='append',type=Path,default=[],
                        help='Additional exact source ICC for a schema 2 native report')
    args = parser.parse_args()
    with args.report.open('rb') as stream:
        raw = stream.read(64*1024*1024+1)
    if len(raw)>64*1024*1024:
        parser.error('Oversized native report')
    report = json.loads(raw.decode('utf-8-sig'))
    if report['schema_version']==2:
        result = analyze_full_generation(ROOT,report,args.target,args.source_profile,args.full_rgb8)
    else:
        if args.source_profile:
            parser.error('--source-profile requires a schema 2 native report')
        result = analyze(ROOT,report,args.target,args.full_rgb8)
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
