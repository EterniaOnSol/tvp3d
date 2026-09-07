"""Hunched, unarmed trolls derived from the three original sprite palettes."""
from functools import partial
import numpy as np

PROFILES = {
    15: dict(body=(113,55,16), light=(157,87,25), dark=(49,25,9), eye=(230,183,29), height=1., breadth=1.),
    53: dict(body=(38,166,177), light=(98,224,229), dark=(13,70,81), eye=(239,91,57), height=1.05, breadth=1.),
    76: dict(body=(49,106,12), light=(85,153,20), dark=(21,49,6), eye=(222,160,26), height=.94, breadth=1.05),
}


def leg_joints(side, phase):
    step=(0.,1.,-1.)[phase%3]*side
    lift=max(0.,step)*.055
    return np.array([[side*.105,.48,-.025], [side*.135,.265,.065+step*.055],
                     [side*.15,.085,.005+step*.10], [side*.15,.045+lift,.09+step*.10]])


def arm_joints(side, phase):
    step=(0.,1.,-1.)[phase%3]*side
    return np.array([[side*.19,.84,-.025], [side*.29,.62,.045-step*.035],
                     [side*.32,.42,.10-step*.07]])


def make_generators(base):
    class TrollSculpt(base):
        def __init__(self, views, profile):
            super().__init__(views)
            source=np.unique(self.palette,axis=0).astype(float)
            self.materials={k:source[np.argmin(np.sum((source-np.array(profile[k]))**2,axis=1))].astype('u1')
                            for k in ('body','light','dark','eye')}
        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])
    return {oid:partial(build,sculpt_type=TrollSculpt,profile=p) for oid,p in PROFILES.items()}


def build(views, phase, *, sculpt_type, profile):
    s=sculpt_type(views,profile)
    # Overlapping masses merge neck, back and belly into a stooped silhouette.
    s.ellipsoid((0,.65,-.025),(.195,.265,.135),'body',28,18)
    s.ellipsoid((0,.83,-.06),(.223,.165,.148),'body',28,18)
    s.ellipsoid((0,.60,.064),(.15,.165,.095),'body',24,16)
    s.ellipsoid((0,.465,-.026),(.153,.108,.118),'body',24,14)
    for side in (-1,1):
        arm=arm_joints(side,phase)
        s.tube(arm,[.107,.087,.053],'body',16)
        s.ellipsoid(arm[0],(.119,.125,.119),'body',22,14)
        wrist=arm[-1]
        s.ellipsoid(wrist,(.057,.055,.057),'body',16,10)
        s.ellipsoid(wrist+[0,-.039,.012],(.06,.071,.039),'body',18,12)
        for finger in range(4):
            x=(finger-1.5)*.027
            a=wrist+[x,-.065,.02]
            s.tube([a,a+[0,-.045,.015],a+[0,-.057,.039]], [.014,.012,.009],'body',8)
        s.tube([wrist+[-side*.045,-.012,.01],wrist+[-side*.077,-.047,.039],
                wrist+[-side*.058,-.071,.055]],[.021,.017,.011],'body',10)
        leg=leg_joints(side,phase)
        s.tube(leg[:3],[.09,.074,.046],'body',16)
        # Ankle follows the lifted foot; all toes share its ground clearance.
        s.tube([leg[2],leg[3]],[.046,.047],'body',12)
        s.ellipsoid(leg[2],(.049,.052,.049),'body',16,10)
        s.ellipsoid(leg[-1],(.065,.045,.096),'body',20,12)
        for toe in range(3):
            s.ellipsoid(leg[-1]+[(toe-1)*.037,-.013,.073-abs(toe-1)*.012],
                        (.024,.026,.037),'body',12,8)
        # Broad pectorals and shoulder creases, embedded in the upper torso.
        s.ellipsoid((side*.09,.80,.092),(.096,.067,.027),'light',22,12)
    # Neck leans forward; face projects beyond the chest.
    s.ellipsoid((0,.92,.026),(.125,.123,.107),'body',24,16)
    s.ellipsoid((0,1.005,.09),(.124,.135,.107),'body',28,20)
    s.ellipsoid((0,.939,.164),(.089,.065,.067),'body',24,16)
    for side in (-1,1):
        s.ellipsoid((side*.048,1.014,.183),(.028,.02,.012),'dark',18,12)
        s.ellipsoid((side*.048,1.014,.194),(.013,.011,.006),'eye',14,10)
        s.tube([[side*.016,1.041,.183],[side*.048,1.048,.184],[side*.087,1.028,.16]],
               [.018,.023,.018],'body',12)
        s.ellipsoid((side*.112,1.015,.079),(.032,.05,.027),'body',18,12)
        s.ellipsoid((side*.127,1.015,.097),(.015,.028,.008),'dark',14,10)
        s.ellipsoid((side*.069,.97,.174),(.038,.035,.024),'body',18,12)
    s.ellipsoid((0,.997,.198),(.032,.045,.034),'body',20,14)
    for side in (-1,1):
        s.ellipsoid((side*.017,.978,.224),(.009,.006,.004),'dark',12,8)
    s.tube([[-.05,.925,.207],[0,.919,.225],[.05,.925,.207]],[.005,.007,.005],'dark',10)
    s.ellipsoid((0,.907,.189),(.059,.019,.033),'body',18,12)
    positions,normals,colors=s.result()
    scale=np.array([profile['breadth'],profile['height'],1.],dtype='f4')
    positions*=scale
    normals/=scale
    normals/=np.linalg.norm(normals,axis=1)[:,None]
    return positions,normals,colors
