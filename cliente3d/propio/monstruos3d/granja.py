"""Wool-bearing sheep and a low, round pig; source palette and cloven hooves."""
from functools import partial
import math
import numpy as np

PROFILES={
    13:dict(shape='sheep',body=(58,57,53),light=(89,88,82),skin=(96,65,37),
            inner=(74,47,26),dark=(22,18,13)),
    14:dict(shape='sheep',body=(177,180,174),light=(217,219,211),skin=(96,65,37),
            inner=(74,47,26),dark=(22,18,13)),
    60:dict(shape='pig',body=(208,148,77),light=(235,182,108),skin=(186,118,62),
            inner=(174,102,51),dark=(53,31,13)),
}


def leg_joints(side,front,phase,pig=False):
    swing=side*(0.,1.,-1.)[phase%3]*(1 if front else -1)
    z=.205 if front else -.245
    hip=.31 if pig else .405
    width=.132 if pig else .112
    return np.array([[side*width*.62,hip,z],[side*(width+.014),.16,z+swing*.018],
                     [side*(width+.017),.030+max(0,swing)*.035,z+.023+swing*.045]])


def hoof_centers(foot):
    return np.array([foot+[side*.014,0,.008] for side in (-1,1)])


def fleece_point(theta,phi):
    direction=np.array([math.sin(theta)*math.cos(phi),math.cos(theta),math.sin(theta)*math.sin(phi)])
    # Low curls on a continuous surface retain the body silhouette without floating balls.
    curl=(.5+.5*math.cos(theta*20))*(.5+.5*math.cos(phi*26))
    return np.array([0,.395,-.05])+direction*(np.array([.205,.218,.338])+.012*curl*math.sin(theta)**2)


def pig_tail(phase):
    sway=(0.,1.,-1.)[phase%3]*.012
    points=[[0,.323,-.346],[0,.341,-.389]]
    for angle in np.linspace(0,math.tau*1.3,19):
        radius=.024*(1-angle/(math.tau*1.3)*.55)
        points.append([radius*math.sin(angle)+sway,.36-radius*math.cos(angle),-.405-angle*.004])
    return np.array(points)


def make_generators(base):
    class FarmSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source=np.unique(self.palette,axis=0).astype(float)
            self.materials={key:self.closest(profile[key]) for key in ('body','light','skin','inner','dark')}

        def closest(self,rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def fleece(self):
            center=np.array([0,.395,-.05])
            for j in range(38):
                for k in range(64):
                    points=[fleece_point(t,p) for t,p in
                            ((j*math.pi/38,k*math.tau/64),((j+1)*math.pi/38,k*math.tau/64),
                             ((j+1)*math.pi/38,(k+1)*math.tau/64),(j*math.pi/38,(k+1)*math.tau/64))]
                    for ids in ((0,1,2),(0,2,3)):
                        tri=np.array([points[i] for i in ids])
                        if np.dot(np.cross(tri[1]-tri[0],tri[2]-tri[0]),tri.mean(axis=0)-center)<0:
                            tri=tri[[0,2,1]]
                        self.face(tri,(0,0),'body')

        def ear(self,side,pig):
            if pig:
                a=np.array([side*.060,.365,.270]); b=np.array([side*.125,.350,.235])
                tip=np.array([side*.148,.445,.307]); back=np.array([side*.098,.350,.235])
            else:
                a=np.array([side*.058,.577,.282]); b=np.array([side*.059,.550,.294])
                tip=np.array([side*.173,.536,.281]); back=np.array([side*.094,.563,.257])
            center=np.mean([a,b,tip,back],axis=0)
            for face in ((a,b,tip),(a,back,b),(b,back,tip),(tip,back,a)):
                tri=np.array(face)
                if np.dot(np.cross(tri[1]-tri[0],tri[2]-tri[0]),tri.mean(axis=0)-center)<0:
                    tri=tri[[0,2,1]]
                self.face(tri,(0,0),'skin' if not pig else 'body')
            inset_center=(a+b+tip)/3
            tri=np.array([inset_center+(v-inset_center)*.62+[0,.001,.002] for v in (a,b,tip)])
            self.face(tri,(0,0),'inner')
    return {oid:partial(build,sculpt_type=FarmSculpt,profile=profile) for oid,profile in PROFILES.items()}


def sheep(s,phase):
    s.fleece()
    s.tube([(0,.38,.16),(0,.485,.24),(0,.54,.28)],[.105,.091,.07],'body',24)
    s.ellipsoid((0,.535,.311),(.070,.080,.111),'skin',26,16)
    s.ellipsoid((0,.487,.387),(.052,.045,.063),'skin',22,12)
    s.ellipsoid((0,.475,.438),(.035,.021,.012),'dark',18,10)
    s.ellipsoid((0,.596,.270),(.072,.053,.081),'body',22,14)
    for side in (-1,1):
        s.ear(side,False)
        s.ellipsoid((side*.062,.552,.352),(.009,.011,.012),'dark',12,8)
        s.ellipsoid((side*.065,.556,.355),(.0025,.003,.003),'light',8,6)
    s.tube([(0,.416,-.329),(0,.337,-.388),((0.,1.,-1.)[phase%3]*.014,.288,-.40)],
           [.036,.027,.012],'body',12)


def pig(s,phase):
    s.ellipsoid((0,.277,-.054),(.187,.162,.305),'body',32,20)
    s.ellipsoid((0,.285,.205),(.138,.130,.152),'body',28,18)
    s.tube([(0,.29,.277),(0,.264,.349),(0,.258,.403)],[.086,.068,.058],'body',18)
    s.ellipsoid((0,.263,.421),(.066,.046,.019),'skin',24,14)
    s.ellipsoid((0,.212,.353),(.059,.006,.065),'inner',20,8)
    for side in (-1,1):
        s.ear(side,True)
        s.ellipsoid((side*.025,.266,.439),(.010,.013,.005),'dark',12,8)
        s.ellipsoid((side*.11,.34,.298),(.011,.012,.011),'dark',14,8)
        s.ellipsoid((side*.113,.344,.302),(.003,.003,.003),'light',8,6)
    tail=pig_tail(phase)
    s.tube(tail,[.009]*(len(tail)-1)+[.001],'skin',8)


BUILDERS={'sheep':sheep,'pig':pig}


def build(views,phase,*,sculpt_type,profile):
    s=sculpt_type(views,profile)
    is_pig=profile['shape']=='pig'
    BUILDERS[profile['shape']](s,phase)
    for side in (-1,1):
        for front in (True,False):
            joints=leg_joints(side,front,phase,is_pig)
            s.tube(joints,[.048 if is_pig else .036,.027,.023],'body' if is_pig else 'skin',12)
            for center in hoof_centers(joints[-1]):
                s.ellipsoid(center,(.012,.030,.032),'dark',12,8)
    return s.result()