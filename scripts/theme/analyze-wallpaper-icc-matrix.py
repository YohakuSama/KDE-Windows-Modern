#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Investigate the native CLUT construction; no runtime approximation."""
import argparse
import itertools
import json
from pathlib import Path
import runpy

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ROUND = {'floor': np.floor, 'nearest': lambda x: np.floor(x + .5), 'ceil': np.ceil}


def quantize(values, scale, mode):
    return ROUND[mode](values * scale) / scale if scale else values


def stage_options(scales):
    return [(0, 'nearest')] + list(itertools.product(scales, ROUND))


def analyze(root, report, target_path):
    p = runpy.run_path(str(root / 'scripts/theme/analyze-wallpaper-icc-precision.py'))
    e = runpy.run_path(str(root / 'scripts/theme/analyze-wallpaper-icc-engine.py'))
    gen = runpy.run_path(str(root / 'scripts/theme/analyze-wallpaper-icc-generation.py'))
    evidence = json.loads((root / 'docs/windows11-26h2-icc-native-matches.json').read_text())
    verification = p['analyze'](report, evidence)
    target, _, sources, _ = e['inputs'](root, target_path)
    tags, matrix, sha = (e[k] for k in ('tags', 'matrix', 'sha'))
    destination = tags(target)
    target_matrix = matrix(destination)
    inverse = np.linalg.inv(target_matrix)
    source_matrix = matrix(tags(sources['srgb']))
    if any(not np.array_equal(matrix(tags(v)), source_matrix) for v in sources.values()):
        raise ValueError('This experiment requires identical source colorants')
    native = None
    references = {}
    for name, data in sources.items():
        item = report['results'][name]
        links = [p['read_rgb8_tables'](p['checked'](item['intents'][i]['link_profile'])) for i in ('0', '1', '2')]
        source_curve = gen['input_curves'](tags(data), e['decode'])
        output_curve = gen['output_curves'](destination)
        for intent, (s, grid, t) in zip(('0', '1', '2'), links):
            if not np.array_equal(s, source_curve) or not np.array_equal(t, output_curve):
                raise ValueError('Independent curves do not match the native reference')
            if any(v['max_channel_error'] for v in verification['results'][name][intent]['portable_rgb8']['vs_wic'].values()):
                raise ValueError('Native replay mismatch')
            if native is None:
                native = grid
            elif not np.array_equal(native, grid):
                raise ValueError('Native CLUT not shared')
        references[name] = (source_curve, output_curve, p['rgb'](p['checked'](item['wic']), 8))
    nodes = np.indices((32, 32, 32)).reshape(3, -1).T
    ref = native.reshape(-1, 3)
    mask = ((nodes > 0) & (nodes < 31)).all(axis=1)
    if not ((ref[mask] > 0) & (ref[mask] < 65535)).all():
        raise ValueError('Unexpected clipped interior nodes')
    # A measured lattice in the reconstructed PCS, not an observed native PCS buffer.
    projected = ref[mask] @ target_matrix.T / 8
    inferred = np.floor(projected + .5).astype(np.int64)
    residual = projected - inferred
    if np.max(np.abs(residual)) >= .5:
        raise ValueError('Ambiguous nearest lattice index')
    grid = nodes / 31
    candidates = []
    for gs, (ms, mr), xr, (ds, dr), scale, out in itertools.product(
            (0, 16384), stage_options((16384, 65536)), ROUND,
            stage_options((65536,)), (65535, 65536), ('floor', 'nearest')):
        xyz = quantize(quantize(grid, gs, 'nearest') @ quantize(source_matrix, ms, mr).T, 8192, xr)
        dst = quantize(inverse, ds, dr)
        prediction = ROUND[out](xyz @ dst.T * scale).clip(0, 65535).astype(np.int64)
        error = np.abs(prediction - ref)
        key = (gs, ms, mr, xr, ds, dr, scale, out)
        candidates.append((int(error.sum()), int(np.count_nonzero(error)), int(error.max()), key))
    candidates.sort()
    pixels = p['rgb'](p['checked'](report['input_rgb']), 8)
    n = report['calibration_count']

    def evaluate(key):
        gs, ms, mr, xr, ds, dr, scale, out = key
        xyz = quantize(quantize(grid, gs, 'nearest') @ quantize(source_matrix, ms, mr).T, 8192, xr)
        dst = quantize(inverse, ds, dr)
        generated = ROUND[out](xyz @ dst.T * scale).clip(0, 65535).astype(np.int64)
        # Separate the hypotheses: forward against inferred PCS, inverse with
        # the inferred PCS supplied directly. Neither is native PCS evidence.
        forward = np.abs(np.rint(xyz[mask] * 8192).astype(np.int64) - inferred)
        back = ROUND[out]((inferred / 8192) @ dst.T * scale).clip(0, 65535).astype(np.int64)
        back_error = np.abs(back - ref[mask])
        rgb8 = {}
        for name, (s, t, r) in references.items():
            pred = p['execute_rgb8_tables'](s, generated.reshape(32, 32, 32, 3), t, pixels)
            rgb8[name] = p['partitions'](pred, r, n)
        return {'parameters': dict(zip(('grid_scale', 'source_matrix_scale', 'source_matrix_round', 'xyz_round',
                                         'inverse_matrix_scale', 'inverse_matrix_round', 'output_scale', 'output_round'), key)),
                'table': gen['table_metrics'](generated, ref, sha),
                'forward_vs_inferred_pcs': {'different_entries': int(np.count_nonzero(forward)),
                                            'absolute_error_sum': int(forward.sum()), 'max_error': int(forward.max())},
                'inverse_from_inferred_pcs': {'different_entries': int(np.count_nonzero(back_error)),
                                              'absolute_error_sum': int(back_error.sum()), 'max_error': int(back_error.max())},
                'fully_generated_rgb8': rgb8}

    previous = (0, 16384, 'nearest', 'nearest', 65536, 'nearest', 65535, 'floor')
    return {'target_sha256': sha(target), 'interior_nodes': int(mask.sum()), 'pcs_lattice_scale': 8192,
            'projected_residual_min': residual.min(axis=0).tolist(), 'projected_residual_max': residual.max(axis=0).tolist(),
            'candidate_count': len(candidates), 'exact_candidates': sum(x[0] == 0 for x in candidates),
            'previous': evaluate(previous), 'best_table_candidate': evaluate(candidates[0][-1])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--target', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(ROOT, json.loads(args.report.read_text(encoding='utf-8-sig')), args.target), indent=2))


if __name__ == '__main__':
    main()
