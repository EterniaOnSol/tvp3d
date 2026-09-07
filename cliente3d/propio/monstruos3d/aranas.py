"""Eight-legged authored family. RGB targets select existing source pixels only."""
from functools import partial
import math
import numpy as np

PROFILES = {
    30: dict(body=(100,27,9), abdomen=(67,106,24), light=(151,175,65),
             leg=(123,29,8), joint=(185,43,9), eye=(19,17,7), fang=(47,24,10),
             radius=.024, abdomen_width=.15, abdomen_length=.215, pattern='green', hair=False),
    36: dict(body=(126,55,19), abdomen=(58,131,146), light=(104,168,176),
             leg=(175,69,15), joint=(236,145,35), eye=(27,19,9), fang=(77,30,9),
             radius=.025, abdomen_width=.15, abdomen_length=.215, pattern='cyan', hair=False),
    38: dict(body=(81,50,20), abdomen=(35,31,31), light=(61,57,55),
             leg=(186,74,17), joint=(251,182,45), eye=(88,146,48), fang=(133,81,21),
             radius=.027, abdomen_width=.175, abdomen_length=.245, pattern='red', hair=False),
    208: dict(body=(81,50,20), abdomen=(35,31,31), light=(61,57,55),
              leg=(186,74,17), joint=(251,182,45), eye=(88,146,48), fang=(133,81,21),
              radius=.027, abdomen_width=.175, abdomen_length=.245, pattern='red', hair=False),
    219: dict(body=(67,37,18), abdomen=(85,49,26), light=(96,60,34),
              leg=(53,31,17), joint=(169,143,104), eye=(16,12,8), fang=(82,50,28),
              radius=.037, abdomen_width=.19, abdomen_length=.23, pattern='brown', hair=True),
}


def make_generators(base):
    class SpiderSculpt(base):
        def __init__(self, views, profile):
            super().__init__(views)
            self.profile = profile
            colors = np.unique(self.palette,axis=0).astype(float)
            self.source_colors = colors
            self.blends = {}
            targets = {k:profile[k] for k in ('body','abdomen','light','leg','joint','eye','fang')}
            targets['accent'] = (159,20,18)
            targets['dark'] = (14,12,10)
            self.materials = {k:colors[np.argmin(np.sum((colors-np.array(v))**2,axis=1))].astype('u1')
                              for k,v in targets.items()}

        def pixel(self, uv, kind='body', direction=2):
            return self.materials.get(kind,self.materials['body'])

        def blend(self, first, second, weight):
            weight = int(np.clip(weight,0,1)*24)/24
            key = (first,second,weight)
            if key not in self.blends:
                target = self.materials[first]*(1-weight)+self.materials[second]*weight
                self.blends[key] = self.source_colors[np.argmin(np.sum((self.source_colors-target)**2,axis=1))].astype('u1')
            return self.blends[key]

        def abdomen(self, center, radius):
            start = len(self.vertices)
            self.ellipsoid(center,radius,'abdomen',40,24)
            # Per-vertex sampling keeps markings continuous across triangle edges.
            for i in range(start,len(self.vertices)):
                x,y,z = (self.vertices[i]-center)/radius
                pattern = self.profile['pattern']
                first,second,weight = 'abdomen','light',0.
                if pattern == 'red':
                    lengthwise = np.clip((.11-abs(x))*32,0,1)*np.clip((.65-abs(z))*20,0,1)
                    bands = max(np.clip((.12-abs(z+.10))*25,0,1),np.clip((.085-abs(z-.5))*30,0,1))
                    weight = max(lengthwise,bands)*np.clip((y-.18)*8,0,1)
                    second = 'accent'
                elif pattern in ('green','cyan'):
                    edge = max(np.clip((abs(x)-.76)/.23,0,1),np.clip((-y-.05)*5,0,1))
                    if edge>0:
                        second,weight = 'body',edge
                    else:
                        weight = math.exp(-((x+.30)/.22)**2)*np.clip((y-.3)*1.5,0,1)
                elif pattern == 'brown':
                    weight = (.18+.14*math.sin(x*18+z*11)*math.sin(z*23-y*9))*max(0,y)
                self.colors[i] = self.blend(first,second,weight)

        def hair(self, origin, direction, length):
            origin,direction = np.array(origin,float),np.array(direction,float)
            direction /= np.linalg.norm(direction)
            axis = np.array([0.,1.,0.]) if abs(direction[1])<.9 else np.array([1.,0.,0.])
            a = np.cross(direction,axis)
            a /= np.linalg.norm(a)
            b = np.cross(direction,a)
            tip = origin+direction*length
            for j in range(3):
                u,v = j*math.tau/3,(j+1)*math.tau/3
                p = origin+.0018*(math.cos(u)*a+math.sin(u)*b)
                q = origin+.0018*(math.cos(v)*a+math.sin(v)*b)
                self.face([p,q,tip],(0,0),'light')

    return {oid:partial(spider,sculpt_type=SpiderSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def leg_joints(side, pair, step):
    """Four staggered legs per side, with an alternating four-foot gait."""
    z = [.18,.095,.005,-.075][pair]
    knee_x = [.29,.39,.40,.32][pair]
    knee_z = [.38,.20,-.14,-.38][pair]
    foot_x = [.36,.51,.53,.43][pair]
    foot_z = [.53,.28,-.25,-.57][pair]
    swing = step*side*(1 if pair%2==0 else -1)
    return np.array([
        [side*.108,.205,z],
        [side*.19,.235,z+(knee_z-z)*.22],
        [side*knee_x,.29+swing*.009,knee_z+swing*.015],
        [side*(foot_x-.02),.075+max(0,swing)*.035,foot_z+swing*.045],
        [side*foot_x,.012+max(0,swing)*.042,foot_z+swing*.055],
    ])


def spider(views, phase, *, sculpt_type, profile):
    s = sculpt_type(views,profile)
    step = [0.,1.,-1.][phase%3]
    # Abdomen and cephalothorax are connected by the short pedicel.
    center = np.array([0.,.245,-.235])
    radius = np.array([profile['abdomen_width'],.165,profile['abdomen_length']])
    s.ellipsoid((0,.205,-.055),(.065,.058,.10),'body',20,12)
    s.abdomen(center,radius)
    s.ellipsoid((0,.197,.105),(.137,.106,.159),'body',28,16)
    # Small dorsal shield follows the carapace, not a separate floating plate.
    s.ellipsoid((0,.279,.075),(.084,.026,.096),'body',24,10)
    for side in (-1,1):
        for pair in range(4):
            joints = leg_joints(side,pair,step)
            r = profile['radius']
            s.tube(joints,[r,r*.87,r*.73,r*.38,.0025],'leg',10)
            # Colored knee plates and short tibial bands seen in the atlas.
            s.ellipsoid(joints[2],(r*.90,r*.88,r*.90),'joint',12,8)
            tibia = joints[2]*.76+joints[3]*.24
            s.tube([joints[2]*.90+joints[3]*.10,tibia],[r*.64,r*.55],'joint',10)
            if profile['hair']:
                for fraction in (.25,.45,.65,.82):
                    point = joints[2]*(1-fraction)+joints[3]*fraction
                    for forward in (-1,1):
                        s.hair(point+[side*r*.5,r*.3,forward*r*.3],
                               [side*.45,.4,forward],.022)
        # Two short sensory palps and two downward-curving chelicerae.
        s.tube([(side*.086,.20,.205),(side*.134,.15,.29),(side*.117,.12,.34)],
               [.028,.019,.008],'body',10)
        s.ellipsoid((side*.041,.175,.253),(.027,.036,.043),'body',16,10)
        s.tube([(side*.043,.168,.275),(side*.047,.114,.295),(side*.023,.093,.312)],
               [.018,.012,.001],'fang',10)
        for x,y in [(side*.025,.247),(side*.027,.22),(side*.071,.241),(side*.095,.214)]:
            z = .105+.159*math.sqrt(max(.01,1-(x/.137)**2-((y-.197)/.106)**2))
            size = .009 if abs(x)<.05 else .0065
            s.ellipsoid((x,y,z+.004),(size,size,size*.7),'eye',12,8)
    if profile['hair']:
        # Deterministic short bristles, distributed on the exposed abdomen.
        for j in range(7):
            theta = .18+j*.18
            for i in range(18):
                a = (i+(j%2)*.5)*math.tau/18
                normal = np.array([math.sin(theta)*math.cos(a),math.cos(theta),math.sin(theta)*math.sin(a)])
                point = center+radius*normal
                s.hair(point,normal,.016+.009*((i+j)%3)/2)
    vertices,normals,colors = s.result()
    # Match source footprint once, independent of gait pose (no pumping scale).
    source_width = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)
    vertices *= (source_width/32*.90)/1.12
    return vertices,normals,colors