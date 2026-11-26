#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify controlled matrix captures and isolate the inferred PCS lattice."""
import argparse
import base64
import json
from pathlib import Path
import runpy

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


def analyze(root, report, target_path):
    p = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    e = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
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
    matrices = {name:e['matrix'](e['tags'](data)) for name,data in profiles.items()}
    endpoint_regression(p['execute_rgb8_tables'])
    pixels = p['rgb'](raw,8)
    grids, table_sets, results = {}, {}, {}
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
            if entry[kind]['cmm_ident'] != '57696E20':
                raise ValueError('Unexpected native CMM')
        tables = p['read_rgb8_tables'](link)
        pred = p['execute_rgb8_tables'](*tables,pixels)
        if pred.tobytes() != direct:
            raise ValueError('Portable replay mismatch: '+pair)
        table_sets[pair] = tables
        grids[pair] = tables[1].reshape(-1,3)
        results[pair] = {'rgb8_sha256':sha(direct),'clut_sha256':sha(tables[1].astype('>u2').tobytes()),
                         'matching_rgb8_colors':len(pixels)}
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
            'portable_rgb8_colors':len(PAIRS)*len(pixels),'pairs':results,
            'v2_v4_identical_tables':equal_v2,'source_perturbation_changed_entries':forward_delta,
            'target_perturbation_changed_entries':inverse_delta,'inferred_shared_pcs':pcs,
            'inverse_from_inferred_pcs':inverse_metrics}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--target',required=True,type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(ROOT,json.loads(args.report.read_text(encoding='utf-8-sig')),args.target),indent=2))


if __name__=='__main__':
    main()
