"""Stocky plantigrade bears, with original brown, polar and panda markings."""
from functools import partial
import math
import numpy as np

PROFILES = {
    16: dict(body=(99,58,25), light=(139,88,39), dark=(55,32,15), nose=(20,14,8),
             width=.217, head=.127, neck=0., muzzle=.135, panda=False),
    42: dict(body=(151,150,140), light=(184,183,171), dark=(100,102,98), nose=(25,27,25),
             width=.204, head=.116, neck=.105, muzzle=.165, panda=False),
    123: dict(body=(159,163,161), light=(192,195,193), dark=(28,30,30), nose=(10,12,12),
              width=.240, head=.153, neck=-.025, muzzle=.078, panda=True),
}


def leg_joints(side, front, step):
    swing = side*step*(1 if front else -1)
    move,lift = swing*.031,max(0,swing)*.025
    if front:
        return np.array([[side*.075,.385,.17],[side*.171,.195,.22+move*.4],
                         [side*.176,.06+lift,.275+move],[side*.176,.026+lift,.32+move]])
    return np.array([[side*.065,.345,-.28],[side*.182,.19,-.24+move*.5],
                     [side*.177,.065+lift,-.36+move],[side*.177,.026+lift,-.302+move]])


def make_generators(base):
    class BearSculpt(base):
        def __init__(self, views, profile):
            super().__init__(views)
            self.profile = profile
            self.source = np.unique(self.palette,axis=0).astype(float)
            self.materials = {k:self.closest(profile[k]) for k in ('body','light','dark','nose')}
            self.blends = {}

        def closest(self, rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self, uv, kind='body', direction=2):
            return self.materials.get(kind,self.materials['body'])

        def blend(self, first, second, amount):
            amount = int(np.clip(amount,0,1)*24)/24
            key = first,second,amount
            if key not in self.blends:
                self.blends[key] = self.closest(self.materials[first]*(1-amount)+self.materials[second]*amount)
            return self.blends[key]

        def paint_body(self, start):
            for i in range(start,len(self.vertices)):
                x,y,z = self.vertices[i]
                if self.profile['panda']:
                    # Shoulder saddle wraps around the body, as in the source.
                    amount = np.clip(min((z-.015)*25,(.275-z)*30),0,1)
                    self.colors[i] = self.blend('body','dark',amount)
                else:
                    noise = .12+.10*math.sin(x*38+z*27)*math.sin(y*43-z*15)
                    self.colors[i] = self.blend('body','light',noise+max(0,y-.4)*.7)

    return {oid:partial(bear,sculpt_type=BearSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def bear(views, phase, *, sculpt_type, profile):
    s = sculpt_type(views,profile)
    step = [0.,1.,-1.][phase%3]
    width,head,neck = profile['width'],profile['head'],profile['neck']
    start = len(s.vertices)
    s.tube([(0,.335,-.44),(0,.365,-.29),(0,.387,-.06),
            (0,.421,.12),(0,.412,.25),(0,.457,.345+neck)],
           [.070,width*.90,width,width*.96,width*.71,head*.64],'body',32)
    s.paint_body(start)
    head_center = np.array([0,.476,.405+neck])
    s.ellipsoid(head_center,(head,.118,head*1.07),'body',32,18)
    muzzle_z = head_center[2]+head*.70
    s.ellipsoid((0,.448,muzzle_z+profile['muzzle']*.38),
                (head*.58,.058,profile['muzzle']*.66),'light',24,14)
    nose_z = muzzle_z+profile['muzzle']*.96
    s.ellipsoid((0,.457,nose_z),(head*.31,.026,.018),'nose',18,10)
    s.ellipsoid((0,.412,muzzle_z+profile['muzzle']*.4),
                (head*.43,.006,profile['muzzle']*.48),'nose',20,8)
    s.ellipsoid((0,.402,muzzle_z+profile['muzzle']*.35),
                (head*.45,.014,profile['muzzle']*.48),'light',20,10)
    for side in (-1,1):
        ear_kind = 'dark' if profile['panda'] else 'body'
        s.ellipsoid((side*head*.78,.568,head_center[2]-.052),(.047,.052,.027),ear_kind,20,12)
        s.ellipsoid((side*head*.78,.574,head_center[2]-.030),(.028,.031,.005),'dark',16,10)
        eye_z = head_center[2]+head*.79
        if profile['panda']:
            s.ellipsoid((side*head*.56,.513,eye_z),(.034,.040,.017),'dark',24,14)
        s.ellipsoid((side*head*.61,.513,eye_z+.012),(.010,.012,.008),'nose',12,8)
        s.ellipsoid((side*head*.62,.517,eye_z+.018),(.0028,.003,.002),'light',8,6)
        for front in (True,False):
            joints = leg_joints(side,front,step)
            limb_kind = 'dark' if profile['panda'] else 'body'
            s.tube(joints,[.086,.064,.043,.042],limb_kind,16)
            foot = joints[-1]
            s.ellipsoid(foot,(.058,.026,.083),limb_kind,22,12)
            for toe in (-2,-1,0,1,2):
                p = foot+np.array([toe*.021,0,.046])
                s.ellipsoid(p,(.017,.022,.033),limb_kind,12,8)
                s.tube([p+[0,0,.027],p+[0,-.010,.046]],
                       [.006,.001],'dark' if not profile['panda'] else 'nose',6)
    s.ellipsoid((0,.36,-.443),(.043,.047,.067),'body',18,10)
    vertices,normals,colors = s.result()
    source_width = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)
    # Variant-specific neck length participates in the fixed footprint transform.
    vertices *= (source_width/32*.90)/(1.10+neck)
    return vertices,normals,colors