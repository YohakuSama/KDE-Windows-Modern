#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify controlled matrix captures and isolate the inferred PCS lattice."""
import argparse
import base64
import json
from pathlib import Path
import runpy
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PAIRS = (
    'linear-srgb|registered-srgb', 'source-v2|registered-srgb',
    'diagonal|diagonal', 'linear-srgb|diagonal', 'diagonal|registered-srgb',
    'mixed|diagonal', 'diagonal|mixed', 'mixed-delta|diagonal', 'diagonal|mixed-delta',
)
PROFILE_HASHES = {
    'linear-srgb': 'BC77188D9AABAF2F17730FBE0C3B3954579190954C6E273C35C33D52CFB193B6',
    'registered-srgb': '2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E',
    'diagonal': 'EA4E03FD6DE5B7FDE826920BA1AD0D23FE16A3756A2D35B412E6E387F222A850',
    'mixed': '5B3116A2C13082F54CD1DC7D15614B1A07CF9170B953CC7D44B8995C9048B829',
    'mixed-delta': '0C4CB39F7174458D06AE88D3123ADF7195BA60B1FA325A46CC207DA144F58B3E',
    'source-v2': '6EC51764DA076242F36221B786533ACF8EAB04A2FCA4C604E7C1644238A8CA37',
}


def endpoint_regression(execute):
    # Synthetic grid: an exact endpoint lands on curve index 128.
    source = np.tile(np.arange(256, dtype=np.int64)*257, (3,1))
    output = np.tile(np.minimum(np.arange(1024, dtype=np.int64)*64,65535),(3,1))
    grid = np.zeros((32,32,32,3), dtype=np.int64)
    grid[:,:,-2,1] = 7928
    grid[:,:,-1,1] = 8192
    pixels = np.array([[0,0,255]], dtype=np.uint8)
    if execute(source,grid,output,pixels).tolist() != [[0,32,0]]:
        raise ValueError('Maximum input vertex regression')


def neutral_axis_constraints(grids, matrices):
    """Separate per-coefficient native rounding from row-sum-only models.

    For a diagonal destination, each ideal neutral-axis output component
    depends only on the corresponding source colorant row sum. Any
    differences with equal exact row sums reject that particular model,
    regardless of its final scalar rounding function.
    """
    indices = np.arange(32)
    sums = {name: np.rint(matrix * 65536).astype(np.int64).sum(axis=1)
            for name, matrix in matrices.items()}
    result = {}
    for target in ('diagonal', 'registered-srgb'):
        reference = grids['diagonal|' + target].reshape(32,32,32,3)[indices,indices,indices]
        rows = {}
        for pair, grid in grids.items():
            source, destination = pair.split('|')
            if destination != target or source == 'diagonal':
                continue
            observed = grid.reshape(32,32,32,3)[indices,indices,indices]
            delta = observed.astype(np.int64) - reference.astype(np.int64)
            same_sum = sums[source] == sums['diagonal']
            hits = np.argwhere(delta != 0)
            # Other row sums cannot influence a diagonal destination's
            # corresponding ideal component. For a non-diagonal target
            # this is descriptive only, not a channel-wise counterexample.
            contradiction = (delta != 0) & same_sum if target == 'diagonal' else np.zeros_like(delta, dtype=bool)
            violations = np.argwhere(contradiction)
            witness = None
            if len(violations):
                node, channel = map(int, violations[0])
                witness = {'node':node, 'channel':channel,
                           'source_row_sum_s15fixed16':int(sums[source][channel]),
                           'reference_raw':int(reference[node,channel]),
                           'source_raw':int(observed[node,channel])}
            rows[source] = {
                'source_row_sums_s15fixed16':sums[source].tolist(),
                'diagonal_row_sums_s15fixed16':sums['diagonal'].tolist(),
                'different_nodes':int(np.count_nonzero(np.any(delta != 0, axis=1))),
                'different_entries':len(hits),
                'maximum_raw_error':int(np.abs(delta).max()),
                'equal_row_sum_counterexamples':len(violations),
                'counterexample':witness,
            }
        result[target] = rows
    return result


def analyze(root, report, target_path):
    p = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    e = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
    gen = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-generation.py'))
    evidence = json.loads((root/'docs/windows11-26h2-icc-native-matches.json').read_text())
    sha, checked = p['sha'], p['checked']
    if (report['schema_version'],report['windows_build'],report['flags'],report['intent'],report['color_count']) != (1,'26300.9974',3,1,1024):
        raise ValueError('Unexpected matrix measurement identity')
    if report['profiles'] != PROFILE_HASHES or set(report['results']) != set(PAIRS):
        raise ValueError('Unexpected profile or transform set')
    raw = checked(report['input_rgb'],3072)
    calibration,_ = p['inputs']()
    if raw != calibration or sha(raw) != evidence['input_rgb_sha256']:
        raise ValueError('Unexpected calibration input')
    target,_,sources,_ = e['inputs'](root,target_path)
    profiles = {'linear-srgb':sources['linear-srgb'],'registered-srgb':target}
    if set(report['matrix_profiles']) != set(PROFILE_HASHES)-set(profiles):
        raise ValueError('Unexpected synthetic profile set')
    for name,item in report['matrix_profiles'].items():
        profiles[name] = base64.b64decode(item['base64'],validate=True)
        if sha(profiles[name]) != item['sha256']:
            raise ValueError('Synthetic profile hash mismatch')
    if {name:sha(data) for name,data in profiles.items()} != PROFILE_HASHES:
        raise ValueError('Profile identity mismatch')
    tags = {name:e['tags'](data) for name,data in profiles.items()}
    matrices = {name:e['matrix'](profile) for name,profile in tags.items()}
    input_tables = {name:gen['input_curves'](tags[name],e['decode'])
                    for name in {pair.split('|')[0] for pair in PAIRS}}
    output_tables = {name:gen['output_curves'](tags[name])
                     for name in {pair.split('|')[1] for pair in PAIRS}}
    endpoint_regression(p['execute_rgb8_tables'])
    pixels = p['rgb'](raw,8)
    grids, table_sets, results = {}, {}, {}
    cmm_versions = set()
    for pair in PAIRS:
        entry = report['results'][pair]
        if entry['status'] != 'ok':
            raise ValueError('Native transform failed: '+pair)
        direct = checked(entry['direct']['outputs']['8to8'],3072)
        replay = checked(entry['link_replay']['outputs']['8to8'],3072)
        link = checked(entry['link_profile'])
        if direct is None or replay != direct or link is None:
            raise ValueError('Native replay mismatch: '+pair)
        for kind in ('direct','link_replay'):
            identity = tuple(entry[kind][key] for key in
                             ('cmm_ident','cmm_dll_version','cmm_win_version'))
            if identity[0] != '57696E20':
                raise ValueError('Unexpected native CMM')
            cmm_versions.add(identity)
        tables = p['read_rgb8_tables'](link)
        pred = p['execute_rgb8_tables'](*tables,pixels)
        if pred.tobytes() != direct:
            raise ValueError('Portable replay mismatch: '+pair)
        src,dst = pair.split('|')
        source_curve = input_tables[src]
        output_curve = output_tables[dst]
        generated = p['execute_rgb8_tables'](source_curve,tables[1],output_curve,pixels)
        table_sets[pair] = tables
        grids[pair] = tables[1].reshape(-1,3)
        results[pair] = {'rgb8_sha256':sha(direct),'clut_sha256':sha(tables[1].astype('>u2').tobytes()),
                         'matching_rgb8_colors':len(pixels),
                         'generated_input_curve':gen['table_metrics'](source_curve,tables[0],sha),
                         'generated_output_curve':gen['table_metrics'](output_curve,tables[2],sha),
                         'generated_curves_native_grid':p['metric'](generated,p['rgb'](direct,8))}
    control = next(s for s in evidence['samples'] if s['source']=='linear-srgb')
    if results[PAIRS[0]]['rgb8_sha256'] != control['output_rgb_sha256']:
        raise ValueError('Original calibration control mismatch')
    equal_v2 = all(np.array_equal(a,b) for a,b in zip(table_sets[PAIRS[0]],table_sets[PAIRS[1]]))
    forward_delta = int(np.count_nonzero(grids['mixed|diagonal']!=grids['mixed-delta|diagonal']))
    inverse_delta = int(np.count_nonzero(grids['diagonal|mixed']!=grids['diagonal|mixed-delta']))
    # Project the two independently generated outputs onto the inferred PCS
    # lattice. Exclude clipped RGB channels: those cannot identify XYZ.
    a,b = grids['linear-srgb|diagonal'],grids[PAIRS[0]]
    mask = ((a>0)&(a<65535)&(b>0)&(b<65535)).all(axis=1)
    def project(grid,name):
        value = grid @ matrices[name].T / 8
        return np.floor(value+.5).astype(np.int64)
    qa,qb = project(a,'diagonal'),project(b,'registered-srgb')
    delta = np.abs(qa[mask]-qb[mask])
    # This is a numerical inference, not a native intermediate buffer.
    pcs = {'unclipped_nodes':int(mask.sum()),'entries':int(delta.size),
           'different_entries':int(np.count_nonzero(delta)),'max_error':int(delta.max())}
    # Use the diagonal control to separate the remaining inverse error.
    control_grid = grids['diagonal|diagonal']
    nodes = np.indices((32,32,32)).reshape(3,-1).T
    interior = ((nodes>0)&(nodes<31)).all(axis=1)
    q = project(control_grid,'diagonal')[interior]
    inverse_metrics = {}
    for name in ('diagonal','registered-srgb','mixed','mixed-delta'):
        expected = grids['diagonal|'+name][interior]
        matrix = np.linalg.inv(matrices[name])
        guess = np.floor(q/8192 @ (np.floor(matrix*65536+.5)/65536).T *65535).clip(0,65535)
        inverse_metrics[name] = p['metric'](guess,expected)
    return {'windows_build':report['windows_build'],'verified_payloads':32,
            'native_cmm_versions':[{'ident':ident,'dll_version':dll,'win_version':win}
                                   for ident,dll,win in sorted(cmm_versions)],
            'neutral_axis_constraints':neutral_axis_constraints(grids,matrices),
            'portable_rgb8_colors':len(PAIRS)*len(pixels),'pairs':results,
            'v2_v4_identical_tables':equal_v2,'source_perturbation_changed_entries':forward_delta,
            'target_perturbation_changed_entries':inverse_delta,'inferred_shared_pcs':pcs,
            'inverse_from_inferred_pcs':inverse_metrics}



PCS_PROFILES = {
    'xyz-identity': 'B6E383B40B96A7BD0824C145B5761692B92851B4DF4BD16319157CCB21D19D77',
    'rgb-pcs': 'D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4',
    'rgb-pcs-zyx': '086832DEE2195FBFC5FAF48A48C30CF2301D70CBA9C92CA46C11E6257C5DBB18',
}
PCS_PAIRS = (
    'xyz-identity|xyz-identity', 'rgb-pcs|rgb-pcs', 'rgb-pcs|rgb-pcs-zyx',
    'xyz-identity|rgb-pcs', 'rgb-pcs|xyz-identity',
    'linear-srgb|xyz-identity', 'mixed|xyz-identity', 'diagonal|xyz-identity',
    'xyz-identity|diagonal', 'xyz-identity|registered-srgb', 'xyz-identity|mixed', 'xyz-identity|mixed-delta',
    'linear-srgb|rgb-pcs', 'mixed|rgb-pcs', 'diagonal|rgb-pcs',
    'rgb-pcs|diagonal', 'rgb-pcs|registered-srgb', 'rgb-pcs|mixed', 'rgb-pcs|mixed-delta',
    'linear-srgb|rgb-pcs-zyx', 'rgb-pcs-zyx|registered-srgb',
    'linear-srgb|registered-srgb', 'diagonal|diagonal',
)


def pcs_inputs():
    markers = np.array([[0,0,0],[1,12345,32768],[32768,1,65535],[1000,2000,3000],
                        [65535,0,0],[0,65535,0],[0,0,65535],[65535,65535,65535]])
    nodes = np.indices((32,32,32)).reshape(3,-1).T
    grid = (nodes*65535+15)//31
    axes = np.zeros((3,8193,3),dtype=np.int64)
    for axis in range(3):
        axes[axis,:,axis] = np.arange(8193)*4
    return np.concatenate((markers,grid,axes.reshape(-1,3))).astype('<u2')


def table_difference(a,b):
    if a.shape != b.shape:
        raise ValueError('Table shape mismatch')
    error = np.abs(a.astype(np.int64)-b.astype(np.int64))
    return {'different_entries':int(np.count_nonzero(error)),
            'absolute_error_sum':int(error.sum()),'max_error':int(error.max())}


def bridge_curve_tables(profile):
    """Generate the measured unity curves of the synthetic mft2 bridges.

    The CLUT (identity or ZYX) is separate. Do not generalize this sampling
    rule to arbitrary LUT profiles or matrix-profile tone curves.
    """
    identity_matrix = (65536,0,0,0,65536,0,0,0,65536)
    for sig in (b'A2B0',b'B2A0'):
        tag = profile[sig]
        if (len(tag)!=124 or tag[:4]!=b'mft2' or tag[8:11]!=bytes((3,3,2))
                or struct.unpack_from('>9i',tag,12)!=identity_matrix
                or struct.unpack_from('>HH',tag,48)!=(2,2)):
            raise ValueError('Expected the measured two-point mft2 bridge')
        for raw in (tag[52:64],tag[-12:]):
            if struct.unpack('>6H',raw)!=(0,65535)*3:
                raise ValueError('Expected full-range unity bridge curves')
    def sample(count, scale):
        # Round to Q15 first, then round the ICC export. The input and
        # output paths have distinct scale factors; preserve full white.
        i = np.arange(count,dtype=np.int64)
        q = (2*i*32768+count-1)//(2*(count-1))
        values = (q*scale+16384)//32768
        values[-1] = 65535
        return np.tile(values,(3,1))
    return sample(256,65534), sample(1024,65535)


def separable_grid(grid, reverse_output=False):
    """Measure, not generate, an axis-separable native grid."""
    logical = grid[...,::-1] if reverse_output else grid
    reconstructed = np.empty_like(logical)
    for c in range(3):
        axis = np.moveaxis(logical[...,c],c,0)[:,0,0]
        np.moveaxis(reconstructed[...,c],c,0)[...] = axis[:,None,None]
    return table_difference(reconstructed,logical)


def analyze_pcs(root, report, matrix_report):
    """Validate isolated PCS boundary captures against the prior matrix report."""
    p = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    e = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
    sha, checked = p['sha'], p['checked']
    fields = ('schema_version','probe_set','windows_build','flags','intent',
              'marker_count','grid_count','axis_count','color_count','input_words')
    if tuple(report[k] for k in fields) != (
            1,'Pcs','26300.9974',3,1,8,32768,8193,57355,'little-endian three WORDs'):
        raise ValueError('Unexpected PCS measurement identity')
    hashes = {**PROFILE_HASHES,**PCS_PROFILES}
    if report['profiles'] != hashes or set(report['results']) != set(PCS_PAIRS):
        raise ValueError('Unexpected PCS profile or transform set')
    profiles = {}
    for key,names in (('matrix_profiles',set(PROFILE_HASHES)-{'linear-srgb','registered-srgb'}),
                      ('pcs_profiles',set(PCS_PROFILES))):
        if set(report[key]) != names:
            raise ValueError('Unexpected embedded synthetic profiles')
        for name,item in report[key].items():
            data = base64.b64decode(item['base64'],validate=True)
            if sha(data) != item['sha256'] or sha(data) != hashes[name]:
                raise ValueError('Synthetic profile hash mismatch')
            e['tags'](data)
            profiles[name] = data
    bridge_curves = {name:bridge_curve_tables(e['tags'](profiles[name]))
                     for name in PCS_PROFILES}
    generated_curves = {}
    pixels = pcs_inputs()
    raw = checked(report['input16'],pixels.nbytes)
    if raw != pixels.tobytes() or sha(raw) != 'CE19EB355E773C647F28C7A7DD9FDE12B756955FC590C0B4CD51996B2ACD9997':
        raise ValueError('Unexpected PCS input words')
    pixels = pixels.astype(np.int64)
    # All grid and axis inputs have a corresponding red/blue-reversed input.
    # Exclude the asymmetric marker set from this comparison.
    perm = np.r_[8+np.arange(32768).reshape(32,32,32).transpose(2,1,0).ravel(),
                 32776+np.arange(3*8193).reshape(3,8193)[::-1].ravel()]
    if not np.array_equal(pixels[perm],pixels[8:,::-1]):
        raise ValueError('Incorrect channel permutation')
    results, colors, tables = {}, {}, {}
    payloads = 1+len(profiles)
    bitmap_success = 0
    bitmap_comparisons = 0
    for pair in PCS_PAIRS:
        entry = report['results'][pair]
        if entry['status'] != 'ok' or entry['cmm_ident'] != '57696E20':
            raise ValueError('Native Win CMM transform unavailable: '+pair)
        color = checked(entry['color16'],pixels.size*2)
        bitmap = checked(entry['bitmap16'],pixels.size*2)
        link = checked(entry['link_profile'])
        if color is None or link is None:
            raise ValueError('Missing PCS output or device link: '+pair)
        payloads += 2
        colors[pair] = p['rgb'](color,16).astype(np.int64)
        spaces = tuple('XYZ ' if name=='xyz-identity' else 'RGB ' for name in pair.split('|'))
        tables[pair] = p['read_link_tables'](link,spaces)
        row = {'color16_sha256':sha(color),'link_sha256':sha(link),
               'table_sha256':[sha(t.astype('>u2').tobytes()) for t in tables[pair]],
               'cmm_dll_version':entry['cmm_dll_version'],
               'cmm_win_version':entry['cmm_win_version']}
        if bitmap is None:
            row['bitmap_error'] = entry['bitmap16']
        else:
            bitmap_success += 1
            payloads += 1
            row['bitmap16_sha256'] = sha(bitmap)
            if spaces == ('RGB ','RGB '):
                b = p['rgb'](bitmap,16).astype(np.int64)
                row['bitmap16_raw_vs_color16'] = p['metric'](b[8:],colors[pair][8:])
                row['bitmap16_bgr_vs_color16'] = p['metric'](b[8:,::-1],colors[pair][perm])
                bitmap_comparisons += 1
        src,dst = pair.split('|')
        generated = {}
        for name,profile,table_index,curve_index in (
                ('input',src,0,0),('output',dst,2,1)):
            if profile in bridge_curves:
                predicted = bridge_curves[profile][curve_index]
                generated[name] = {**table_difference(predicted,tables[pair][table_index]),
                                   'entries':int(predicted.size),
                                   'sha256':sha(predicted.astype('>u2').tobytes())}
        if generated:
            generated_curves[pair] = generated
        results[pair] = row

    def compare_tables(a,b):
        return {name:table_difference(x,y) for name,x,y in zip(
            ('input','clut','output'),a,b)}

    def compare_paths(a,b):
        return {'color16':p['metric'](colors[a],colors[b]),
                'tables':compare_tables(tables[a],tables[b])}

    identity = 'xyz-identity|xyz-identity'
    # Test the tempting extension of the independently generated output
    # normalization to the CLUT, keeping a distinct metric for each stage.
    codes = np.arange(32,dtype=np.int64)
    q15 = (2*codes*32768+31)//62
    axis = (q15*65535+16384)//32768
    nodes = np.indices((32,32,32)).transpose(1,2,3,0)
    identity_q15 = table_difference(axis[nodes],tables[identity][1])
    separability = {name:separable_grid(tables[name][1],name=='rgb-pcs|rgb-pcs-zyx')
                    for name in (identity,'rgb-pcs|rgb-pcs','rgb-pcs|rgb-pcs-zyx',
                                 'diagonal|diagonal','diagonal|xyz-identity','xyz-identity|diagonal')}
    identity_paths = {name:compare_paths(identity,name) for name in (
        'rgb-pcs|rgb-pcs','xyz-identity|rgb-pcs','rgb-pcs|xyz-identity')}
    bridges = {}
    for name in ('linear-srgb','mixed','diagonal'):
        bridges[name+'|pcs'] = compare_paths(name+'|xyz-identity',name+'|rgb-pcs')
    for name in ('diagonal','registered-srgb','mixed','mixed-delta'):
        bridges['pcs|'+name] = compare_paths('xyz-identity|'+name,'rgb-pcs|'+name)
    f, f_rev = 'linear-srgb|rgb-pcs', 'linear-srgb|rgb-pcs-zyx'
    r, r_rev = 'rgb-pcs|registered-srgb', 'rgb-pcs-zyx|registered-srgb'
    permutation = {
        'identity_color16':p['metric'](colors['rgb-pcs|rgb-pcs-zyx'],colors[identity][:,::-1]),
        'forward_color16':p['metric'](colors[f_rev],colors[f][:,::-1]),
        'forward_clut':table_difference(tables[f_rev][1],tables[f][1][...,::-1]),
        'inverse_color16':p['metric'](colors[r_rev][8:],colors[r][perm]),
        'inverse_clut':table_difference(tables[r_rev][1],tables[r][1].transpose(2,1,0,3)),
    }
    prior = {}
    for pair in ('linear-srgb|registered-srgb','diagonal|diagonal'):
        link = checked(matrix_report['results'][pair]['link_profile'])
        prior[pair] = compare_tables(tables[pair],p['read_rgb8_tables'](link))
    # Compare the bridge's measured CLUT against the previous inferred PCS
    # lattice; a public PCS conversion is not the matrix-only internal stage.
    diagonal = e['matrix'](e['tags'](profiles['diagonal']))
    inferred = {}
    for name in ('linear-srgb','mixed','diagonal'):
        grid = tables[name+'|xyz-identity'][1]
        previous = p['read_rgb8_tables'](checked(matrix_report['results'][name+'|diagonal']['link_profile']))[1]
        old_q = np.floor(previous@diagonal.T/8+.5).astype(np.int64)
        new_q = (grid+2)//4
        mask = (previous>0)&(previous<65535)
        inferred[name] = {'unclipped_entries':int(mask.sum()),
                          **table_difference(new_q[mask],old_q[mask])}
    # For the diagonal control use only exact measured PCS inputs, not
    # interpolated values. This tests composition of the *public* transforms.
    composition = {}
    for axis in range(3):
        section = slice(32776+axis*8193,32776+(axis+1)*8193)
        forward = colors['diagonal|xyz-identity'][section]
        inverse = colors['xyz-identity|diagonal'][section]
        direct = colors['diagonal|diagonal'][section]
        other = [c for c in range(3) if c!=axis]
        if np.any(forward[:,other]) or np.any(inverse[:,other]) or np.any(direct[:,other]):
            raise ValueError('Diagonal axis control has channel leakage')
        v = forward[:,axis]
        match = (v%4==0)&(v<=32768)
        index = np.flatnonzero(match)
        indirect = inverse[v[match]//4]
        mismatch = np.flatnonzero(np.any(indirect!=direct[match],axis=1))
        witness = None
        if len(mismatch):
            j = int(mismatch[0])
            i = index[j]
            witness = {'input':pixels[section][i].tolist(),'pcs':forward[i].tolist(),
                       'composed':indirect[j].tolist(),'direct':direct[i].tolist()}
        composition[str(axis)] = {'matched_axis_inputs':len(index),
                                  **p['metric'](indirect,direct[match]),'witness':witness}
    return {'windows_build':report['windows_build'],'verified_payloads':payloads,
            'color16_success':len(colors),'bitmap16_success':bitmap_success,
            'bitmap16_rgb_comparisons':bitmap_comparisons,
            'packing_comparison_colors_per_pair':len(perm),'links':len(tables),
            'results':results,'identity_vs_ideal':p['metric'](colors[identity],pixels),
            'identity_grid_vs_ideal':table_difference(tables[identity][1].reshape(-1,3),pixels[8:32776]),
            'generated_bridge_curves':generated_curves,
            'identity_grid_q15_candidate':identity_q15,'separable_control_grids':separability,
            'identity_paths':identity_paths,'bridges':bridges,'permutation':permutation,
            'prior_control_tables':prior,'bridge_vs_inferred_pcs':inferred,
            'public_diagonal_composition':composition}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--pcs-report',type=Path,help='Also compare the isolated PCS capture')
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding='utf-8-sig'))
    result = analyze(ROOT,report,args.target)
    if args.pcs_report:
        result['pcs'] = analyze_pcs(ROOT,json.loads(args.pcs_report.read_text(encoding='utf-8-sig')),report)
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
