"""Antlered deer and compact rabbit; original RGB and independent size targets."""
from functools import partial
import math
import numpy as np

PROFILES={
    31:dict(shape='deer',body=(135,58,17),light=(200,145,67),dark=(34,20,9),
            inner=(106,55,21),bone=(92,72,36)),
    74:dict(shape='rabbit',body=(103,72,52),light=(151,120,89),dark=(34,22,15),
            inner=(125,83,62),bone=(94,67,49)),
}


def leg_joints(side,front,phase,rabbit=False):
    step=(0.,1.,-1.)[phase%3]
    if rabbit:
        lift=.025 if front and phase==1 else (.018 if not front and phase==2 else 0)
        z=.16 if front else -.12
        return np.array([[side*.07,.17,z],[side*.105,.075+lift,z-.025],
                         [side*.105,.018+lift,z+.066+step*.012]])
    swing=side*step*(1 if front else -1)
    z=.18 if front else -.25
    return np.array([[side*.065,.59,z],[side*.117,.31,z+(.02 if front else .075)],
                     [side*.125,.13,z+swing*.026],
                     [side*.125,.025+max(0,swing)*.046,z+.045+swing*.055]])


def antler_branches(side):
    main=np.array([[side*.05,.918,.36],[side*.092,1.065,.27],
                   [side*.145,1.164,.20],[side*.19,1.247,.165]])
    return [main,np.array([main[1],[side*.064,1.115,.354],[side*.051,1.165,.362]]),
            np.array([main[2],[side*.209,1.208,.26],[side*.239,1.255,.27]])]


def make_generators(base):
    class ForestSculpt(base):
        def __init__(self,views,profile):
            super().__init__(views)
            self.source=np.unique(self.palette,axis=0).astype(float)
            self.materials={k:self.closest(profile[k]) for k in ('body','light','dark','inner','bone')}
            self.materials['tail']=self.closest((235,235,210))

        def closest(self,rgb):
            return self.source[np.argmin(np.sum((self.source-np.array(rgb))**2,axis=1))].astype('u1')

        def pixel(self,uv,kind='body',direction=2):
            return self.materials.get(kind,self.materials['body'])

        def ear(self,base,tip,width,kind='body'):
            # Closed, flattened leaf aligned from root to tip, with an inset inner face.
            a,b=np.array(base),np.array(tip)
            center=(a+b)/2
            axis=(b-a)/np.linalg.norm(b-a)
            cross=np.cross(axis,[0,0,1.]); cross/=np.linalg.norm(cross)
            depth=np.cross(cross,axis)
            rotation=np.column_stack((cross,axis,depth))
            for inner in (False,True):
                start=len(self.vertices)
                self.ellipsoid((0,0,.012 if inner else 0),
                               (width*(.55 if inner else 1),np.linalg.norm(b-a)*(.37 if inner else .5),.004 if inner else .012),
                               'inner' if inner else kind,20,14)
                for i in range(start,len(self.vertices)):
                    self.vertices[i]=center+rotation@self.vertices[i]
                    self.normals[i]=rotation@self.normals[i]
    return {oid:partial(build,sculpt_type=ForestSculpt,profile=profile) for oid,profile in PROFILES.items()}


def deer(s,phase):
    s.ellipsoid((0,.565,-.05),(.152,.164,.325),'body',32,18)
    s.ellipsoid((0,.51,.17),(.117,.12,.127),'light',24,14)
    s.tube([(0,.56,.15),(0,.68,.237),(0,.80,.29),(0,.87,.331)],
           [.108,.098,.077,.063],'body',24)
    s.ellipsoid((0,.879,.389),(.076,.08,.13),'body',26,16)
    s.tube([(0,.87,.439),(0,.835,.514),(0,.811,.575)],[.054,.043,.028],'body',16)
    s.ellipsoid((0,.808,.586),(.03,.025,.018),'dark',16,10)
    s.ellipsoid((0,.788,.525),(.033,.01,.066),'light',18,10)
    for side in (-1,1):
        s.ear([side*.05,.9,.32],[side*.19,.988,.292],.033)
        s.ellipsoid((side*.065,.90,.431),(.011,.013,.014),'dark',14,8)
        s.ellipsoid((side*.068,.905,.434),(.003,.003,.004),'light',8,6)
        for i,branch in enumerate(antler_branches(side)):
            radii=[.014,.012,.009,.001] if i==0 else [.008,.005,.001]
            s.tube(branch,radii,'bone',10)
        for front in (True,False):
            joints=leg_joints(side,front,phase)
            s.tube(joints,[.044,.027,.017,.023],'body',12)
            for toe in (-1,1):
                s.ellipsoid(joints[-1]+[toe*.013,0,.009],(.011,.025,.032),'dark',12,8)
        # Small pale flank markings follow the curved coat surface.
        for z in (-.22,-.12,-.02,.07):
            x=side*.139*math.sqrt(max(.2,1-((z+.05)/.325)**2))
            s.ellipsoid((x,.603,z),(.007,.013,.018),'light',12,8)
    sway=(0.,1.,-1.)[phase%3]*.015
    s.tube([(0,.598,-.32),(sway,.634,-.403),(sway,.69,-.451)],
           [.031,.040,.001],'tail',14)
    s.tube([(0,.60,-.341),(sway,.64,-.418),(sway,.685,-.451)],
           [.020,.026,.001],'light',12)


def rabbit(s,phase):
    bob=(0.,-.006,.006)[phase%3]
    s.ellipsoid((0,.163+bob,-.05),(.122,.112,.194),'body',28,18)
    s.ellipsoid((0,.148+bob,-.151),(.132,.123,.131),'body',26,16)
    s.ellipsoid((0,.228+bob,.145),(.091,.086,.102),'body',26,16)
    s.ellipsoid((0,.196+bob,.226),(.061,.044,.057),'light',22,12)
    s.ellipsoid((0,.203+bob,.278),(.017,.012,.010),'inner',14,8)
    for side in (-1,1):
        sway=(0.,1.,-1.)[phase%3]*.014
        s.ear([side*.044,.278+bob,.122],[side*.077+sway,.493+bob,.083],.029)
        s.ellipsoid((side*.078,.244+bob,.196),(.013,.017,.015),'dark',14,10)
        s.ellipsoid((side*.083,.25+bob,.203),(.0035,.004,.003),'light',8,6)
        for front in (True,False):
            joints=leg_joints(side,front,phase,True)
            if not front:
                s.ellipsoid((side*.09,.126+bob,-.138),(.075,.092,.108),'body',22,14)
            s.tube(joints,[.027,.022,.018],'body',12)
            s.ellipsoid(joints[-1],(.029,.018,.052 if not front else .035),'light',18,10)
        for dz in (-.018,.012):
            s.tube([(side*.038,.205+bob,.248),(side*.105,.21+bob,.255+dz)],
                   [.0018,.0005],'bone',6)
    s.ellipsoid((0,.177+bob,-.265),(.038,.043,.04),'light',20,12)


BUILDERS={'deer':deer,'rabbit':rabbit}


def build(views,phase,*,sculpt_type,profile):
    s=sculpt_type(views,profile)
    BUILDERS[profile['shape']](s,phase)
    return s.result()