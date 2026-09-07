"""Open skeletal anatomy, shared by the ivory and red original appearances."""
from functools import partial
import math
import numpy as np

PROFILES={
    33:dict(bone=(168,163,120),joint=(108,99,64),light=(209,207,170),dark=(24,24,13)),
    37:dict(bone=(174,46,41),joint=(99,21,19),light=(226,115,110),dark=(35,5,7)),
}


def leg_joints(side,phase):
    step=(0.,1.,-1.)[phase%3]*side
    return np.array([[side*.071,.63,0],[side*.084,.338,.025+step*.064],
                     [side*.087,.066+max(0,step)*.047,.012+step*.096],
                     [side*.088,.019+max(0,step)*.047,.084+step*.096]])


def arm_joints(side,phase):
    step=(0.,1.,-1.)[phase%3]*side
    return np.array([[side*.166,.965,-.004],[side*.218,.795,.018-step*.063],
                     [side*.254,.671,.057-step*.10]])


def ribs(side,pair):
    y=.934-pair*.045
    width=(.11,.142,.157,.158,.145,.122)[pair]
    # Back-to-front arc: empty thoracic cavity, with a sternum only at the front.
    return np.array([[side*.018,y,-.047],[side*width*.77,y+.009,-.06],
                     [side*width,y-.013,.005],[side*width*.78,y-.038,.066],
                     [side*.012,y-.036,.082]])


def make_generators(base):
    class BoneSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source=np.unique(self.palette,axis=0).astype(float)
            self.materials={k:self.closest(profile[k]) for k in ('bone','joint','light','dark')}

        def closest(self,color):
            return self.source[np.argmin(np.sum((self.source-np.array(color))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='bone',direction=2):
            return self.materials.get(kind,self.materials['bone'])

        def long_bone(self,a,b,width):
            a,b=np.array(a),np.array(b)
            self.tube([a,(a+b)/2,b],
                      [width*1.17,width*.72,width*1.10],'bone',8 if width<.012 else 10)
            if width>=.008:
                for p in (a,b):
                    self.ellipsoid(p,(width*1.14,width*1.05,width*1.14),'bone',10,6)
    return {oid:partial(build,sculpt_type=BoneSculpt,profile=profile) for oid,profile in PROFILES.items()}


def skull(s):
    # Cranial vault ends above the jaw; the mouth is an actual open gap.
    s.ellipsoid((0,1.175,.006),(.103,.109,.088),'bone',32,20)
    s.ellipsoid((0,1.091,.032),(.077,.030,.056),'bone',24,14)
    for side in (-1,1):
        s.ellipsoid((side*.044,1.16,.084),(.030,.034,.008),'dark',22,14)
        s.tube([(side*.016,1.19,.082),(side*.041,1.202,.084),(side*.075,1.18,.067)],
               [.010,.012,.009],'bone',10)
        s.long_bone([side*.075,1.132,.047],[side*.060,1.092,.064],.011)
    # Nasal aperture on the upper maxilla, below the orbital cavities.
    s.face([[-.013,1.105,.087],[.013,1.105,.087],[0,1.137,.088]],(0,0),'dark')
    s.tube([[-.073,1.096,.012],[-.066,1.035,.054],[0,1.021,.080],
            [.066,1.035,.054],[.073,1.096,.012]],[.011,.013,.014,.013,.011],'bone',12)
    for x in np.linspace(-.05,.05,7):
        z=.080-abs(x)*.19
        s.ellipsoid((x,1.061,z),(.0053,.010,.007),'light',10,8)
        s.ellipsoid((x,1.041,z),(.0053,.008,.006),'bone',10,8)


def pelvis(s):
    for side in (-1,1):
        loop=[]
        for t in np.linspace(0,math.tau,15):
            loop.append([side*(.065+.043*math.cos(t)),.633+.052*math.sin(t),.003+.011*math.cos(t)])
        s.tube(loop,[.017]*len(loop),'bone',10)
        s.long_bone([side*.10,.669,-.013],[side*.023,.683,-.034],.023)
        s.long_bone([side*.088,.608,.01],[side*.019,.585,.033],.013)
    s.long_bone([-.018,.59,.034],[.018,.59,.034],.013)


def hands(s,side,wrist,phase):
    # A palm made from metacarpals, with separate hooked phalanges.
    for finger in range(4):
        root=wrist+[side*(finger-1.5)*.011,-.005,0]
        knuckle=root+[side*.006,-.041,.008]
        tip=knuckle+[side*.004,-.024-(.006 if finger in (1,2) else 0),.024]
        s.long_bone(root,knuckle,.0048)
        s.tube([knuckle,tip,tip+[0,.004,.014]],[.0048,.0035,.001],'bone',8)
    s.tube([wrist+[side*-.018,0,.005],wrist+[side*-.041,-.018,.025],
            wrist+[side*-.038,-.032,.044]],[.007,.005,.001],'bone',8)


def build(views,phase,*,sculpt_type,profile):
    s=sculpt_type(views,profile)
    # Individual vertebrae and connecting core leave the torso transparent.
    s.tube([[0,.61,-.035],[0,.80,-.05],[0,.965,-.038],[0,1.083,-.018]],
           [.012,.012,.012,.011],'joint',10)
    for y in np.linspace(.655,1.052,12):
        z=-.046 if y<.97 else -.027
        s.ellipsoid((0,y,z),(.022,.012,.019),'bone',14,8)
    for side in (-1,1):
        for pair in range(6):
            s.tube(ribs(side,pair),[.009,.010,.010,.009,.006],'bone',10)
        s.long_bone([side*.013,.964,.035],[side*.164,.965,-.004],.012)
        s.ellipsoid((side*.09,.918,-.064),(.040,.055,.008),'bone',18,12)
        arm=arm_joints(side,phase)
        s.long_bone(arm[0],arm[1],.017)
        for offset in (-.009,.009):
            s.long_bone(arm[1]+[0,0,offset],arm[2]+[0,0,offset],.009)
        hands(s,side,arm[-1],phase)
        leg=leg_joints(side,phase)
        s.long_bone(leg[0],leg[1],.021)
        s.ellipsoid(leg[1]+[0,0,.018],(.018,.021,.01),'light',14,10)
        for offset in (-.009,.009):
            s.long_bone(leg[1]+[side*offset,0,0],leg[2]+[side*offset,0,0],.010)
        s.long_bone(leg[2],leg[3],.013)
        for toe in range(5):
            a=leg[-1]+[(toe-2)*.010,0,-.013]
            b=a+[0,0,.046-abs(toe-2)*.006]
            s.long_bone(a,b,.0045)
    s.long_bone([0,.913,.082],[0,.754,.082],.011)
    pelvis(s)
    skull(s)
    return s.result()