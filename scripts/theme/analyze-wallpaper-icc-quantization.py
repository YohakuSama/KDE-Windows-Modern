#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Test matrix-stage separability and quantify periodic PCS residuals offline."""
import argparse
import base64
from fractions import Fraction
import json
from pathlib import Path
import runpy

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ('diagonal', 'linear-srgb', 'mixed', 'mixed-delta')


def scalar_maps(grids, diagonal):
    maps = [dict() for _ in range(3)]
    for name in SOURCES:
        grid = grids[name+'|diagonal']
        pcs = np.floor(grid @ diagonal.T / 8 + .5).astype(np.int64)
        for channel, values in enumerate(maps):
            q = pcs[...,channel].ravel()
            raw = grid[...,channel].ravel()
            mask = (raw>0)&(raw<65535)
            for x, y in zip(q[mask], raw[mask]):
                x, y = int(x), int(y)
                if values.setdefault(x,y)!=y:
                    raise ValueError('Inferred PCS does not identify a unique diagonal output')
    return maps


def slope_bounds(values):
    # For a single affine map followed by any quantizer whose residual
    # lies in an interval of width one, (dy-1)/dx <= slope <= (dy+1)/dx.
    # A strict contradiction excludes the entire class, including ties.
    x = np.array(sorted(values), dtype=np.int64)
    y = np.array([values[i] for i in x], dtype=np.int64)
    lower, upper = None, None
    lags = (1,2,3,4,5,6,7,8,16,32,64,128,256,512,1024,2048,4096,len(x)-1)
    for lag in sorted(set(lags)):
        if not 0<lag<len(x):
            continue
        dx, dy = x[lag:]-x[:-lag], y[lag:]-y[:-lag]
        a, b = (dy-1)/dx, (dy+1)/dx
        i, j = int(a.argmax()), int(b.argmin())
        lo, hi = Fraction(int(dy[i])-1,int(dx[i])), Fraction(int(dy[j])+1,int(dx[j]))
        if lower is None or lo>lower[0]:
            lower = (lo,[int(x[i]),int(y[i]),int(x[i+lag]),int(y[i+lag])])
        if upper is None or hi<upper[0]:
            upper = (hi,[int(x[j]),int(y[j]),int(x[j+lag]),int(y[j+lag])])
    if lower is None or upper is None:
        raise ValueError('Insufficient unclipped observations')
    return {'unique_pcs_codes':len(x), 'lower_slope':str(lower[0]), 'upper_slope':str(upper[0]),
            'lower_witness':lower[1], 'upper_witness':upper[1], 'incompatible':lower[0]>upper[0]}


def periodic_residual(values):
    # The diagonal green colorant is exactly one, so its nominal output is 8*q.
    residual = {x:y-8*x for x,y in values.items()}
    result = {'range':[min(residual.values()),max(residual.values())], 'lags':{}}
    for lag in (16,32,64,128,256,512):
        delta = [residual[x+lag]-r for x,r in residual.items() if x+lag in residual]
        result['lags'][str(lag)] = {'pairs':len(delta), 'equal':delta.count(0),
                                    'increase':sum(v>0 for v in delta),'decrease':sum(v<0 for v in delta)}
    return result


def inverse_order_constraints(grids, diagonal, matrices):
    """Reject monotone scalar postprocessing of particular inverse matrices.

    Within each target and output channel, a larger observed output must
    have a strictly larger projected scalar for any deterministic monotone
    mapping. Compute projection keys exactly from ICC 16.16 colorants.
    The PCS codes are still inferred, not a directly captured buffer.
    """
    observations = {}
    for pair, grid in grids.items():
        source, target = pair.split('|')
        control = grids.get(source+'|diagonal')
        if control is None:
            continue
        a = control.reshape(-1,3)
        mask = ((a>0)&(a<65535)).all(axis=1)
        q = np.floor(a[mask] @ diagonal.T / 8 + .5).astype(np.int64)
        observations.setdefault(target,[]).append((q,grid.reshape(-1,3)[mask]))
    result = {}
    for target, pairs in observations.items():
        q = np.concatenate([a for a,_ in pairs])
        observed = np.concatenate([b for _,b in pairs])
        # Hash-checked probe profiles have small positive 16.16 colorants.
        # Their adjugate products and PCS dot products fit int64. Use Python
        # integers for the Q16 rounding numerator, which may exceed int64.
        a = (matrices[target]*65536).astype(np.int64)
        adj = np.array([np.cross(a[:,1],a[:,2]),np.cross(a[:,2],a[:,0]),np.cross(a[:,0],a[:,1])])
        det = int(a[:,0] @ adj[0])
        if det <= 0:
            raise ValueError('Expected positive-determinant probe matrix')
        q16 = np.array([[(2*int(v)*65536**2+det)//(2*det) for v in row] for row in adj],dtype=np.int64)
        models = {}
        for name, coeff in (('exact_inverse',adj),('nearest_q16_inverse',q16)):
            channels = []
            for c in range(3):
                mask = (observed[:,c]>0)&(observed[:,c]<65535)
                y = observed[mask,c]
                x = q[mask] @ coeff[c]
                order = np.argsort(x)
                x,y = x[order],y[order]
                starts = np.r_[0,np.flatnonzero(np.diff(x))+1]
                lo = np.minimum.reduceat(y,starts)
                hi = np.maximum.reduceat(y,starts)
                collisions = np.flatnonzero(lo!=hi)
                reversals = np.flatnonzero(hi[:-1]>lo[1:])
                witness = None
                if len(reversals):
                    i = int(reversals[0])
                    witness = [[int(x[starts[i]]),int(hi[i])],
                               [int(x[starts[i+1]]),int(lo[i+1])]]
                channels.append({'distinct_projection_keys':len(starts),
                                 'conflicting_equal_keys':len(collisions),
                                 'reversed_adjacent_keys':len(reversals),
                                 'reversal_witness':witness})
            models[name] = channels
        result[target] = models
    return result


def rectangle_witness(grid, diagonal):
    # If the inferred coordinate is floor(a_i+b_j+c_k+constant),
    # every unclipped rectangle has alternating sum in {-1,0,1}.
    # This also applies to ceil and round-half-up. It does not exclude
    # non-uniform quantizers or rounding at intermediate stages.
    pcs = np.floor(grid @ diagonal.T / 8 + .5).astype(np.int64)
    out = []
    for c in range(3):
        witness = None
        count = 0
        for a,b in ((0,1),(0,2),(1,2)):
            q = np.moveaxis(pcs[...,c],(a,b),(0,1))
            valid = np.moveaxis((grid[...,c]>0)&(grid[...,c]<65535),(a,b),(0,1))
            delta = q[1:,1:]-q[:-1,1:]-q[1:,:-1]+q[:-1,:-1]
            mask = valid[1:,1:]&valid[:-1,1:]&valid[1:,:-1]&valid[:-1,:-1]
            hits = np.argwhere(mask&(np.abs(delta)>1))
            count += len(hits)
            if witness is None and len(hits):
                i,j,k = map(int,hits[0])
                witness = {'axes':[a,b], 'index':[i,j,k], 'pcs':q[i:i+2,j:j+2,k].tolist(),
                           'alternating_sum':int(delta[i,j,k])}
        out.append({'channel':c, 'violating_adjacent_rectangles':count,'witness':witness})
    return out


def analyze(root, report, target_path):
    capture = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-matrix-capture.py'))
    verified = capture['analyze'](root,report,target_path)
    p = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-precision.py'))
    e = runpy.run_path(str(root/'scripts/theme/analyze-wallpaper-icc-engine.py'))
    data = base64.b64decode(report['matrix_profiles']['diagonal']['base64'],validate=True)
    diagonal = e['matrix'](e['tags'](data))
    if np.any(diagonal != np.diag(np.diag(diagonal))) or diagonal[1,1]!=1:
        raise ValueError('Expected the measured diagonal control')
    grids = {name:p['read_rgb8_tables'](p['checked'](item['link_profile']))[1]
             for name,item in report['results'].items()}
    values = scalar_maps(grids,diagonal)
    matrices = {'registered-srgb':e['matrix'](e['tags'](target_path.read_bytes()))}
    for name in ('diagonal','mixed','mixed-delta'):
        data = base64.b64decode(report['matrix_profiles'][name]['base64'],validate=True)
        matrices[name] = e['matrix'](e['tags'](data))
    return {'windows_build':verified['windows_build'],'verified_payloads':verified['verified_payloads'],
            'portable_rgb8_colors':verified['portable_rgb8_colors'],
            'inverse_scalar_bounds':[slope_bounds(v) for v in values],
            'identity_green_residual':periodic_residual(values[1]),
            'inverse_order_constraints':inverse_order_constraints(grids,diagonal,matrices),
            'forward_rectangles':{name:rectangle_witness(grids[name+'|diagonal'],diagonal)
                                  for name in ('linear-srgb','mixed')}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--target',required=True,type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding='utf-8-sig'))
    print(json.dumps(analyze(ROOT,report,args.target),indent=2))


if __name__=='__main__':
    main()
