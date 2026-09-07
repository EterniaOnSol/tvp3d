"""Three distinct arthropod anatomies using only their original sprite RGB."""
from functools import partial
import math
import numpy as np

PROFILES = {
    43: dict(shape='scorpion', pairs=4, body=(109,77,33), light=(157,118,65),
             dark=(32,24,12), limb=(85,61,28), accent=(140,105,51)),
    45: dict(shape='bug', pairs=3, body=(86,32,15), light=(136,132,121),
             dark=(26,21,15), limb=(45,39,25), accent=(111,159,40)),
    124: dict(shape='centipede', pairs=12, body=(126,50,4), light=(233,170,12),
              dark=(37,22,4), limb=(146,83,3), accent=(62,132,15)),
}


def centipede_center(pair,phase):
    z = .43-pair*.079
    return np.array([.026*math.sin(pair*.63+phase*math.tau/3),.082,z])


def leg_joints(side,pair,phase,shape):
    step = (0.,1.,-1.)[phase%3]
    if shape=='centipede':
        center = centipede_center(pair,phase)
        swing = side*math.sin(pair*.63+phase*math.tau/3)
        return np.array([center+[side*.031,-.006,0],
                         center+[side*.093,-.033,.009+swing*.016],
                         [center[0]+side*.128,.008+max(0,swing)*.020,center[2]-.023+swing*.026]])
    swing = side*step*(1 if pair%2==0 else -1)
    if shape=='bug':
        z = .09-pair*.089
        return np.array([[side*.066,.097,z],[side*.132,.085,z+.01],
                         [side*.184,.008+max(0,swing)*.023,z+.035+swing*.025]])
    z = .16-pair*.097
    return np.array([[side*.10,.116,z],[side*.193,.137,z+.02],
                     [side*.268,.049,z+.016+swing*.02],
                     [side*.31,.008+max(0,swing)*.024,z-.016+swing*.036]])


def tail_points(phase):
    sway = (0.,1.,-1.)[phase%3]*.022
    return np.array([[0,.13,-.29],[sway,.19,-.39],[sway*1.4,.29,-.415],
                     [sway*1.5,.40,-.37],[sway,.51,-.285],[sway*.5,.55,-.17],
                     [0,.49,-.105]])


def make_generators(base):
    class ArthropodSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source = np.unique(self.palette,axis=0).astype(float)
            self.materials = {k:self.closest(profile[k]) for k in ('body','light','dark','limb','accent')}

        def closest(self,rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def plate(self,center,radius,pattern='ridge'):
            start = len(self.vertices)
            self.ellipsoid(center,radius,'body',24,12)
            for i in range(start,len(self.vertices)):
                x,y,z = (self.vertices[i]-center)/radius
                if y<0:
                    kind='dark'
                elif pattern=='bug':
                    kind='light' if abs(x)<.25 and y>.5 else 'body'
                else:
                    kind='light' if y>.65 and abs(z)<.46 else 'body'
                self.colors[i]=self.closest(self.materials['body']*.4+self.materials['light']*.6) if kind=='light' and pattern=='bug' else self.materials[kind]
    return {oid:partial(build,sculpt_type=ArthropodSculpt,profile=profile)
            for oid,profile in PROFILES.items()}


def scorpion(s,phase):
    s.ellipsoid((0,.112,-.048),(.116,.065,.254),'dark',24,12)
    for j in range(6):
        z = -.26+j*.059
        w = .077+.035*math.sin((j+1)/7*math.pi)
        s.plate(np.array([0,.135,z]),np.array([w,.063,.039]))
    s.plate(np.array([0,.143,.14]),np.array([.119,.066,.106]))
    for side in (-1,1):
        for pair in range(4):
            joints = leg_joints(side,pair,phase,'scorpion')
            s.tube(joints,[.015,.017,.009,.001],'limb',10)
        # Pedipalps terminate in open, opposed fingers; eight walking legs remain separate.
        swing = side*(0.,1.,-1.)[phase%3]*.018
        s.tube([(side*.091,.126,.192),(side*.19,.102,.251),
                (side*.243,.124,.355+swing)],[.026,.031,.026],'body',12)
        s.plate(np.array([side*.239,.135,.392+swing]),np.array([.061,.038,.069]))
        for finger in (-1,1):
            s.tube([(side*.239+finger*.032,.14,.422+swing),
                    (side*.239+finger*.05,.145,.491+swing),
                    (side*.239+finger*.007,.141,.527+swing)],
                   [.021,.012,.001],'body',10)
        s.ellipsoid((side*.035,.205,.19),(.009,.008,.010),'dark',12,8)
        s.tube([(side*.023,.111,.232),(side*.03,.105,.266),(side*.008,.102,.275)],
               [.012,.009,.001],'dark',8)
    tail=tail_points(phase)
    s.tube(tail,[.027,.026,.023,.021,.020,.018,.015],'dark',12)
    for j in range(len(tail)-1):
        a,b=tail[j],tail[j+1]
        radius=.044-j*.003
        s.tube([a+(b-a)*.12,(a+b)/2,a+(b-a)*.88],[radius*.78,radius,radius*.78],'body',12)
    s.ellipsoid(tail[-1],(.037,.040,.035),'body',18,10)
    s.tube([tail[-1],tail[-1]+[0,-.037,.042],tail[-1]+[0,-.108,.052]],
           [.019,.013,.0007],'dark',12)


def bug(s,phase):
    s.ellipsoid((0,.093,-.035),(.103,.053,.174),'dark',24,12)
    for side in (-1,1):
        s.plate(np.array([side*.051,.132,-.06]),np.array([.050,.089,.154]),'bug')
        for pair in range(3):
            s.tube(leg_joints(side,pair,phase,'bug'),[.013,.012,.001],'limb',10)
    s.plate(np.array([0,.125,.112]),np.array([.084,.052,.065]),'bug')
    s.ellipsoid((0,.111,.179),(.058,.036,.041),'body',20,12)
    for side in (-1,1):
        s.ellipsoid((side*.047,.133,.193),(.010,.010,.011),'dark',12,8)
        s.tube([(side*.035,.136,.201),(side*.079,.177,.25),(side*.096,.231,.245)],
               [.007,.006,.003],'accent',10)
        s.ellipsoid((side*.096,.231,.245),(.009,.012,.009),'accent',12,8)
        s.tube([(side*.020,.090,.207),(side*.027,.091,.229),(side*.007,.088,.235)],
               [.008,.006,.001],'dark',8)


def centipede(s,phase):
    centers=np.array([centipede_center(j,phase) for j in range(12)])
    s.tube(centers,[.028]*12,'dark',12)
    for j,center in enumerate(centers):
        width=.046 if j<10 else .046-(j-9)*.005
        s.plate(center,np.array([width,.041,.045]))
        for side in (-1,1):
            joints=leg_joints(side,j,phase,'centipede')
            s.tube(joints,[.009,.008,.0008],'limb',8)
            s.ellipsoid(center+[side*.035,.017,.005],(.013,.014,.018),'light',10,6)
    head=centers[0]+[0,.002,.063]
    s.plate(head,np.array([.059,.047,.053]))
    for side in (-1,1):
        s.ellipsoid(head+[side*.045,.020,.028],(.008,.009,.008),'dark',10,6)
        s.tube([head+[side*.034,.014,.043],head+[side*.066,.034,.10],head+[side*.077,.055,.144]],
               [.008,.006,.001],'accent',8)
        end=centers[-1]
        s.tube([end+[side*.024,0,-.029],end+[side*.075,.025,-.092],end+[side*.081,.04,-.13]],
               [.010,.007,.001],'accent',8)


BUILDERS={'scorpion':scorpion,'bug':bug,'centipede':centipede}


def build(views,phase,*,sculpt_type,profile):
    sculpt=sculpt_type(views,profile)
    BUILDERS[profile['shape']](sculpt,phase)
    # generar.py owns the shared, uniform scale across every animation frame.
    return sculpt.result()