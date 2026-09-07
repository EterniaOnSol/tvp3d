"""Low green snake and raised hooded cobra, with a stable three-pose wave."""
from functools import partial
import math
import numpy as np

PROFILES = {
    28: dict(body=(33,111,44), light=(81,153,66), dark=(14,52,26),
             belly=(70,128,52), eye=(156,35,24), hood=False),
    81: dict(body=(65,49,60), light=(107,124,104), dark=(27,24,28),
             belly=(125,108,77), eye=(17,16,16), hood=True),
}


def centerline(phase, hood=False):
    shift = [0.,1.,-1.][phase%3]*.38
    points,radii = [],[]
    for t in np.linspace(0,1,20):
        radius = .001+(.043 if hood else .030)*(1-math.exp(-t*9))
        x = (.15 if hood else .13)*math.sin(t*math.tau*1.5+shift)*math.sin(math.pi*t)**1.5
        points.append([x,radius+.008,-.50+t*(.59 if hood else .91)])
        radii.append(radius)
    if hood:
        points.extend([[0,.13,.11],[0,.24,.145],[0,.35,.185],[0,.402,.23]])
        radii.extend([.039,.032,.030,.037])
    return np.array(points),np.array(radii)


def make_generators(base):
    class SnakeSculpt(base):
        def __init__(self, views, profile):
            super().__init__(views)
            self.profile = profile
            self.source = np.unique(self.palette,axis=0).astype(float)
            self.materials = {k:self.closest(profile[k]) for k in ('body','light','dark','belly','eye')}
            self.blends = {}

        def closest(self, rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self, uv, kind='body', direction=2):
            return self.materials.get(kind,self.materials['body'])

        def hood(self):
            def point(u,v):
                width = .032+.073*math.sin(math.pi*v)**.85
                return np.array([width*math.cos(u),.125+.275*v,.105+.115*v+.046*math.sin(u)])
            for j in range(24):
                for i in range(32):
                    u,v = i*math.tau/32,j/24
                    p,q,r,t = point(u,v),point(u+math.tau/32,v),point(u+math.tau/32,v+1/24),point(u,v+1/24)
                    kind = 'body'
                    if math.sin(u)>0:
                        kind = 'belly' if j%4 else 'body'
                    elif ((v-.56)/.26)**2+(math.cos(u)/.55)**2 < 1:
                        kind = 'light'
                    # This parametrization has inward cross normals: reverse it.
                    self.face([p,r,q],(i/32,v),kind)
                    self.face([p,t,r],(i/32,v),kind)
            # Close both ends; the neck overlaps the narrow bases.
            for v in (0.,1.):
                center = np.array([0,.125+.275*v,.105+.115*v])
                for i in range(32):
                    a,b = point(i*math.tau/32,v),point((i+1)*math.tau/32,v)
                    self.face([center,a,b] if v==0 else [center,b,a],(0,v),'body')

    return {oid:partial(snake,sculpt_type=SnakeSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def snake(views, phase, *, sculpt_type, profile):
    s = sculpt_type(views,profile)
    points,radii = centerline(phase,profile['hood'])
    s.tube(points,radii,'body',18)
    if profile['hood']:
        s.hood()
        center = np.array([0,.408,.252])
        head_radius = np.array([.047,.028,.070])
    else:
        center = np.array([0,.047,.431])
        head_radius = np.array([.039,.025,.064])
    s.ellipsoid(center,head_radius,'body',24,14)
    s.ellipsoid(center+[0,-head_radius[1]*.55,.008],head_radius*[.87,.22,.83],'belly',20,10)
    for side in (-1,1):
        p = center+np.array([side*head_radius[0]*.79,head_radius[1]*.35,.023])
        s.ellipsoid(p,(.005,.005,.006),'eye',12,8)
        if profile['hood']:
            s.ellipsoid(center+[side*.018,.012,.057],(.004,.003,.005),'dark',8,6)
    vertices,normals,colors = s.result()
    source_width = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)
    vertices *= (source_width/32*.90)/(1.01 if not profile['hood'] else .87)
    return vertices,normals,colors