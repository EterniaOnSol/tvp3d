"""Demon 35: compact red brute sculpted against the original NESW sprites."""
import numpy as np


def leg_joints(side, phase):
    step = (0., 1., -1.)[phase % 3] * side
    return np.array([[side*.23,.65,-.12], [side*.30,.37,.035+step*.065],
                     [side*.29,.13,-.04+step*.12],
                     [side*.30,.065+max(0.,step)*.065,.095+step*.12]])


def make_generator(base):
    class DemonSculpt(base):
        def __init__(self, views):
            super().__init__(views)
            source = np.unique(self.palette, axis=0).astype(float)
            targets = dict(body=(132,17,3),light=(193,33,5),ridge=(77,9,3),
                           dark=(35,13,3),horn=(235,207,133),claw=(208,158,42),
                           eye=(228,240,47),mouth=(71,24,7),green=(77,162,7),glow=(207,226,87))
            self.materials = {k:source[np.argmin(np.sum((source-v)**2,axis=1))].astype('u1')
                              for k,v in targets.items()}
        def pixel(self, uv, kind='body', direction=2):
            return self.materials.get(kind,self.materials['body'])
    def build(views, phase):
        s = DemonSculpt(views)
        step = (0.,1.,-1.)[phase%3]
        # Neck disappears into the huge trapezius: face projects ahead of torso.
        s.ellipsoid((0,.91,-.08),(.345,.43,.245),'body',32,22)
        s.ellipsoid((0,1.15,-.15),(.365,.29,.255),'body',32,20)
        s.ellipsoid((0,.68,-.12),(.285,.205,.225),'ridge',28,18)
        s.ellipsoid((0,.87,.105),(.242,.265,.143),'body',28,18)
        for side in (-1,1):
            # Pectorals taper toward a narrow central seam; abdomen stays red.
            s.ellipsoid((side*.152,1.13,.145),(.178,.124,.092),'light',24,16)
            for y,w in [(.985,.105),(.883,.092),(.793,.077)]:
                s.ellipsoid((side*w*.65,y,.218),(w,.057,.029),'body',20,12)
            shoulder=np.array([side*.365,1.22,-.065])
            elbow=np.array([side*.53,.88,.055-step*side*.04])
            wrist=np.array([side*.46,.54,.22-step*side*.08])
            s.tube([shoulder,elbow,wrist],[.202,.144,.097],'body',20)
            s.ellipsoid(shoulder,(.219,.22,.205),'light',28,18)
            s.ellipsoid(elbow,(.155,.18,.151),'body',24,16)
            s.ellipsoid(wrist+[0,-.06,.035],(.121,.135,.086),'body',22,14)
            for finger in range(3):
                a=wrist+[(finger-1)*.072,-.095,.06]
                b=a+[0,-.092,.028]
                s.tube([a,b,b+[0,-.019,.052]],[.031,.025,.018],'body',10)
                s.tube([b+[0,-.012,.032],b+[0,-.025,.08],b+[0,-.014,.112]],
                       [.021,.014,.001],'claw',10)
            a=wrist+[-side*.085,-.02,.05]
            s.tube([a,a+[-side*.065,-.063,.058],a+[-side*.03,-.11,.075]],
                   [.04,.028,.002],'claw',12)
            # Ivory spur curves around the outer forearm as in the side sprites.
            s.tube([wrist+[side*.075,.07,-.025],elbow+[side*.07,-.015,-.055],
                    elbow+[side*.13,.075,-.065]], [.055,.028,.001],'horn',12)
            leg=leg_joints(side,phase)
            s.ellipsoid(leg[0],(.167,.22,.185),'body',24,16)
            s.tube(leg[:3],[.147,.12,.075],'body',18)
            s.tube(leg[2:],[.075,.083],'body',14)
            s.ellipsoid(leg[-1],(.113,.065,.153),'body',22,14)
            for toe in (-1,0,1):
                a=leg[-1]+[toe*.071,-.025,.107-abs(toe)*.018]
                s.tube([a,a+[toe*.008,-.016,.067],a+[toe*.012,-.025,.105]],
                       [.035,.022,.001],'claw',12)
        # Flattened demonic skull, muzzle and clearly separated lower jaw.
        s.ellipsoid((0,1.38,.10),(.197,.194,.156),'body',30,20)
        s.ellipsoid((0,1.305,.22),(.149,.097,.132),'body',26,16)
        s.ellipsoid((0,1.255,.303),(.133,.042,.052),'green',24,12)
        s.ellipsoid((0,1.262,.35),(.09,.02,.012),'glow',22,12)
        s.ellipsoid((0,1.21,.268),(.125,.045,.087),'green',24,14)
        s.tube([(0,1.203,.25),(0,1.13,.225)],[.068,.004],'green',14)
        for side in (-1,1):
            s.ellipsoid((side*.083,1.402,.245),(.053,.033,.019),'dark',18,12)
            s.ellipsoid((side*.083,1.404,.263),(.032,.016,.007),'eye',16,10)
            s.tube([(side*.015,1.426,.25),(side*.084,1.453,.239),(side*.15,1.418,.201)],
                   [.029,.036,.023],'ridge',14)
            s.ellipsoid((side*.034,1.335,.33),(.012,.009,.007),'dark',12,8)
            # Thick pale horns curl out, down beside the cheek and up at the tip.
            s.tube([(side*.142,1.487,.045),(side*.226,1.50,.075),
                    (side*.26,1.405,.16),(side*.25,1.307,.224),
                    (side*.19,1.315,.281),(side*.17,1.39,.288)],
                   [.039,.036,.031,.025,.015,.001],'horn',16)
            for x in (.048,.099):
                s.tube([(side*x,1.278,.342),(side*x,1.231,.35)], [.015,.001],'horn',10)
        # Red crown and dorsal fins read strongly from north and side views.
        for z,y in [(.13,1.52),(-.03,1.54),(-.20,1.40),(-.32,1.23),(-.335,1.03),(-.30,.84)]:
            s.tube([(0,y-.05,z),(0,y+.067,z-.06),(0,y+.12,z-.16)],
                   [.068,.036,.001],'ridge',12)
        for side in (-1,1):
            for y,z in [(1.22,-.28),(1.07,-.31),(.91,-.30)]:
                s.tube([(side*.16,y,z),(side*.28,y-.02,z-.095),(side*.37,y+.03,z-.17)],
                       [.065,.035,.001],'body',12)
        # Long whiplike tail runs behind the body and curls beside one hip.
        tail=[(0,.68,-.25),(.10,.43,-.45),(.30,.24,-.60),
              (.59+step*.025,.19,-.56),(.73+step*.035,.31,-.37),
              (.78+step*.025,.52,-.18),(.73,.72,-.09)]
        s.tube(tail,[.104,.086,.061,.044,.03,.018,.001],'body',18)
        return s.result()
    return build
