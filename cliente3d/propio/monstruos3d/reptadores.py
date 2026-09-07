"""Radial Rotworm, segmented Larva and two six-legged scarab variants."""
from functools import partial
import math
import numpy as np

PROFILES = {
    26: dict(shape='worm', phases=6, body=(117,61,17), light=(166,101,42),
             dark=(22,10,3), accent=(101,13,8), limb=(108,49,12), ivory=(206,177,133)),
    82: dict(shape='larva', phases=3, body=(75,106,57), light=(181,187,112),
             dark=(23,39,20), accent=(115,139,70), limb=(69,48,91), ivory=(194,189,119)),
    83: dict(shape='scarab', phases=3, body=(38,86,33), light=(65,150,57),
             dark=(21,28,21), accent=(49,67,36), limb=(33,41,32), ivory=(111,122,99)),
    79: dict(shape='ancient', phases=3, body=(84,82,101), light=(120,107,145),
             dark=(22,25,24), accent=(206,124,24), limb=(31,40,27), ivory=(122,136,130)),
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
                    self.colors[i] = self.blend('body','light',max(0,y)*(.16 if self.profile['shape'] in ('scarab','ancient') else (.50 if seam else .80)))

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


def elytron_point(side, theta, phi, ancient):
    """Separate wing cases: inset suture, broad shoulders and engraved ribs."""
    envelope = max(0., math.sin(theta))
    width = .185 if ancient else .157
    x = side*(.0025 + width*envelope**.72*math.sin(phi))
    z = -.128-.237*math.cos(theta)
    ribs = .0032*math.cos(phi*24)*math.sin(phi)**.5 if phi < math.pi/2 else 0.
    y = .142 + (.127*math.cos(phi)+ribs)*envelope**.65
    return np.array([x,y,z])


def wing_case(s,side,ancient):
    # Analytic geometry gives the suture a real gap, not a painted zigzag.
    for j in range(28):
        for k in range(40):
            theta = (j+.5)*math.pi/28
            phi = (k+.5)*math.pi/40
            points = [elytron_point(side,t,v,ancient) for t,v in
                      ((j*math.pi/28,k*math.pi/40),((j+1)*math.pi/28,k*math.pi/40),
                       ((j+1)*math.pi/28,(k+1)*math.pi/40),(j*math.pi/28,(k+1)*math.pi/40))]
            start = len(s.vertices)
            for indices in ((0,1,2),(0,2,3)):
                tri = np.array([points[n] for n in indices])
                mid = tri.mean(axis=0)
                outward = (mid-[side*.0025,.142,-.128])/np.array([.18,.127,.237])**2
                if np.dot(np.cross(tri[1]-tri[0],tri[2]-tri[0]),outward)<0:
                    tri = tri[[0,2,1]]
                s.face(tri,(0,0),'body')
            if phi>1.5 or phi<.075:
                color = s.materials['dark']
            else:
                ridge = (.5+.5*math.cos(phi*24))
                color = s.blend('body','light',.06+.12*ridge+.18*math.sin(theta))
            for n in range(start,len(s.vertices)):
                s.colors[n] = color
    # Roll around the outer lip, with small chitin notches.
    rim = [elytron_point(side,t,1.48,ancient) for t in np.linspace(.13,math.pi-.13,25)]
    s.tube(rim,[.008]*len(rim),'limb',8)
    # Close the flat inner face below the visible dorsal suture.
    for j in range(28):
        a,b = j*math.pi/28,(j+1)*math.pi/28
        points = [elytron_point(side,a,0,ancient),elytron_point(side,b,0,ancient),
                  elytron_point(side,b,math.pi,ancient),elytron_point(side,a,math.pi,ancient)]
        for indices in ((0,1,2),(0,2,3)):
            tri = np.array([points[n] for n in indices])
            if np.cross(tri[1]-tri[0],tri[2]-tri[0])[0]*side>0:
                tri = tri[[0,2,1]]
            s.face(tri,(0,0),'dark')


def scarab(s,phase,ancient):
    step = (0.,1.,-1.)[phase%3]
    width = .185 if ancient else .157
    s.ellipsoid((0,.113,-.095),(width*.90,.069,.240),'dark',28,14)
    for z in (-.28,-.22,-.16,-.10,-.04):
        s.ellipsoid((0,.090,z),(width*.87,.040,.039),'limb',20,8)
    for side in (-1,1):
        wing_case(s,side,ancient)
    # Broad shield nested under the front of the wing cases, narrow armored head.
    s.shell(np.array([0,.156,.103]),np.array([width*.93,.078,.096]))
    # Paired rows of small chitin pits follow the shield surface.
    for side in (-1,1):
        for z in (.070,.092,.114,.136):
            x = side*width*.61
            y = .156+.078*math.sqrt(1-(x/(width*.93))**2-((z-.103)/.096)**2)
            s.ellipsoid((x,y,z),(.0035,.0018,.005),'dark',8,6)
    s.ellipsoid((0,.136,.225),(.076,.044,.068),'dark',24,12)
    s.shell(np.array([0,.158,.220]),np.array([.068,.035,.055]))
    # Frontal clypeus is a flattened digging shield.
    s.ellipsoid((0,.123,.274),(.070,.020,.030),'limb',22,10)
    for side in (-1,1):
        for pair in range(3):
            joints = leg_joints(side,pair,step)
            # Separate rigid segments preserve a visible knee and ankle.
            hip,knee,ankle,foot = joints
            s.tube([hip,(hip+knee)/2,knee],[.016,.027,.015],'limb',12)
            s.ellipsoid(knee,(.019,.019,.019),'dark',12,8)
            s.tube([knee,(knee+ankle)/2,ankle],[.014,.018,.007],'limb',10)
            s.tube([ankle,foot],[.007,.003],'dark',8)
            for tooth in (.35,.58,.78):
                root = knee*(1-tooth)+ankle*tooth
                s.tube([root,root+[side*.022,.002,.013]],[.006,.0007],'limb',6)
            for claw in (-1,1):
                s.tube([foot,foot+[claw*.009,0,.017]],[.003,.0006],'dark',6)
        eye = [side*.065,.165,.253]
        s.ellipsoid(eye,(.010,.008,.010),'accent' if ancient else 'dark',14,8)
        antenna = [(side*.06,.139,.258),(side*.102,.16,.29),(side*.143,.187,.287)]
        s.tube(antenna,[.005,.004,.003],'limb',8)
        s.ellipsoid(antenna[-1],(.009,.006,.012),'limb',12,8)
        if ancient:
            # Serrated, flattened stag-like pincers curve inward at their tips.
            points = [(side*.047,.115,.263),(side*.114,.122,.310),
                      (side*.168,.133,.401),(side*.159,.149,.489),(side*.074,.161,.565)]
            start = len(s.vertices)
            s.tube(points,[.026,.039,.034,.023,.001],'limb',16)
            for n in range(start,len(s.vertices)):
                s.vertices[n][1] = .135+(s.vertices[n][1]-.135)*.60
            # Recompute normals after flattening the whole pincer surface.
            for n in range(start,len(s.vertices),3):
                tri = np.array(s.vertices[n:n+3])
                normal = np.cross(tri[1]-tri[0],tri[2]-tri[0])
                normal /= np.linalg.norm(normal)
                s.normals[n:n+3] = [normal]*3
            for x,z in ((.131,.346),(.164,.403),(.155,.46)):
                s.tube([(side*x,.132,z),(side*(x-.047),.133,z+.021)],
                       [.014,.001],'limb',8)
        else:
            s.tube([(side*.041,.112,.28),(side*.068,.115,.327),(side*.022,.12,.35)],
                   [.017,.015,.001],'limb',12)
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