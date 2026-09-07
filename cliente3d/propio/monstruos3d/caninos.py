"""Brown domestic dog and a sloping-backed hyaena with a spotted coat."""
from functools import partial
import math
import numpy as np

PROFILES={
    32:dict(hyaena=False,body=(93,41,3),light=(139,83,18),dark=(45,18,0),nose=(18,8,0)),
    94:dict(hyaena=True,body=(127,108,83),light=(168,149,122),dark=(51,41,30),nose=(27,22,15)),
}


def torso_path(hyaena):
    if hyaena:
        return np.array([[0,.26,-.36],[0,.29,-.25],[0,.34,-.08],[0,.40,.11],[0,.45,.24],[0,.49,.32]]),[.05,.102,.135,.148,.116,.071]
    return np.array([[0,.30,-.33],[0,.31,-.23],[0,.32,-.03],[0,.34,.15],[0,.40,.27],[0,.46,.32]]),[.05,.095,.101,.11,.077,.060]


def leg_joints(side,front,phase,hyaena=False):
    swing=side*(0.,1.,-1.)[phase%3]*(1 if front else -1)
    z=.18 if front else -.25
    hip=(.40 if front else .29) if hyaena else .32
    return np.array([[side*.055,hip,z],[side*.109,.185,z+(.022 if front else .057)],
                     [side*.12,.062+max(0,swing)*.031,z+swing*.025],
                     [side*.12,.023+max(0,swing)*.031,z+.055+swing*.039]])


def make_generators(base):
    class CompanionSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source=np.unique(self.palette,axis=0).astype(float)
            self.materials={k:self.closest(profile[k]) for k in ('body','light','dark','nose')}
            self.profile=profile

        def closest(self,rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def paint(self,start):
            for i in range(start,len(self.vertices)):
                x,y,z=self.vertices[i]
                spot=math.sin(z*54+y*31)*math.sin(y*67-z*17)
                if self.profile['hyaena'] and abs(x)>.055 and spot>.72:
                    self.colors[i]=self.materials['dark']
                elif y<.29 and z>-.22:
                    self.colors[i]=self.materials['light']
    return {oid:partial(build,sculpt_type=CompanionSculpt,profile=profile) for oid,profile in PROFILES.items()}


def build(views,phase,*,sculpt_type,profile):
    s=sculpt_type(views,profile)
    hyena=profile['hyaena']
    start=len(s.vertices)
    points,radii=torso_path(hyena)
    s.tube(points,radii,'body',28)
    s.paint(start)
    y=.50 if hyena else .465
    width=.088 if hyena else .071
    s.ellipsoid((0,y,.368),(width,.082,.109),'body',28,16)
    s.tube([(0,y-.011,.409),(0,y-.033,.472),(0,y-.047,.531)],
           [.060 if hyena else .044,.043 if hyena else .035,.029],'body',16)
    s.ellipsoid((0,y-.053,.475),(.045,.009,.066),'nose',20,8)
    s.ellipsoid((0,y-.066,.468),(.042,.016,.061),'light',20,10)
    s.ellipsoid((0,y-.043,.542),(.031,.023,.017),'nose',18,10)
    for side in (-1,1):
        s.ellipsoid((side*width*.81,y+.026,.410),(.011,.013,.014),'nose',14,8)
        s.ellipsoid((side*width*.83,y+.031,.414),(.003,.003,.003),'light',8,6)
        if hyena:
            s.ellipsoid((side*.068,y+.091,.325),(.038,.049,.019),'body',20,14)
            s.ellipsoid((side*.069,y+.095,.342),(.024,.031,.005),'dark',18,10)
        else:
            # Short dropped ears attach to the side of the skull and taper downward.
            s.tube([(side*.053,y+.048,.333),(side*.093,y+.027,.317),
                    (side*.105,y-.043,.339)],[.022,.032,.002],'dark',14)
        for front in (True,False):
            joints=leg_joints(side,front,phase,hyena)
            s.tube(joints,[.050 if hyena and front else .038,.030,.018,.024],'body',12)
            s.ellipsoid(joints[-1],(.032,.023,.045),'body',18,10)
            for toe in (-1,0,1):
                s.ellipsoid(joints[-1]+[toe*.017,-.003,.027],(.011,.016,.020),'dark' if hyena else 'body',10,6)
    sway=(0.,1.,-1.)[phase%3]*.026
    if hyena:
        s.tube([(0,.275,-.32),(sway,.21,-.425),(sway+.02,.13,-.51),(sway+.033,.14,-.55)],
               [.027,.041,.032,.001],'body',14)
        s.tube([(sway+.014,.15,-.485),(sway+.033,.14,-.55)],[.032,.001],'dark',12)
        for z in np.linspace(-.20,.25,10):
            ytop=float(np.interp(z,points[:,2],points[:,1]+np.array(radii)))
            s.tube([(0,ytop-.025,z),(0,ytop+.022,z-.038)],[.012,.001],'dark',8)
    else:
        s.tube([(0,.326,-.31),(sway,.37,-.42),(sway+.023,.463,-.48),(sway+.028,.51,-.49)],
               [.021,.018,.010,.001],'body',12)
    return s.result()