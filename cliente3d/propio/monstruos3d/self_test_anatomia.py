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
                phases = len(self.index['outfits'][str(outfit)]['c'][2])
                self.assertEqual(struct.unpack_from('<I',blob,8)[0],phases)
                views = views_for(self.index['outfits'][str(outfit)],0,self.sheets)
                rgba = views[2]['rgba']
                source = set(map(tuple,rgba[rgba[:,:,3]>=128,:3].tolist()))
                offset, poses, palettes = 12, [], []
                for phase in range(phases):
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
                self.assertTrue(all(p == palettes[0] for p in palettes))
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
        self.assertEqual(enabled,{21,56,34,39,30,36,38,208,219,27,52,3,16,42,123,28,81,26,82,83,79,43,45,124,13,14,60,31,74,32,94})
        small = np.array(manifest['30']['max'])-manifest['30']['min']
        giant = np.array(manifest['38']['max'])-manifest['38']['min']
        self.assertGreater(giant[0],small[0]*1.4)
        # The Old Widow reuses the same reference appearance as Giant Spider.
        self.assertTrue(np.allclose(manifest['208']['max'],manifest['38']['max']))
    def test_wolf_diagonal_support_and_relative_size(self):
        from lobos import leg_joints
        for step in (0.,1.,-1.):
            contacts = []
            for side in (-1,1):
                for front in (True,False):
                    joints = leg_joints(side,front,step)
                    self.assertTrue(np.isfinite(joints).all())
                    self.assertGreaterEqual(joints[-1,1],.024)
                    if np.isclose(joints[-1,1],.024):
                        contacts.append((side,front))
            self.assertEqual(len(contacts),4 if step==0 else 2)
            if step:
                self.assertNotEqual(contacts[0][0],contacts[1][0])
                self.assertNotEqual(contacts[0][1],contacts[1][1])
        manifest = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        normal = np.array(manifest['27']['max'])-manifest['27']['min']
        war = np.array(manifest['3']['max'])-manifest['3']['min']
        self.assertGreater(war[0],normal[0])
        self.assertGreater(war[2],normal[2])
    def test_bear_contacts_and_panda_markings(self):
        from osos import leg_joints, make_generators, PROFILES
        for step in (0.,1.,-1.):
            feet = np.array([leg_joints(side,front,step)[-1] for side in (-1,1) for front in (True,False)])
            self.assertEqual(len(np.unique(feet,axis=0)),4)
            self.assertEqual(np.isclose(feet[:,1],.026).sum(),4 if step==0 else 2)
            self.assertTrue(np.all(feet[:,1]>=.026))
        # Check the visible saddle against the generated panda surface.
        entry = json.loads((OUT/'catalogo.json').read_text())['monstruos']['123']
        blob = (OUT/entry['archivo']).read_bytes()
        count = struct.unpack_from('<I',blob,12)[0]
        xyz = np.frombuffer(blob,dtype='<f4',count=count*3,offset=16).reshape(-1,3)
        rgb = np.frombuffer(blob,dtype='u1',count=count*3,offset=16+count*24).reshape(-1,3)
        views = views_for(self.index['outfits']['123'],0,self.sheets)
        scale = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)/32*.90/(1.10+PROFILES[123]['neck'])
        scale *= entry['escala']['factor']
        shoulder = (xyz[:,2]>.10*scale)&(xyz[:,2]<.19*scale)&(xyz[:,1]>.5*scale)
        rump = (xyz[:,2]<-.1*scale)&(xyz[:,1]>.5*scale)
        self.assertTrue(shoulder.any() and rump.any())
        self.assertLess(float(rgb[shoulder].mean()),float(rgb[rump].mean())*.5)
    def test_snake_wave_endpoints_and_low_profile(self):
        from serpientes import centerline
        for hood in (False,True):
            rest,radii = centerline(0,hood)
            for phase in (1,2):
                points,other_radii = centerline(phase,hood)
                self.assertTrue(np.isfinite(points).all())
                self.assertTrue(np.allclose(points[[0,-1]],rest[[0,-1]]))
                self.assertTrue(np.array_equal(radii,other_radii))
                self.assertFalse(np.allclose(points,rest))
                self.assertTrue(np.all(points[:,1]-other_radii>=.0079))
        entries = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        snake = np.array(entries['28']['max'])-entries['28']['min']
        cobra = np.array(entries['81']['max'])-entries['81']['min']
        self.assertLess(snake[1],snake[2]*.12)
        self.assertGreater(cobra[1],snake[1]*3)

    def test_crawler_contacts_mouth_cycle_and_sizes(self):
        from reptadores import leg_joints, mouth_opening
        aperture = [mouth_opening(p) for p in range(6)]
        self.assertTrue(all(aperture[p] > aperture[p+1] for p in range(3)))
        self.assertEqual(aperture[1],aperture[5])
        self.assertEqual(aperture[2],aperture[4])
        for larva in (False,True):
            ground = .010 if larva else .009
            for step in (0.,1.,-1.):
                feet = np.array([leg_joints(side,pair,step,larva)[-1]
                                 for side in (-1,1) for pair in range(3)])
                self.assertEqual(len(np.unique(feet,axis=0)),6)
                self.assertTrue(np.isfinite(feet).all())
                self.assertTrue(np.all(feet[:,1]>=ground))
                self.assertEqual(np.isclose(feet[:,1],ground).sum(),6 if step==0 else 3)
        entries = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        normal = np.array(entries['83']['max'])-entries['83']['min']
        ancient = np.array(entries['79']['max'])-entries['79']['min']
        self.assertGreater(ancient[2],normal[2])

    def test_all_authored_scales_and_size_hierarchy(self):
        from generar import SCALES
        targets = json.loads(SCALES.read_text())['monstruos']
        entries = json.loads((OUT/'catalogo.json').read_text())['monstruos']
        enabled = {k:v for k,v in entries.items() if v.get('anatomia')}
        self.assertEqual(set(targets),set(enabled))
        spans = {}
        for oid,entry in enabled.items():
            bounds = np.array(entry['max'])-entry['min']
            spans[oid] = max(bounds[0],bounds[2])
            self.assertAlmostEqual(spans[oid],targets[oid]['longitud_casillas'],places=5)
            self.assertGreater(entry['escala']['factor'],0)
        self.assertGreater(spans['79']/spans['83'],2.)
        self.assertGreater(spans['38']/spans['21'],3.5)
        self.assertGreater(spans['27']/spans['21'],2.)
        self.assertGreater(spans['34'],spans['38'])
        self.assertGreater(spans['42'],spans['16'])
        self.assertEqual(spans['38'],spans['208'])

    def test_scarab_split_cases_and_real_grooves(self):
        from reptadores import elytron_point
        for ancient in (False,True):
            for theta in np.linspace(.1,np.pi-.1,12):
                left = elytron_point(-1,theta,0,ancient)
                right = elytron_point(1,theta,0,ancient)
                self.assertGreater(right[0]-left[0],.004)
                self.assertTrue(np.allclose(left[1:],right[1:]))
            # Ribs change actual height, not only color on a smooth ellipsoid.
            phi = np.linspace(.15,1.35,100)
            xyz = np.array([elytron_point(1,np.pi/2,p,ancient) for p in phi])
            residual = xyz[:,1]-(.142+.127*np.cos(phi))
            self.assertGreater(np.ptp(residual),.004)

    def test_arthropod_contacts_tail_and_size(self):
        from artropodos import PROFILES,leg_joints,tail_points
        for profile in PROFILES.values():
            for phase in range(3):
                feet=np.array([leg_joints(side,pair,phase,profile['shape'])[-1]
                               for side in (-1,1) for pair in range(profile['pairs'])])
                self.assertEqual(len(np.unique(feet,axis=0)),profile['pairs']*2)
                self.assertTrue(np.isfinite(feet).all())
                self.assertTrue(np.all(feet[:,1]>=.008))
                contacts=profile['pairs'] if phase or profile['shape']=='centipede' else profile['pairs']*2
                # The first centipede pair has both feet down at the wave zero crossing.
                if profile['shape']=='centipede' and phase==0:
                    contacts+=1
                self.assertEqual(np.isclose(feet[:,1],.008).sum(),contacts)
        for phase in range(3):
            tail=tail_points(phase)
            self.assertGreater(tail[:,1].max(),.5)
            self.assertTrue(np.all(np.linalg.norm(np.diff(tail,axis=0),axis=1)>.05))
        entries=json.loads((OUT/'catalogo.json').read_text())['monstruos']
        size=lambda oid:entries[str(oid)]['escala']['longitud_casillas']
        self.assertLess(size(45),size(21))
        self.assertLess(size(45)*2,size(83))
        self.assertGreater(size(124),size(43))

    def test_farm_hooves_coat_and_relative_height(self):
        from granja import leg_joints,hoof_centers,fleece_point,pig_tail
        for pig in (False,True):
            for phase in range(3):
                feet=np.array([leg_joints(side,front,phase,pig)[-1]
                               for side in (-1,1) for front in (True,False)])
                self.assertEqual(np.isclose(feet[:,1],.030).sum(),4 if phase==0 else 2)
                self.assertTrue(np.all(feet[:,1]>=.030))
                for foot in feet:
                    toes=hoof_centers(foot)
                    self.assertGreater(toes[1,0]-toes[0,0],.024)
        for phase in range(3):
            self.assertTrue(np.isfinite(pig_tail(phase)).all())
            self.assertTrue(np.all(pig_tail(phase)[:,1]>.30))
        # The wool silhouette has real relief above the underlying ellipsoid.
        theta=np.linspace(.1,np.pi-.1,100)
        points=np.array([fleece_point(t,.3) for t in theta])
        self.assertGreater(np.ptp(np.linalg.norm((points-[0,.395,-.05])/[.205,.218,.338],axis=1)),.02)
        entries=json.loads((OUT/'catalogo.json').read_text())['monstruos']
        self.assertTrue(np.allclose(entries['13']['max'],entries['14']['max']))
        self.assertTrue(np.allclose(entries['13']['min'],entries['14']['min']))
        self.assertGreater(entries['14']['max'][1],entries['60']['max'][1]*1.2)
        def brightness(oid):
            blob=(OUT/entries[oid]['archivo']).read_bytes()
            n=struct.unpack_from('<I',blob,12)[0]
            return np.frombuffer(blob,dtype='u1',count=n*3,offset=16+n*24).mean()
        self.assertGreater(brightness('14'),brightness('13')*1.5)

    def test_forest_support_antlers_and_sizes(self):
        from bosque import leg_joints,antler_branches
        for rabbit in (False,True):
            ground=.018 if rabbit else .025
            for phase in range(3):
                feet=np.array([leg_joints(side,front,phase,rabbit)[-1]
                               for side in (-1,1) for front in (True,False)])
                self.assertTrue(np.isfinite(feet).all())
                self.assertTrue(np.all(feet[:,1]>=ground))
                self.assertEqual(np.isclose(feet[:,1],ground).sum(),4 if phase==0 else 2)
                self.assertEqual(len(np.unique(feet,axis=0)),4)
        for side in (-1,1):
            branches=antler_branches(side)
            self.assertLess(np.sum(((branches[0][0]-[0,.879,.389])/[.076,.08,.13])**2),1)
            self.assertTrue(np.array_equal(branches[1][0],branches[0][1]))
            self.assertTrue(np.array_equal(branches[2][0],branches[0][2]))
            self.assertTrue(all(np.all(branch[:,0]*side>0) for branch in branches))
        entries=json.loads((OUT/'catalogo.json').read_text())['monstruos']
        self.assertGreater(entries['31']['max'][1],entries['14']['max'][1]*1.5)
        self.assertGreater(entries['31']['escala']['longitud_casillas'],entries['74']['escala']['longitud_casillas']*2.5)
        self.assertLess(entries['74']['max'][1],entries['14']['max'][1])

    def test_dog_hyaena_gait_slope_and_size(self):
        from caninos import leg_joints,torso_path
        for hyena in (False,True):
            for phase in range(3):
                contacts=[]
                for side in (-1,1):
                    for front in (True,False):
                        foot=leg_joints(side,front,phase,hyena)[-1]
                        self.assertTrue(np.isfinite(foot).all())
                        self.assertGreaterEqual(foot[1],.023)
                        if np.isclose(foot[1],.023): contacts.append((side,front))
                self.assertEqual(len(contacts),4 if phase==0 else 2)
                if phase:
                    self.assertNotEqual(contacts[0][0],contacts[1][0])
                    self.assertNotEqual(contacts[0][1],contacts[1][1])
        path,radii=torso_path(True)
        self.assertGreater(path[3,1]+radii[3]-(path[1,1]+radii[1]),.14)
        entries=json.loads((OUT/'catalogo.json').read_text())['monstruos']
        self.assertLess(entries['32']['escala']['longitud_casillas'],entries['27']['escala']['longitud_casillas'])
        self.assertGreater(entries['94']['escala']['longitud_casillas'],entries['32']['escala']['longitud_casillas']*1.3)

if __name__ == '__main__':
    unittest.main(verbosity=2)