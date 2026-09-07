"""Authored canines: lean grey wolf, white winter wolf, larger war wolf."""
from functools import partial
import math
import numpy as np

PROFILES = {
    27: dict(body=(76,79,81), light=(126,129,131), dark=(35,37,39),
             nose=(13,14,15), eye=(48,44,37), width=1., head=1., coat='saddle'),
    52: dict(body=(152,156,160), light=(187,190,194), dark=(105,110,117),
             nose=(22,24,27), eye=(44,42,37), width=1.04, head=1., coat='white'),
    3: dict(body=(88,92,96), light=(136,140,144), dark=(47,51,55),
            nose=(23,25,28), eye=(224,180,43), width=1.22, head=1.16, coat='streaks'),
}


def leg_joints(side, front, step):
    swing = side*step*(1 if front else -1)
    move,lift = swing*.048,max(0,swing)*.037
    if front:
        return np.array([[side*.065,.425,.22],[side*.112,.24,.235+move*.4],
                         [side*.115,.07+lift,.28+move],[side*.115,.024+lift,.345+move]])
    return np.array([[side*.04,.365,-.27],[side*.15,.235,-.14+move*.35],
                     [side*.135,.105+lift,-.29+move],[side*.13,.024+lift,-.255+move]])


def make_generators(base):
    class WolfSculpt(base):
        def __init__(self, views, profile):
            super().__init__(views)
            self.profile = profile
            self.source = np.unique(self.palette,axis=0).astype(float)
            self.materials = {k:self.closest(profile[k]) for k in ('body','light','dark','nose','eye')}
            self.blends = {}

        def closest(self, rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self, uv, kind='body', direction=2):
            return self.materials.get(kind,self.materials['body'])

        def blend(self, a, b, weight):
            weight = int(np.clip(weight,0,1)*24)/24
            key = (a,b,weight)
            if key not in self.blends:
                self.blends[key] = self.closest(self.materials[a]*(1-weight)+self.materials[b]*weight)
            return self.blends[key]

        def coat(self, center, radius, saddle=True):
            start = len(self.vertices)
            self.ellipsoid(center,radius,'body',32,18)
            for i in range(start,len(self.vertices)):
                x,y,z = (self.vertices[i]-center)/radius
                if y<.12:
                    color = self.blend('body','light',np.clip((.12-y)*.9,0,.75))
                else:
                    amount = np.clip((y-.15)*1.15,0,1) if saddle else .15
                    if self.profile['coat']=='white':
                        color = self.blend('body','light',y*.7)
                    elif self.profile['coat']=='streaks':
                        amount *= .5+.3*math.sin(z*22+abs(x)*9)
                        color = self.blend('body','light',amount*.8)
                    else:
                        color = self.blend('body','dark',amount*.8)
                self.colors[i] = color

        def ear(self, side, head_scale):
            # Closed triangular pinna with a separate inset on its forward face.
            x = side*.076*head_scale
            a = np.array([x-side*.045,.65,.32])
            b = np.array([x+side*.043,.645,.31])
            tip = np.array([x+side*.015,.76,.276])
            back = np.array([x,.66,.25])
            for tri in ((a,b,tip),(a,back,b),(b,back,tip),(tip,back,a)):
                points = np.array(tri)
                n = np.cross(points[1]-points[0],points[2]-points[0])
                if np.dot(n,points.mean(axis=0)-np.mean([a,b,tip,back],axis=0))<0:
                    points = points[[0,2,1]]
                self.face(points,(0,0),'body')
            center = (a+b+tip)/3
            inset = [center+(v-center)*.62+np.array([0,0,.002]) for v in (a,b,tip)]
            self.face(inset if side==1 else inset[::-1],(0,0),'dark')

    return {oid:partial(wolf,sculpt_type=WolfSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def wolf(views, phase, *, sculpt_type, profile):
    s = sculpt_type(views,profile)
    step = [0.,1.,-1.][phase%3]
    width,head = profile['width'],profile['head']
    # One continuous torso-to-neck surface avoids overlapping shoulder rings.
    start = len(s.vertices)
    s.tube([(0,.345,-.39),(0,.36,-.27),(0,.382,-.07),
            (0,.414,.15),(0,.467,.265),(0,.55,.337)],
           [.063*width,.122*width,.137*width,.153*width,.115*width,.081*head],'body',28)
    for i in range(start,len(s.vertices)):
        x,y,z = s.vertices[i]
        center_y = .38 if z<.1 else .414+max(0,z-.15)*.55
        height = (y-center_y)/(.145*width)
        if profile['coat']=='white':
            s.colors[i] = s.blend('body','light',max(0,height)*.45)
        elif profile['coat']=='streaks':
            streak = .15+.15*math.sin(z*42+abs(x)*35)
            s.colors[i] = s.blend('body','light',streak*max(0,height))
        elif height>.1:
            s.colors[i] = s.blend('body','dark',min(.6,height*.6))
        else:
            s.colors[i] = s.blend('body','light',min(.4,-height*.4))
    # Forward-facing wedge muzzle; a thin mouth line, lower jaw and black nose.
    s.coat(np.array([0,.61,.398]),np.array([.088*head,.088,.132]),False)
    s.tube([(0,.599,.452),(0,.573,.545),(0,.557,.622)], [.065*head,.047*head,.031*head],'body',16)
    s.ellipsoid((0,.538,.552),(.047*head,.013,.082),'nose',20,8)
    s.ellipsoid((0,.525,.546),(.045*head,.016,.075),'light',20,10)
    s.ellipsoid((0,.565,.628),(.034*head,.023,.019),'nose',16,10)
    for side in (-1,1):
        s.ear(side,head)
        # Dark eye socket, small iris and a light eyebrow.
        s.ellipsoid((side*.075*head,.635,.455),(.016,.020,.029),'dark',16,10)
        s.ellipsoid((side*.086*head,.636,.463),(.010,.011,.014),'eye',12,8)
        s.ellipsoid((side*.077*head,.651,.452),(.021,.012,.030),'body',16,8)
        # Short cheek tufts follow the head contour.
        s.tube([(side*.07*head,.57,.37),(side*.102*head,.553,.34),
                (side*.115*head,.531,.31)], [.025,.019,.001],'body',10)
        for front in (True,False):
            joints = leg_joints(side,front,step)
            joints[:,0] *= width
            radii = [.054*width,.033,.019,.023] if front else [.075*width,.046,.023,.023]
            s.tube(joints,radii,'body',14)
            foot = joints[-1]
            s.ellipsoid(foot,(.036*width,.024,.052),'light',18,10)
            for toe in (-1,0,1):
                pos = foot+np.array([toe*.021*width,-.003,.028])
                s.ellipsoid(pos,(.014*width,.019,.031),'body',12,8)
                s.tube([pos+[0,-.004,.023],pos+[0,-.008,.036]],[.006,.001],'nose',6)
    # Bushy tail carried low, gently counterbalancing the two diagonal poses.
    sway = step*.025
    s.tube([(0,.355,-.31),(.018,.31,-.48),(.036+sway,.23,-.60),
            (.06+sway,.165,-.73),(.079+sway,.19,-.82)], [.055*width,.086*width,.074,.045,.002],'body',18)
    # Tapered tufts give the tail a fur silhouette without a noisy shell.
    for side in (-1,1):
        for y,z in ((.295,-.50),(.235,-.59),(.18,-.69)):
            s.tube([(side*.04+sway*.5,y,z),(side*.075+sway,y-.018,z-.055)], [.026,.001],'dark',8)
    vertices,normals,colors = s.result()
    source_width = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)
    vertices *= (source_width/32*.90)/1.48
    return vertices,normals,colors