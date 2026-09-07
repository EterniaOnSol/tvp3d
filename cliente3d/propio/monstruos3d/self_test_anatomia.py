"""Geometry/material regressions: run with python self_test_anatomia.py."""
import hashlib
import json
import struct
import unittest


import numpy as np
from PIL import Image
from anatomia import DragonSculpt, PALETTE_FRAME
from generar import ATLAS, OUT, views_for


class DragonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = json.loads((ATLAS / 'indice.json').read_text(encoding='utf-8'))
        cls.sheets = [np.array(Image.open(ATLAS / ('lamina_%02d.png' % i)).convert('RGBA'))
                      for i in range(cls.index['laminas'])]
        cls.views = views_for(cls.index['outfits']['34'], 0, cls.sheets)

    def test_outward_smooth_normals_and_clockwise_faces(self):
        sculpt = DragonSculpt(self.views)
        center = np.array([.1,.5,-.2])
        radius = np.array([.3,.2,.4])
        sculpt.ellipsoid(center,radius)
        vertices,normals,_ = sculpt.result()
        expected = (vertices-center)/radius**2
        expected /= np.linalg.norm(expected,axis=1)[:,None]
        self.assertTrue(np.all(np.sum(normals*expected,axis=1) > .96))
        faces = vertices.reshape(-1,3,3)
        cross = np.cross(faces[:,1]-faces[:,0],faces[:,2]-faces[:,0])
        self.assertTrue(np.all(np.sum(cross*normals.reshape(-1,3,3).mean(axis=1),axis=1) < 0))

    def test_baked_meshes_palette_normals_bounds_and_hash(self):
        manifest = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        for outfit in sorted(PALETTE_FRAME):
            with self.subTest(outfit=outfit):
                entry = manifest[str(outfit)]
                blob = (OUT/entry['archivo']).read_bytes()
                self.assertEqual(hashlib.sha256(blob).hexdigest(),entry['sha256'])
                self.assertEqual(blob[:8],b'TVPVOL01')
                self.assertEqual(struct.unpack_from('<I',blob,8)[0],3)
                views = views_for(self.index['outfits'][str(outfit)],0,self.sheets)
                rgba = views[2]['rgba']
                source = set(map(tuple,rgba[rgba[:,:,3]>=128,:3].tolist()))
                offset, poses, palettes = 12, [], []
                for phase in range(3):
                    count = struct.unpack_from('<I',blob,offset)[0]
                    offset += 4
                    vertices = np.frombuffer(blob,dtype='<f4',count=count*3,offset=offset).reshape(-1,3)
                    normals = np.frombuffer(blob,dtype='<f4',count=count*3,offset=offset+count*12).reshape(-1,3)
                    colors = np.frombuffer(blob,dtype='u1',count=count*3,offset=offset+count*24).reshape(-1,3)
                    offset += count*27
                    self.assertTrue(np.isfinite(vertices).all() and np.isfinite(normals).all())
                    self.assertTrue(np.allclose(np.linalg.norm(normals,axis=1),1,atol=.002))
                    self.assertGreaterEqual(float(vertices[:,1].min()),-.0001)
                    self.assertEqual(count,entry['vertices'][phase])
                    palette = set(map(tuple,np.unique(colors,axis=0).tolist()))
                    self.assertTrue(palette <= source)
                    palettes.append(palette)
                    poses.append(vertices)
                self.assertEqual(offset,len(blob))
                self.assertEqual(palettes[0],palettes[1])
                self.assertEqual(palettes[0],palettes[2])
                self.assertFalse(np.array_equal(poses[0],poses[1]))
                all_vertices = np.concatenate(poses)
                self.assertTrue(np.allclose(all_vertices.min(axis=0),entry['min']))
                self.assertTrue(np.allclose(all_vertices.max(axis=0),entry['max']))

    def test_spider_eight_legs_alternating_contacts(self):
        from aranas import leg_joints
        for step in (0.,1.,-1.):
            legs = [leg_joints(side,pair,step) for side in (-1,1) for pair in range(4)]
            self.assertEqual(len(legs),8)
            feet = np.array([j[-1] for j in legs])
            self.assertEqual(len(np.unique(feet,axis=0)),8)
            self.assertEqual(int(np.isclose(feet[:,1],.012).sum()),8 if step==0 else 4)
            self.assertTrue(np.all(feet[:,1]>=.012))
            self.assertTrue(all(np.isfinite(j).all() for j in legs))
        for side in (-1,1):
            for pair in range(4):
                rest = leg_joints(side,pair,0)[-1]
                left = leg_joints(side,pair,1)[-1]
                right = leg_joints(side,pair,-1)[-1]
                self.assertAlmostEqual(float((left[2]+right[2])/2),float(rest[2]))

    def test_spider_sizes_and_enabled_count(self):
        manifest = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        enabled = {int(k) for k,v in manifest.items() if v.get('anatomia')}
        self.assertEqual(enabled,{21,56,34,39,30,36,38,208,219})
        small = np.array(manifest['30']['max'])-manifest['30']['min']
        giant = np.array(manifest['38']['max'])-manifest['38']['min']
        self.assertGreater(giant[0],small[0]*1.4)
        # The Old Widow reuses the same reference appearance as Giant Spider.
        self.assertTrue(np.allclose(manifest['208']['max'],manifest['38']['max']))

if __name__ == '__main__':
    unittest.main(verbosity=2)