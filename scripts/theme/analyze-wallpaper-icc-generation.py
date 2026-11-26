#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline ICC table construction experiments, not a runtime color engine."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import struct

import numpy as np
from PIL import Image

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


def input_curves(profile, decode):
    """Measured shared parametric types 0/3 and v2 unity-gamma sampling."""
    tag = shared_trc(profile)
    codes = np.r_[np.arange(0,256,4),255]
    # Preserve the reciprocal multiplication and binary64 floor order.
    # Division by 255 is not interchangeable at integral linear samples.
    normalized = codes*(1.0/255.0)
    linear = normalized if linear_gamma_tag(tag) else decode(profile, normalized)
    anchors = np.floor(linear*65535)
    if not np.isfinite(anchors).all() or np.any(anchors<0) or np.any(anchors>65535):
        raise ValueError('Invalid sampled source curve')
    anchors = anchors.astype(np.int64)
    if np.any(np.diff(anchors)<0):
        raise ValueError('Expected a monotone source curve')
    out = interpolate_anchors(anchors, codes, np.arange(256), 4)
    return np.tile(out,(3,1))


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


def candidate_grids(source, target):
    """Independent matrix-derived candidates, none is a verified CMM."""
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
            'fixed14_integer':integer_fixed14_grid(source,target)}


def table_metrics(actual, reference, sha):
    if actual.shape!=reference.shape:
        raise ValueError('Table shape mismatch')
    error = np.abs(actual.astype(np.int64)-reference.astype(np.int64))
    return {'sha256':sha(actual.astype('>u2').tobytes()), 'entries':int(error.size),
            'different_entries':int(np.count_nonzero(error)),
            'absolute_error_sum':int(error.sum()), 'max_error':int(error.max())}


def exhaustive_rgb8(source, candidate, native, destination, execute):
    """Compare two *portable* table replays over all RGB8 codes, in batches.

    Native-table replay is not a fresh Windows measurement for these colors.
    Hash both output streams in ascending R/G/B order.
    """
    counts = np.zeros(256,dtype=np.int64)
    colors = 0
    candidate_sha = hashlib.sha256()
    native_sha = hashlib.sha256()
    worst = None
    maximum = -1
    for start in range(0,1<<24,1<<18):
        codes = np.arange(start,min(start+(1<<18),1<<24),dtype=np.uint32)
        pixels = np.column_stack((codes>>16,(codes>>8)&255,codes&255)).astype(np.uint8)
        a = execute(source,candidate,destination,pixels)
        b = execute(source,native,destination,pixels)
        candidate_sha.update(a.tobytes())
        native_sha.update(b.tobytes())
        error = np.abs(a.astype(np.int16)-b.astype(np.int16))
        colors += int(np.count_nonzero(error.any(axis=1)))
        counts += np.bincount(error.ravel(),minlength=256)
        k,c = np.unravel_index(int(error.argmax()),error.shape)
        if int(error[k,c])>maximum:
            maximum = int(error[k,c])
            worst = {'input':pixels[k].tolist(),'candidate':a[k].tolist(),'native_replay':b[k].tolist()}
    return {'color_count':1<<24,'different_colors':colors,
            'different_channels':int(counts[1:].sum()),
            'absolute_error_sum':int(counts@np.arange(256)),
            'max_channel_error':maximum,'channel_error_histogram':{
                str(i):int(v) for i,v in enumerate(counts) if v},
            'candidate_rgb_sha256':candidate_sha.hexdigest().upper(),
            'native_replay_rgb_sha256':native_sha.hexdigest().upper(),
            'worst_witness':worst}


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
        measured = samples[name]['observation']['capture']['native_wallpaper_color_api']
        if measured['status'] != 'ok':
            raise ValueError('Missing native colorization reference')
        argb = f'0x{alpha:02X}{candidate[1:]}'
        return {**result,'weighted_seed':seed,'colorization_argb':argb,
                'native_colorization_argb':measured['argb'],
                'matches_native_colorization':argb==measured['argb']}

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
        with Image.frombytes('RGB',(1280,800),source_rgb) as image:
            width,height,baseline = runtime['_icc_rgb_bitmap'](image,data)
        if (width,height)!=(256,256):
            raise ValueError('Unexpected baseline bitmap dimensions')
        row = {'native_replay_cache':native_cache,'runtime_lcms_cache':bitmap_metrics(baseline,name),'input_curve':table_metrics(source,native_source,sha),
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
            if full_rgb8 and model=='fixed14_integer':
                row['grids'][model]['full_rgb8_replay_comparison'] = exhaustive_rgb8(
                    source,grid,native_grid,destination,execute)
        result['sources'][name] = row
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--full-rgb8',action='store_true',
                        help='Compare fixed14 and native-table replays over all RGB8 inputs')
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding='utf-8-sig'))
    print(json.dumps(analyze(ROOT,report,args.target,args.full_rgb8),indent=2))


if __name__=='__main__':
    main()
