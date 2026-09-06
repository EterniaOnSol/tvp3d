"""Bake four original Tibia views into colored solid meshes (no sprite edits).

Run from any directory: python generar.py [--ids 21 34] [--output PATH].
Requires numpy, scipy and Pillow. Runtime has no Python dependency.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

import numpy as np
from PIL import Image
from scipy import ndimage
from anatomia import AUTHORED

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / 'assets' / 'sprites772'
OUT = Path(__file__).resolve().parent / 'mallas'
ELEVATION = math.radians(55)
SIN, COS = math.sin(ELEVATION), math.cos(ELEVATION)
# N/E/S/W: horizontal screen-right and camera-facing world axes (Y is up).
RIGHT = np.array([[-1, 0, 0], [0, 0, 1], [1, 0, 0], [0, 0, -1]])
FRONT = np.array([[0, 0, -1], [1, 0, 0], [0, 0, 1], [-1, 0, 0]])


def views_for(outfit, phase, sheets):
    views = []
    for frames in outfit['c'][:4]:
        r = frames[phase % len(frames)]
        a = sheets[r['l']][r['y']:r['y']+r['h'], r['x']:r['x']+r['w']].copy()
        mask = a[:, :, 3] >= 128
        yy, xx = np.where(mask)
        if not len(xx):
            raise ValueError('Empty directional sprite')
        bounds = [int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())]
        # Nearest opaque pixels extend only surface colors, never silhouettes.
        _, nearest = ndimage.distance_transform_edt(~mask, return_indices=True)
        views.append(dict(rgba=a, mask=mask, bounds=bounds,
                          center=np.array([(xx.min()+xx.max())/2, (yy.min()+yy.max())/2]),
                          dilated=ndimage.binary_dilation(mask, iterations=1),
                          colors=a[nearest[0], nearest[1], :3]))
    return views


def projection(points, view, direction):
    u = points @ RIGHT[direction] + view['center'][0]
    v = -points[:, 1] * COS + (points @ FRONT[direction]) * SIN + view['center'][1]
    u = np.rint(u).astype(int)
    v = np.rint(v).astype(int)
    h, w = view['mask'].shape
    valid = (u >= 0) & (v >= 0) & (u < w) & (v < h)
    return np.clip(u, 0, w-1), np.clip(v, 0, h-1), valid


def reconstruct(views, extent):
    width, height, depth = extent
    shape = np.ceil([width, height, depth]).astype(int) + 4
    centers = (np.indices(shape).reshape(3, -1).T - (shape-1)/2).astype(float)
    exact = np.zeros(len(centers), dtype=np.uint8)
    padded = np.zeros_like(exact)
    for d, view in enumerate(views):
        u, v, valid = projection(centers, view, d)
        exact += view['mask'][v, u] & valid
        padded += view['dilated'][v, u] & valid
    solid = ((exact >= 3) & (padded == 4)).reshape(shape)
    solid = ndimage.binary_fill_holes(solid)
    if solid.sum() < 8:
        raise ValueError('Insufficient common silhouette volume')
    # Cull isolated single-pixel debris, retaining thin limbs and tails.
    labels, _ = ndimage.label(solid)
    counts = np.bincount(labels.ravel())
    solid &= counts[labels] >= 3
    vertices, normals, colors = [], [], []
    corners = {
        (0, 1): [[.5,-.5,-.5],[.5,.5,-.5],[.5,.5,.5],[.5,-.5,.5]],
        (0,-1): [[-.5,-.5,.5],[-.5,.5,.5],[-.5,.5,-.5],[-.5,-.5,-.5]],
        (1, 1): [[-.5,.5,.5],[.5,.5,.5],[.5,.5,-.5],[-.5,.5,-.5]],
        (1,-1): [[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5]],
        (2, 1): [[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5],[-.5,-.5,.5]],
        (2,-1): [[-.5,-.5,-.5],[-.5,.5,-.5],[.5,.5,-.5],[.5,-.5,-.5]],
    }
    for (axis, sign), quad in corners.items():
        neighbor = np.roll(solid, -sign, axis=axis)
        boundary = [slice(None)] * 3
        boundary[axis] = -1 if sign > 0 else 0
        neighbor[tuple(boundary)] = False
        cells = np.argwhere(solid & ~neighbor)
        points = cells - (shape-1)/2
        normal = np.zeros(3)
        normal[axis] = sign
        face_centers = points + normal * .5
        # Front, back and both sides sample their own original sprite.
        scores, samples = [], []
        for d, view in enumerate(views):
            u, v, valid = projection(face_centers, view, d)
            camera = FRONT[d] * COS + np.array([0, SIN, 0])
            score = np.full(len(points), normal @ camera * 4)
            score += view['mask'][v, u] * 2 + valid
            scores.append(score)
            samples.append(view['colors'][v, u])
        best = np.argmax(np.array(scores), axis=0)
        rgb = np.array(samples)[best, np.arange(len(points))]
        # Original RGB bytes, with no invented palette or color quantization.
        triangles = (points[:, None, :] + np.array(quad)[[0,1,2,0,2,3]]).reshape(-1,3)
        vertices.append(triangles)
        normals.append(np.tile(normal, (len(triangles),1)))
        colors.append(np.repeat(rgb, 6, axis=0))
    return (np.concatenate(vertices).astype('<f4'),
            np.concatenate(normals).astype('<f4'), np.concatenate(colors).astype('u1'))


def save_mesh(path, frames):
    # Small versioned binary: header, then position/normal float32 and RGB8.
    # Godot reads this directly; it needs neither importer nor Python at runtime.
    temporary = path.with_suffix('.tmp')
    with temporary.open('wb') as f:
        f.write(b'TVPVOL01')
        f.write(struct.pack('<I', len(frames)))
        for vertices, normals, colors in frames:
            f.write(struct.pack('<I', len(vertices)))
            f.write(vertices.tobytes())
            f.write(normals.tobytes())
            f.write(colors.tobytes())
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ids', nargs='+', type=int)
    parser.add_argument('--output', type=Path, default=OUT)
    args = parser.parse_args()
    index = json.loads((ATLAS / 'indice.json').read_text(encoding='utf-8'))
    catalog = json.loads((ROOT / 'assets' / 'monster_names772.json').read_text(encoding='utf-8'))
    sheets = [np.array(Image.open(ATLAS / ('lamina_%02d.png' % i)).convert('RGBA'))
              for i in range(index['laminas'])]
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / 'catalogo.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'version':1, 'monstruos':{}}
    ids = args.ids or sorted(map(int, catalog))
    failures = []
    for oid in ids:
        if str(oid) not in index['outfits']:
            failures.append([oid, 'No outfit in original atlas'])
            continue
        outfit = index['outfits'][str(oid)]
        try:
            views = [views_for(outfit, p, sheets) for p in range(len(outfit['c'][0]))]
            widths = np.array([[v['bounds'][2]-v['bounds'][0]+1 for v in phase] for phase in views])
            heights = np.array([[v['bounds'][3]-v['bounds'][1]+1 for v in phase] for phase in views])
            width = float(widths[:, [0,2]].max())
            depth = float(widths[:, [1,3]].max())
            inferred = (heights.max(axis=0) - np.array([depth,width,depth,width])*SIN)/COS
            height = max(6., float(inferred.max()), heights.max()*.28)
            frames = ([AUTHORED[oid](v, p) for p, v in enumerate(views)] if oid in AUTHORED
                      else [reconstruct(v, (width,height,depth)) for v in views])
            # One shared transform for ALL animation frames, so feet do not jump.
            bottom = min(float(f[0][:,1].min()) for f in frames)
            pixel_scale = 1.0 if oid in AUTHORED else .90 / 32
            for vertices, _, _ in frames:
                vertices[:,1] -= bottom
                vertices *= pixel_scale
            path = args.output / ('outfit_%04d.tvol' % oid)
            save_mesh(path, frames)
            all_positions = np.concatenate([f[0] for f in frames])
            manifest['monstruos'][str(oid)] = {
                'nombre': catalog.get(str(oid), str(oid)), 'archivo':path.name,
                'anatomia': oid in AUTHORED,
                'fases':len(frames), 'vertices':[len(f[0]) for f in frames],
                'min':all_positions.min(axis=0).tolist(), 'max':all_positions.max(axis=0).tolist(),
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            }
            print('%d %s: %d phases, %d triangles' % (oid, catalog.get(str(oid), ''), len(frames), sum(len(f[0])//3 for f in frames)), flush=True)
        except (ValueError, KeyError, IndexError) as error:
            failures.append([oid, str(error)])
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print('Failures:', failures)
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
