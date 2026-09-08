"""Four distinct birds reconstructed as authored volume from their source palettes."""
from functools import partial
import numpy as np


PROFILES = {
    111: dict(shape='chicken', body=(242,242,242), wing=(180,180,180),
              skin=(220,26,33), beak=(247,148,28), leg=(247,148,28), dark=(0,0,0)),
    212: dict(shape='flamingo', body=(203,181,186), wing=(164,125,137),
              skin=(70,23,36), beak=(11,3,5), leg=(247,148,28), dark=(0,0,0)),
    217: dict(shape='parrot', body=(190,7,6), wing=(0,255,255),
              skin=(255,247,153), beak=(247,148,28), leg=(235,204,8), dark=(0,0,0)),
    218: dict(shape='terror', body=(31,21,14), wing=(23,20,13),
              skin=(36,14,8), beak=(255,205,124), leg=(255,242,0), dark=(0,0,0)),
}


def leg_joints(side, phase, shape):
    step=(0.,1.,-1.)[phase%3]*side
    dimensions={
        'chicken': (.205,.085,.027,.035),
        'flamingo': (.485,.105,.018,.050),
        'parrot': (.245,.060,.018,.028),
        'terror': (.390,.125,.038,.065),
    }
    hip,width,ground,stride=dimensions[shape]
    lift=max(0.,step)*(.032 if shape!='flamingo' else .055)
    knee_z=-.025-step*stride*.45
    foot_z=.055+step*stride
    return np.array([[side*width,hip,0.],
                     [side*(width*1.04),hip*.52,knee_z],
                     [side*(width*1.08),ground+lift,foot_z]])


def toe_paths(foot, shape):
    spread=.024 if shape in ('chicken','parrot') else (.032 if shape=='flamingo' else .045)
    reach=.060 if shape!='terror' else .090
    radius=.008 if shape!='terror' else .014
    paths=[]
    for fan in (-1,0,1):
        paths.append((np.array([foot,foot+[fan*spread,0,reach],
                                foot+[fan*spread*1.15,-foot[1]+.006,reach*1.45]]),radius))
    paths.append((np.array([foot,foot+[0,0,-reach*.55],
                            foot+[0,-foot[1]+.006,-reach*.90]]),radius*.85))
    return paths


def neck_path(shape):
    if shape=='flamingo':
        return np.array([[0,.52,.08],[0,.69,.14],[0,.82,.09],[0,.91,.18],[0,1.02,.25]])
    if shape=='terror':
        return np.array([[0,.53,.13],[0,.68,.20],[0,.82,.29]])
    if shape=='parrot':
        return np.array([[0,.38,.13],[0,.47,.20],[0,.54,.27]])
    return np.array([[0,.34,.11],[0,.42,.18],[0,.47,.24]])


def make_generators(base):
    class BirdSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source=np.unique(self.palette,axis=0).astype(float)
            self.materials={key:self.closest(profile[key])
                            for key in ('body','wing','skin','beak','leg','dark')}

        def closest(self,rgb):
            target=np.array(rgb,float)
            return self.source[np.argmin(np.sum((self.source-target)**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def feather(self,root,tip,width,kind='wing'):
            root,tip=np.array(root,float),np.array(tip,float)
            side=np.array([width,0,0],float)
            ridge=np.array([0,width*.18,0],float)
            points=[root-side,root+side,tip,root+ridge]
            for face in ((0,1,2),(0,3,1),(0,2,3),(1,3,2)):
                self.face(np.array([points[i] for i in face]),(0,0),kind)

        def beak(self,center,size,hook=False):
            center=np.array(center,float)
            tip=center+np.array([0,-size[1]*.15,size[2]])
            if hook:
                tip+=np.array([0,-size[1]*.55,-size[2]*.06])
            self.tube([center,center+[0,0,size[2]*.52],tip],
                       [size[0],size[0]*.62,.001],'beak',12)

    return {oid:partial(build,sculpt_type=BirdSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def body_and_head(s,shape,phase):
    sway=(0.,1.,-1.)[phase%3]
    if shape=='flamingo':
        s.ellipsoid((0,.50,-.08),(.145,.155,.255),'body',30,18)
        s.ellipsoid((0,1.035,.275),(.080,.075,.105),'body',24,14)
        s.tube(neck_path(shape),[.055,.047,.041,.046,.055],'body',18)
        s.beak((0,1.025,.345),(.052,.050,.150),True)
        s.ellipsoid((0,1.045,.302),(.056,.041,.061),'skin',18,10)
        wing_center=(0,.53,-.055)
        wing_radius=(.148,.090,.205)
    elif shape=='parrot':
        s.ellipsoid((0,.335,-.05),(.165,.205,.245),'body',30,18)
        s.tube(neck_path(shape),[.105,.095,.085],'body',18)
        s.ellipsoid((0,.555,.292),(.112,.118,.118),'body',26,16)
        s.beak((0,.558,.365),(.080,.080,.132),True)
        wing_center=(0,.37,-.015)
        wing_radius=(.168,.125,.225)
    elif shape=='terror':
        s.ellipsoid((0,.445,-.10),(.255,.285,.390),'body',34,20)
        s.tube(neck_path(shape),[.155,.125,.105],'skin',20)
        s.ellipsoid((0,.835,.335),(.155,.145,.195),'body',28,16)
        s.beak((0,.835,.455),(.130,.120,.275),True)
        wing_center=(0,.49,-.055)
        wing_radius=(.235,.145,.285)
    else:
        s.ellipsoid((0,.285,-.06),(.180,.205,.270),'body',30,18)
        s.tube(neck_path(shape),[.100,.085,.072],'body',18)
        s.ellipsoid((0,.485,.270),(.100,.105,.115),'body',24,14)
        s.beak((0,.475,.345),(.060,.050,.115))
        wing_center=(0,.315,-.025)
        wing_radius=(.180,.125,.235)

    # Folded wings are separate volumes, offset enough to read from every facing.
    for side in (-1,1):
        c=np.array(wing_center)+[side*wing_radius[0]*.58,sway*.008,-.018]
        s.ellipsoid(c,(wing_radius[0]*.52,wing_radius[1],wing_radius[2]),'wing',26,14)
        eye_y={'flamingo':1.065,'parrot':.585,'terror':.875,'chicken':.515}[shape]
        eye_z={'flamingo':.337,'parrot':.350,'terror':.430,'chicken':.335}[shape]
        eye_x={'flamingo':.064,'parrot':.094,'terror':.132,'chicken':.082}[shape]
        s.ellipsoid((side*eye_x,eye_y,eye_z),(.012,.014,.011),'dark',12,8)

    if shape=='chicken':
        for y,z,r in ((.590,.250,.035),(.625,.225,.031),(.647,.190,.027)):
            s.ellipsoid((0,y,z),(r,r*.72,r*.62),'skin',14,8)
        for side in (-1,1):
            s.ellipsoid((side*.040,.420,.360),(.030,.055,.025),'skin',14,8)
    elif shape=='flamingo':
        s.ellipsoid((0,1.028,.420),(.049,.024,.040),'dark',16,8)

    # Tail feathers are real tapered solids, not a painted rear wedge.
    tail_specs={
        'chicken':(3,-.31,.16,.18),
        'flamingo':(4,-.31,.16,.22),
        'parrot':(5,-.30,.22,.48),
        'terror':(5,-.47,.24,.31),
    }
    count,z0,width,length=tail_specs[shape]
    for i in range(count):
        x=(i-(count-1)/2)*width/max(1,count-1)
        s.feather((x*.55,.37 if shape!='terror' else .50,z0),
                  (x+sway*.012,.26 if shape!='parrot' else .18,z0-length),
                  width*.42,'wing')


def build(views,phase,*,sculpt_type,profile):
    s=sculpt_type(views,profile)
    shape=profile['shape']
    body_and_head(s,shape,phase)
    for side in (-1,1):
        joints=leg_joints(side,phase,shape)
        thickness=.018 if shape in ('flamingo','parrot') else (.026 if shape=='chicken' else .044)
        s.tube(joints,[thickness,thickness*.82,thickness*.65],'leg',12)
        for path,radius in toe_paths(joints[-1],shape):
            s.tube(path,[radius,radius*.62,.001],'leg',8)
    return s.result()

