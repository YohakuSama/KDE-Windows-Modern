#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify native precision measurements; never used by the runtime."""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TARGET = '2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E'
FORMATS = {f'{i}to{o}': o for i in (8, 16) for o in (8, 10, 16)}


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def checked(entry, size=None, limit=16*1024*1024):
    if entry['status'] != 'ok':
        if entry['status'] != 'error':
            raise ValueError('Unknown result status')
        return None
    length = entry['length']
    if type(length) is not int or not 0 < length <= limit or (size is not None and length != size):
        raise ValueError('Invalid native buffer length')
    if len(entry['base64']) != 4*((length+2)//3):
        raise ValueError('Invalid base64 length')
    data = base64.b64decode(entry['base64'], validate=True)
    if len(data) != length or sha(data) != entry['sha256']:
        raise ValueError('Native buffer hash mismatch')
    return data


def inputs():
    colors = {(i,i,i) for i in range(256)}
    for i in range(256):
        colors.update(((i,0,0),(0,i,0),(0,0,i)))
    colors.update(((20,138,20),(225,48,48),(255,0,255)))
    calibration = b''.join(map(bytes, sorted(colors)))
    mixed = bytes(v for r in range(16) for g in range(16) for b in range(16)
                  for v in (8+16*r,4+16*g,12+16*b))
    return calibration, mixed


def metric(actual, reference):
    error = np.abs(actual.astype(np.int64)-reference.astype(np.int64))
    return {'different_colors':int(error.any(axis=1).sum()), 'different_channels':int(np.count_nonzero(error)),
            'absolute_error_sum':int(error.sum()), 'max_channel_error':int(error.max())}


def rgb(data, bits):
    if bits == 8:
        return np.frombuffer(data, np.uint8).reshape(-1,3).astype(np.uint32)
    if bits == 16:
        return np.frombuffer(data, '<u2').reshape(-1,3).astype(np.uint32)
    packed = np.frombuffer(data, '<u4')
    return np.column_stack(((packed>>20)&1023,(packed>>10)&1023,packed&1023))


def partitions(actual, reference, n):
    return {'calibration':metric(actual[:n],reference[:n]), 'mixed':metric(actual[n:],reference[n:])}


def describe_link(data):
    if len(data)<132 or struct.unpack_from('>I',data)[0]!=len(data) or data[12:16]!=b'link' or data[36:40]!=b'acsp':
        raise ValueError('Invalid device-link ICC header')
    count=struct.unpack_from('>I',data,128)[0]
    end=132+12*count
    if end>len(data):
        raise ValueError('Invalid device-link tag count')
    result={'sha256':sha(data),'length':len(data),'version_hex':data[8:12].hex(),
            'input_space':data[16:20].decode('ascii'),'output_space':data[20:24].decode('ascii'),'tags':[]}
    for i in range(count):
        sig,off,size=struct.unpack_from('>4sII',data,132+12*i)
        if off<end or size<8 or off+size>len(data):
            raise ValueError('Invalid device-link tag range')
        typ=data[off:off+4]
        item={'signature':sig.decode('ascii'),'type':typ.decode('ascii'),'size':size}
        if typ in (b'mft1',b'mft2') and size>=12:
            item.update(input_channels=data[off+8],output_channels=data[off+9],grid_points=data[off+10])
        result['tags'].append(item)
    return result


def read_rgb8_tables(data):
    """Read the validated measured RGB8 mft2 tables."""
    description = describe_link(data)
    if (description['input_space'], description['output_space']) != ('RGB ', 'RGB '):
        raise ValueError('Expected RGB-to-RGB device link')
    count = len(description['tags'])
    matches = [(off, size) for sig, off, size in
               (struct.unpack_from('>4sII', data, 132+12*i) for i in range(count))
               if sig == b'A2B0']
    if len(matches) != 1:
        raise ValueError('Expected one A2B0 tag')
    off, size = matches[0]
    tag = data[off:off+size]
    if len(tag) < 52 or tag[:4] != b'mft2' or tag[8:11] != bytes((3,3,32)):
        raise ValueError('Unexpected mft2 dimensions')
    if struct.unpack_from('>9i', tag, 12) != (65536,0,0,0,65536,0,0,0,65536):
        raise ValueError('Expected identity matrix')
    ni, no = struct.unpack_from('>HH', tag, 48)
    if (ni,no) != (256,1024) or len(tag) != 52+6*ni+6*32**3+6*no:
        raise ValueError('Unexpected mft2 table length')
    source = np.frombuffer(tag[52:52+6*ni], '>u2').reshape(3,ni).astype(np.int64)
    grid = np.frombuffer(tag[52+6*ni:-6*no], '>u2').reshape(32,32,32,3).astype(np.int64)
    target = np.frombuffer(tag[-6*no:], '>u2').reshape(3,no).astype(np.int64)
    return source, grid, target


def execute_rgb8_tables(source, grid, target, pixels):
    """Run the verified fixed-point RGB8 lookup on validated or generated tables."""
    for table, shape in ((source, (3,256)), (grid, (32,32,32,3)), (target, (3,1024))):
        if table.shape != shape or table.dtype.kind not in "ui" or np.any(table<0) or np.any(table>65535):
            raise ValueError("Invalid RGB8 table")
    source, grid, target = (table.astype(np.int64, copy=False) for table in (source, grid, target))
    if pixels.ndim != 2 or pixels.shape[1] != 3 or np.any(pixels<0) or np.any(pixels>255):
        raise ValueError('Expected RGB8 pixels')
    # 16-bit curve samples -> 5-bit grid coordinate and 11-bit fraction.
    values = source[np.arange(3),pixels.astype(np.int64)]
    p = (values*31)>>5
    cell, frac = p>>11, p&2047
    # The maximum 16-bit code selects the exact final vertex, not 2047/2048.
    frac = np.where(values == 65535, 2048, frac)
    order = np.argsort(-frac, axis=1)
    fractions = np.take_along_axis(frac, order, axis=1)
    q = cell.copy()
    rows = np.arange(len(q))
    prev = grid[q[:,0],q[:,1],q[:,2]]
    numerator = prev*2048
    for j in range(3):
        q[rows,order[:,j]] += 1
        node = grid[q[:,0],q[:,1],q[:,2]]
        numerator += (node-prev)*fractions[:,j,None]
        prev = node
    # Accumulate without intermediate rounding. Drop 11 fraction bits and
    # six low CLUT-output bits together, then take the curve's high byte.
    idx = (numerator>>17).clip(0,1023)
    pred = (target[np.arange(3),idx]>>8).astype(np.uint8)
    return pred


def replay_rgb8(data, pixels):
    """Execute the measured RGB8 mft2 device-link path; not a LUT generator."""
    source, grid, target = read_rgb8_tables(data)
    pred = execute_rgb8_tables(source, grid, target, pixels)
    return pred, {'input_curve_sha256':sha(source.astype('>u2').tobytes()),
                  'clut_sha256':sha(grid.astype('>u2').tobytes()),
                  'output_curve_sha256':sha(target.astype('>u2').tobytes())}


def measure(entry, count, reference, n):
    if set(entry['outputs'])!=set(FORMATS):
        raise ValueError('Missing or unexpected native output formats')
    result={k:entry[k] for k in ('cmm_ident','cmm_dll_version','cmm_win_version')}
    buffers={}
    failures={}
    for key,bits in FORMATS.items():
        item=entry['outputs'][key]
        data=checked(item,count*{8:3,10:4,16:6}[bits])
        if data is None:
            failures[key]=item
        else:
            buffers[key]=rgb(data,bits)
    result['failures']=failures
    result['rgb8_vs_wic']={k:partitions(v,reference,n) for k,v in buffers.items() if k=='8to8'}
    result['packing_note']='16-bit raw channel order is unresolved on this capture; no cross-depth precision inference from 16-bit input/output.'
    result['downconversion']={}
    # Compare high-bit outputs against 8-bit output from the same input format.
    # These are diagnostic comparisons, not a claim that the paths share precision.
    for key,bits in FORMATS.items():
        baseline=key.split('to')[0]+'to8'
        if key!='8to10' or key not in buffers or baseline not in buffers:
            continue
        x=buffers[key]; y=buffers[baseline]; maxval=(1<<bits)-1
        reduced={'shift':x>>(bits-8),'round255':(x*255+maxval//2)//maxval,
                 'floor255':x*255//maxval,'floor256':np.minimum(255,x*256//maxval)}
        result['downconversion'][key]={rule:partitions(v,y,n) for rule,v in reduced.items()}
    return result,buffers


def analyze(report, evidence):
    calibration,mixed=inputs(); n=len(calibration)//3; count=n+len(mixed)//3
    if (report['schema_version'],report['windows_build'],report['calibration_count'],report['mixed_count'],report['flags'])!=(1,'26300.9974',n,len(mixed)//3,3):
        raise ValueError('Unexpected native measurement identity')
    if report['target_sha256']!=TARGET or evidence['target']['sha256']!=TARGET:
        raise ValueError('Wrong destination profile')
    if (sha(calibration)!=report['calibration_sha256'] or sha(calibration)!=evidence['input_rgb_sha256']
            or checked(report['input_rgb'],count*3)!=calibration+mixed):
        raise ValueError('Wrong measurement input')
    expected={s['source']:s for s in evidence['samples']}
    if report['sources']!={k:v['source_icc_sha256'] for k,v in expected.items()} or set(report['results'])!=set(expected):
        raise ValueError('Wrong input profile set')
    results={}
    for source,item in report['results'].items():
        prior=gzip.decompress(base64.b64decode(expected[source]['output_rgb_gzip_base64'],validate=True))
        if len(prior)!=n*3 or sha(prior)!=expected[source]['output_rgb_sha256']:
            raise ValueError('Old evidence failed hash check')
        wic=checked(item['wic'],count*3)
        if wic is None or wic[:n*3]!=prior:
            raise ValueError('WIC baseline did not reproduce prior measurement: '+source)
        reference=rgb(wic,8)
        if set(item['intents'])!={'0','1','2'}:
            raise ValueError('Wrong intent set')
        results[source]={}
        for intent,entry in item['intents'].items():
            if entry['status']=='error':
                results[source][intent]=entry; continue
            if entry['status']!='ok':
                raise ValueError('Unknown transform status')
            result,direct=measure(entry['direct'],count,reference,n)
            link=checked(entry['link_profile'])
            result['device_link']=entry['link_profile'] if link is None else describe_link(link)
            if link is not None:
                prediction, tables = replay_rgb8(link, rgb(calibration+mixed,8))
                result['portable_rgb8'] = {**tables, 'output_sha256':sha(prediction.tobytes()),
                                           'vs_wic':partitions(prediction,reference,n)}
                if '8to8' in direct:
                    result['portable_rgb8']['vs_direct']=partitions(prediction,direct['8to8'],n)
                replay=entry['link_replay']
                if replay.get('status')=='error':
                    result['link_replay']=replay
                else:
                    m,buffers=measure(replay,count,reference,n)
                    m['vs_direct']={k:partitions(v,direct[k],n) for k,v in buffers.items() if k in direct}
                    result['link_replay']=m
            results[source][intent]=result
    return {'windows_build':report['windows_build'],'target_sha256':TARGET,'calibration_count':n,
            'mixed_count':count-n,'results':results}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('--evidence',type=Path,default=ROOT/'docs/windows11-26h2-icc-native-matches.json')
    args=parser.parse_args()
    print(json.dumps(analyze(json.loads(args.report.read_text(encoding='utf-8-sig')),
                             json.loads(args.evidence.read_text())),indent=2))


if __name__=='__main__':
    main()
