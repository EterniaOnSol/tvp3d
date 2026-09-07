"""Radial Rotworm, segmented Larva and two six-legged scarab variants."""
from functools import partial
import math
import numpy as np

PROFILES = {
    26: dict(shape='worm', phases=6, body=(117,61,17), light=(166,101,42),
             dark=(22,10,3), accent=(101,13,8), limb=(108,49,12), ivory=(206,177,133)),
    82: dict(shape='larva', phases=3, body=(75,106,57), light=(181,187,112),
             dark=(23,39,20), accent=(115,139,70), limb=(69,48,91), ivory=(194,189,119)),
    83: dict(shape='scarab', phases=3, body=(60,83,46), light=(124,145,96),
             dark=(21,28,21), accent=(49,67,36), limb=(33,41,32), ivory=(111,122,99)),
    79: dict(shape='ancient', phases=3, body=(73,58,85), light=(140,128,153),
             dark=(22,25,24), accent=(206,124,24), limb=(44,62,39), ivory=(122,136,130)),
}


def mouth_opening(phase):
    return (1.,.70,.40,.12,.40,.70)[phase%6]


def leg_joints(side, pair, step, larva=False):
    swing = side*step*(1 if pair%2==0 else -1)
    if larva:
        z = .22-pair*.072
        return np.array([[side*.056,.09,z],[side*.10,.055,z+.020],
                         [side*.135,.010+max(0,swing)*.019,z+.027+swing*.022]])
    z = (.15,.01,-.15)[pair]
    target = (.34,.035,-.34)[pair]
    x = (.26,.31,.28)[pair]
    return np.array([[side*.09,.13,z],[side*.19,.145,z+(target-z)*.42],
                     [side*x,.055+max(0,swing)*.023,target+swing*.025],
                     [side*(x+.035),.009+max(0,swing)*.030,target+swing*.04]])


def make_generators(base):
    class Sculptor(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.profile = profile
            self.source = np.unique(self.palette,axis=0).astype(float)
            self.materials = {k:self.closest(profile[k]) for k in ('body','light','dark','accent','limb','ivory')}
            self.blends = {}

        def closest(self,color):
            return self.source[np.argmin(np.sum((self.source-np.array(color))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def blend(self,first,second,amount):
            amount = round(float(np.clip(amount,0,1))*24)/24
            key = first,second,amount
            if key not in self.blends:
                self.blends[key] = self.closest(self.materials[first]*(1-amount)+self.materials[second]*amount)
            return self.blends[key]

        def shell(self,center,radius,seam=False):
            start = len(self.vertices)
            self.ellipsoid(center,radius,'body',32,20)
            for i in range(start,len(self.vertices)):
                x,y,z = (self.vertices[i]-center)/radius
                if seam and abs(x)<.055 and y>0:
                    self.colors[i] = self.materials['dark']
                elif y<.14:
                    self.colors[i] = self.materials['limb'] if seam else self.materials['body']
                else:
                    self.colors[i] = self.blend('body','light',max(0,y)*(.50 if seam else .80))

        def ring(self,y,radius,thickness,height,kind='body'):
            def point(u,v):
                return [(radius+thickness*math.cos(v))*math.cos(u),y+height*math.sin(v),
                        (radius+thickness*math.cos(v))*math.sin(u)]
            for i in range(36):
                for j in range(12):
                    u,v = i*math.tau/36,j*math.tau/12
                    p,q,r,t = point(u,v),point(u+math.tau/36,v),point(u+math.tau/36,v+math.tau/12),point(u,v+math.tau/12)
                    self.face([p,r,q],(i/36,j/12),kind)
                    self.face([p,t,r],(i/36,j/12),kind)

    return {oid:partial(build,sculpt_type=Sculptor,profile=profile) for oid,profile in PROFILES.items()}


def rotworm(s,phase):
    opening = mouth_opening(phase)
    # Short, ribbed body: original frames show a radial feeding mouth, no legs.
    s.ellipsoid((0,.038,0),(.171,.038,.171),'body',28,12)
    for y,r in ((.055,.130),(.104,.127),(.15,.116)):
        s.ring(y,r,.036,.029)
    lip = .063+opening*.070
    s.ellipsoid((0,.193,0),(lip,.009,lip),'dark',28,12)
    s.ellipsoid((0,.202,.004),(lip*.30,.010,lip*.34),'accent',18,10)
    s.ring(.203,lip+.013,.037,.036,'light')
    for i in range(8):
        a = i*math.tau/8
        unit = np.array([math.cos(a),0,math.sin(a)])
        outer = unit*(lip+.030)+[0,.220,0]
        middle = unit*(lip*.82)+[0,.252+opening*.016,0]
        tip = unit*(lip*.50)+[0,.218+opening*.009,0]
        s.tube([outer,middle,tip],[.017,.012,.001],'ivory',10)
    return .40


def larva(s,phase):
    step = (0.,1.,-1.)[phase%3]
    for j in range(7):
        z = -.33+j*.085
        width = .033+.050*math.sin((j+1)/8*math.pi)
        x = step*.014*math.sin(j*math.pi/3)
        center = np.array([x,width+.014,z])
        s.shell(center,np.array([width,width,.065]))
    s.ellipsoid((0,.117,.265),(.078,.071,.075),'body',26,16)
    s.ellipsoid((0,.081,.324),(.043,.021,.017),'dark',18,10)
    for side in (-1,1):
        for pair in range(3):
            s.tube(leg_joints(side,pair,step,True),[.017,.012,.002],'limb',10)
        s.ellipsoid((side*.056,.140,.306),(.008,.009,.008),'dark',12,8)
        s.tube([(side*.046,.165,.286),(side*.066,.214,.328),(side*.085,.221,.344)],
               [.009,.006,.001],'limb',8)
    return .75


def scarab(s,phase,ancient):
    step = (0.,1.,-1.)[phase%3]
    width = .171 if ancient else .145
    s.ellipsoid((0,.095,-.07),(width,.074,.249),'dark',28,14)
    s.shell(np.array([0,.147,-.115]),np.array([width,.119,.218]),True)
    s.shell(np.array([0,.164,.123]),np.array([width*.81,.067,.080]))
    s.ellipsoid((0,.139,.228),(width*.55,.046,.068),'body',24,14)
    for side in (-1,1):
        for pair in range(3):
            joints = leg_joints(side,pair,step)
            s.tube(joints,[.022,.017,.010,.002],'limb',12)
            s.ellipsoid(joints[1],(.019,.017,.019),'limb',12,8)
        eye = [side*width*.43,.174,.258]
        s.ellipsoid(eye,(.012,.014,.012),'accent' if ancient else 'dark',14,8)
        s.tube([(side*.066,.151,.261),(side*.127,.20,.285),(side*.16,.235,.265)],
               [.008,.006,.002],'limb',8)
        if ancient:
            # Long opposing mandibles and inward teeth follow the source silhouette.
            s.tube([(side*.061,.12,.257),(side*.145,.16,.34),
                    (side*.163,.186,.47),(side*.108,.19,.563)],
                   [.031,.031,.023,.001],'limb',14)
            s.tube([(side*.151,.185,.439),(side*.096,.185,.425)], [.015,.001],'ivory',8)
            s.tube([(side*.122,.161,.328),(side*.077,.158,.350)], [.014,.001],'ivory',8)
        else:
            s.tube([(side*.041,.112,.28),(side*.075,.121,.334),(side*.027,.129,.357)],
                   [.018,.014,.001],'limb',10)
    return .95 if ancient else .76


def build(views,phase,*,sculpt_type,profile):
    s = sculpt_type(views,profile)
    shape = profile['shape']
    if shape=='worm':
        extent = rotworm(s,phase)
    elif shape=='larva':
        extent = larva(s,phase)
    else:
        extent = scarab(s,phase,shape=='ancient')
    vertices,normals,colors = s.result()
    source_width = max(v['bounds'][2]-v['bounds'][0]+1 for v in views)
    vertices *= (source_width/32*.90)/extent
    return vertices,normals,colors