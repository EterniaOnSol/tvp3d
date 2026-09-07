"""Authored anatomy for rat and dragon families, textured with source pixels."""
import math
import numpy as np


class Sculpt:
    def __init__(self, views):
        self.vertices, self.normals, self.colors = [], [], []
        self.views = views
        rgba = views[2]['rgba']
        self.palette = rgba[rgba[:,:,3] >= 128,:3]
        self.phase = 0.
        self._sample_cache = {}
        self._palette_cache = {}

    def pixel(self, uv, kind='body', direction=2):
        # All colors are actual RGB triplets from this creature's sprite.
        view = self.views[direction]
        image = view['colors']
        h,w = image.shape[:2]
        x0,y0,x1,y1 = view['bounds']
        sx = int(x0+(x1-x0)*(.33+uv[0]*.34))
        sy = int(y0+(y1-y0)*(.32+uv[1]*.38))
        key = (kind,direction,sx,sy)
        if key in self._sample_cache:
            return self._sample_cache[key]
        rgb = self.palette.astype(float)
        r,g,b = rgb.T
        bright = rgb.mean(axis=1)
        if kind == 'eye':
            selected = rgb[bright <= np.percentile(bright, 6)]
        elif kind == 'claw':
            selected = rgb[(r > g*.9) & (r > b*1.4) & (bright > np.percentile(bright,55))]
        elif kind == 'ear':
            selected = rgb[(r > g*1.14) & (r > b*1.2) & (bright > np.percentile(bright,30))]
        elif kind == 'light':
            selected = rgb[bright >= np.percentile(bright,75)]
        else:
            selected = rgb[(bright >= np.percentile(bright,58)) & (bright <= np.percentile(bright,94))]
            if kind == 'wing':
                selected = selected[selected[:,1] >= selected[:,0]]
        if not len(selected):
            selected = rgb
        # The source image supplies the pattern; coordinates wrap through it.
        source = image[sy%h, sx%w].astype(float)
        color = selected[np.argmin(np.sum((selected-source)**2, axis=1))].astype('u1')
        self._sample_cache[key] = color
        return color

    def face(self, triangle, uv, kind='body'):
        p = np.array(triangle, dtype=float)
        n = np.cross(p[1]-p[0], p[2]-p[0])
        length = np.linalg.norm(n)
        if length < 1e-8:
            return
        n /= length
        self.vertices.extend(p)
        self.normals.extend([n]*3)
        direction = (1 if n[0]>0 else 3) if abs(n[0])>abs(n[2]) else (2 if n[2]>=0 else 0)
        self.colors.extend([self.pixel(uv, kind,direction)]*3)

    def ellipsoid(self, center, radius, kind='body', segments=32, rings=18):
        center, radius = np.array(center), np.array(radius)
        for j in range(rings):
            for i in range(segments):
                points = []
                for u,v in [(i/segments,j/rings),((i+1)/segments,j/rings),
                            ((i+1)/segments,(j+1)/rings),(i/segments,(j+1)/rings)]:
                    a,t = u*2*math.pi, v*math.pi
                    points.append(center+radius*np.array([math.sin(t)*math.cos(a),math.cos(t),math.sin(t)*math.sin(a)]))
                uv = ((i+.5)/segments,(j+.5)/rings)
                self.face([points[0],points[2],points[1]],uv,kind)
                self.face([points[0],points[3],points[2]],uv,kind)

    def tube(self, points, radii, kind='body', sides=12):
        points = np.array(points,dtype=float)
        for j in range(len(points)-1):
            tangent = points[j+1]-points[j]
            tangent /= np.linalg.norm(tangent)
            reference = np.array([0.,1.,0.]) if abs(tangent[1]) < .9 else np.array([1.,0.,0.])
            a = np.cross(tangent, reference)
            a /= np.linalg.norm(a)
            b = np.cross(tangent,a)
            for i in range(sides):
                ring = [math.cos(t)*a+math.sin(t)*b for t in [i/sides*math.tau,(i+1)/sides*math.tau]]
                p = [points[j]+ring[0]*radii[j],points[j]+ring[1]*radii[j],
                     points[j+1]+ring[1]*radii[j+1],points[j+1]+ring[0]*radii[j+1]]
                uv = ((i+.5)/sides,(j+.5)/(len(points)-1))
                self.face([p[0],p[1],p[2]],uv,kind)
                self.face([p[0],p[2],p[3]],uv,kind)

    def membrane(self, anchor, rim, kind='wing'):
        a = np.array(anchor)
        for j in range(len(rim)-1):
            b,c = np.array(rim[j]),np.array(rim[j+1])
            # Subdivide the web so the source pixel pattern stays crisp.
            steps = 14
            for i in range(steps):
                for k in range(steps-i):
                    p = a+(b-a)*i/steps+(c-a)*k/steps
                    q = a+(b-a)*(i+1)/steps+(c-a)*k/steps
                    r = a+(b-a)*i/steps+(c-a)*(k+1)/steps
                    uv = ((i+.5)/steps,(k+.5)/steps)
                    self.face([p,q,r],uv,kind)
                    if i+k < steps-1:
                        t = a+(b-a)*(i+1)/steps+(c-a)*(k+1)/steps
                        self.face([q,t,r],uv,kind)

    def result(self):
        return np.array(self.vertices,dtype='<f4'),np.array(self.normals,dtype='<f4'),np.array(self.colors,dtype='u1')


def rat(views, phase):
    s = Sculpt(views)
    step = [0., 1., -1.][phase%3]
    s.ellipsoid((0,.205,-.08),(.145,.16,.24))
    s.ellipsoid((0,.225,-.21),(.155,.175,.16))
    s.ellipsoid((0,.20,.16),(.11,.105,.15))
    s.tube([(0,.18,.17),(0,.15,.29),(0,.125,.355)],[.083,.055,.017])
    s.ellipsoid((0,.132,.347),(.027,.024,.022),'ear',16,8)
    for side in [-1,1]:
        s.ellipsoid((side*.085,.297,.13),(.06,.071,.023),'body',20,12)
        s.ellipsoid((side*.085,.303,.149),(.041,.049,.007),'ear',18,10)
        s.ellipsoid((side*.085,.232,.238),(.015,.018,.014),'eye',12,8)
        s.ellipsoid((side*.089,.238,.245),(.004,.005,.004),'light',8,6)
        for z,sign in [(-.19,1),(.12,-1)]:
            move = step*side*sign*.035
            s.tube([(side*.09,.15,z),(side*.14,.065,z+move),(side*.14,.028,z+.055+move)], [.05,.033,.022],sides=12)
            s.ellipsoid((side*.14,.024,z+.074+move),(.044,.02,.057),'ear',16,8)
            for toe in [-1,0,1]:
                s.tube([(side*.14+toe*.018,.023,z+.10+move),(side*.14+toe*.02,.018,z+.13+move)], [.01,.002],'claw',6)
    tail = [(0,.15,-.35),(.045,.09,-.46),(.105+step*.018,.055,-.58),(.14+step*.035,.041,-.71),(.085+step*.045,.055,-.80)]
    s.tube(tail,[.035,.027,.020,.013,.001],'ear',12)
    # Fine whiskers retain the dark source outline instead of a new white paint.
    for side in [-1,1]:
        for dz in [-.045,0,.04]:
            s.tube([(side*.035,.155,.31),(side*.16,.16,.32+dz)],[.0025,.001],'light',4)
    return s.result()


class DragonSculpt(Sculpt):
    """Continuous surfaces and restrained, source-only regional palettes."""
    def __init__(self, views):
        super().__init__(views)
        rgb = self.palette.astype(float)
        r, g, b = rgb.T
        green = (g > r * 1.35) & (g > b * 2.0)
        red = (r > g * 2.5) & (r > b * 1.6) & (r > 30)
        dominant = green if green.sum() > red.sum() else red
        self.skin = np.unique(rgb[dominant], axis=0)
        if not len(self.skin):
            self.skin = np.unique(rgb, axis=0)
        self.skin = self.skin[np.argsort(self.skin.mean(axis=1))]
        bone = rgb[(r >= g * .95) & (g > r * .60) & (g > b * 1.4)]
        self.bone = np.unique(bone if len(bone) else rgb, axis=0)
        self.bone = self.bone[np.argsort(self.bone.mean(axis=1))]
        self.dark = rgb[np.argmin(rgb.mean(axis=1))].astype('u1')

    def pixel(self, uv, kind='body', direction=2):
        # No directional sprite reprojection: that produced stripes at every
        # ring/normal boundary. Every output RGB still belongs to the source.
        if kind == 'eye':
            return self.dark
        bank = self.bone if kind in ('claw', 'iris') else self.skin
        level = {'body': .68, 'wing': .72, 'light': .83, 'ridge': .48,
                 'claw': .84, 'iris': .67}.get(kind, .62)
        variation = 0.0  # Regional color; lighting describes the volume without ring stripes.
        return bank[int(np.clip(level + variation, 0, 1) * (len(bank)-1))].astype('u1')

    def ellipsoid(self, *args, **kwargs):
        start = len(self.vertices)
        super().ellipsoid(*args, **kwargs)
        # The legacy ellipsoid uses clockwise winding but inward cross normals.
        # Work in outward-cross convention here; result converts winding to Godot.
        for i in range(start,len(self.vertices),3):
            self.vertices[i+1],self.vertices[i+2] = self.vertices[i+2],self.vertices[i+1]
            for k in range(i,i+3):
                self.normals[k] = -self.normals[k]

    @staticmethod
    def curve(points, values, subdivisions=5):
        points = np.asarray(points, float)
        values = np.asarray(values, float)
        result, radii = [], []
        for j in range(len(points)-1):
            a,b,c,d = points[max(0,j-1)],points[j],points[j+1],points[min(len(points)-1,j+2)]
            for i in range(subdivisions):
                t = i / subdivisions
                result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
                radii.append(values[j]*(1-t)+values[j+1]*t)
        result.append(points[-1])
        radii.append(values[-1])
        return np.array(result), np.array(radii)

    def tube(self, points, radii, kind='body', sides=16):
        points, radii = self.curve(points, radii)
        rings = []
        previous = None
        for j, point in enumerate(points):
            tangent = points[min(j+1,len(points)-1)] - points[max(0,j-1)]
            tangent /= np.linalg.norm(tangent)
            if previous is None:
                axis = np.array([0.,1.,0.]) if abs(tangent[1]) < .9 else np.array([1.,0.,0.])
                a = np.cross(tangent, axis)
            else:
                a = previous - tangent * np.dot(previous,tangent)
            a /= np.linalg.norm(a)
            previous = a
            b = np.cross(tangent,a)
            rings.append([point+radii[j]*(math.cos(i/sides*math.tau)*a+math.sin(i/sides*math.tau)*b) for i in range(sides)])
        for j in range(len(rings)-1):
            for i in range(sides):
                k = (i+1)%sides
                uv = (i/sides,j/(len(rings)-1))
                self.face([rings[j][i],rings[j][k],rings[j+1][k]],uv,kind)
                self.face([rings[j][i],rings[j+1][k],rings[j+1][i]],uv,kind)
        for i in range(sides):
            k = (i+1)%sides
            self.face([points[0],rings[0][k],rings[0][i]],(0,0),kind)
            self.face([points[-1],rings[-1][i],rings[-1][k]],(0,1),kind)

    def web(self, wrist, first, last, side):
        # Ruled bat-wing panel: concave trailing edge and a gently inflated web.
        wrist, first, last = map(lambda p: np.array(p,float), (wrist,first,last))
        def point(u,v):
            edge = first*(1-v)+last*v
            edge += (wrist-edge)*(.24*math.sin(math.pi*v))
            p = wrist*(1-u)+edge*u
            p += np.array([side*.018,.055,.035])*math.sin(math.pi*u)*math.sin(math.pi*v)
            return p
        steps = 18
        for i in range(steps):
            for j in range(steps):
                u,v = i/steps,j/steps
                p,q,r,t = point(u,v),point(u+1/steps,v),point(u+1/steps,v+1/steps),point(u,v+1/steps)
                self.face([p,q,r],(u,v),'wing')
                self.face([p,r,t],(u,v),'wing')
        edge = []
        for v in np.linspace(0,1,9):
            edge.append(point(1,v))
        self.tube(edge,[.008]*len(edge),'ridge',6)

    def result(self):
        vertices, normals, colors = super().result()
        # Average shared vertices per continuous surface; no format/runtime change.
        _, inverse = np.unique(np.round(vertices,6),axis=0,return_inverse=True)
        smooth = np.zeros((inverse.max()+1,3),float)
        np.add.at(smooth,inverse,normals)
        lengths = np.linalg.norm(smooth,axis=1)
        smooth /= np.maximum(lengths[:,None],1e-9)
        # Godot front faces are clockwise; normals remain outward.
        order = np.arange(len(vertices)).reshape(-1,3)[:,[0,2,1]].ravel()
        return vertices[order],smooth[inverse][order].astype('<f4'),colors[order]


def dragon(views, phase):
    s = DragonSculpt(views)
    step = [0.,1.,-1.][phase%3]
    # Low, long rib cage, strong hips, and a continuous forward-curving neck.
    s.ellipsoid((0,.49,-.13),(.265,.29,.43))
    s.ellipsoid((0,.55,.13),(.235,.27,.26))
    s.tube([(0,.53,.15),(0,.69,.32),(0,.87,.41),(0,1.04,.53)], [.205,.158,.117,.125],sides=24)
    # Overlapping ventral scutes rather than a single bright oval on the chest.
    for y,z,width in [(.33,.275,.12),(.41,.337,.16),(.49,.375,.16),
                      (.57,.401,.15),(.65,.45,.13),(.73,.495,.108),
                      (.81,.52,.095),(.89,.55,.09),(.97,.60,.085)]:
        s.ellipsoid((0,y,z),(width,.047,.029),'light',24,10)
    # Wedge-shaped skull, tapered muzzle, dark mouth seam and separate jaw.
    s.ellipsoid((0,1.035,.61),(.151,.12,.195))
    s.ellipsoid((0,.985,.785),(.105,.056,.185),'ridge',28,12)
    s.ellipsoid((0,.976,.81),(.103,.017,.149),'eye',24,8)
    s.ellipsoid((0,.953,.797),(.102,.027,.161),'light',24,10)
    for side in [-1,1]:
        # Recessed amber eye beneath a strong swept brow.
        s.ellipsoid((side*.126,1.075,.687),(.025,.028,.048),'ridge',16,10)
        s.ellipsoid((side*.144,1.077,.694),(.012,.019,.032),'iris',16,10)
        s.ellipsoid((side*.153,1.079,.704),(.004,.015,.007),'eye',12,8)
        s.tube([(side*.099,1.105,.752),(side*.14,1.12,.672),(side*.148,1.093,.595)], [.023,.03,.014],'body',12)
        s.ellipsoid((side*.065,1.027,.899),(.013,.009,.021),'eye',12,8)
        # Horns sweep backwards along the skull, with smaller cheek spurs.
        s.tube([(side*.105,1.11,.52),(side*.17,1.205,.425),(side*.20,1.24,.30),(side*.21,1.27,.225)], [.042,.031,.015,.001],'claw',14)
        s.tube([(side*.127,1.012,.528),(side*.205,1.012,.45),(side*.229,1.052,.37)], [.039,.022,.001],'ridge',12)
        for z in [.79,.866]:
            s.tube([(side*.094,.985,z),(side*.092,.951,z+.012)],[.012,.001],'claw',10)
        move = side*step*.048
        lift = max(0,side*step)*.026
        s.ellipsoid((side*.235,.325,-.30),(.165,.21,.21))
        s.tube([(side*.25,.32,-.30),(side*.31,.17,-.16+move),(side*.30,.07,.055+move)], [.113,.078,.056],sides=20)
        s.ellipsoid((side*.30,.055+lift,.105+move),(.097,.05,.13),segments=24,rings=12)
        # Front feet now support the body: a dragon's planted four-legged stance.
        s.tube([(side*.18,.55,.18),(side*.255,.30,.28-move),(side*.235,.067+lift,.425-move)], [.087,.053,.04],sides=18)
        s.ellipsoid((side*.235,.046+lift,.462-move),(.073,.04,.095),segments=20,rings=10)
        for toe in [-1,0,1]:
            for x,z,w in [(side*.30+toe*.054,.19+move,.023),(side*.235+toe*.043,.51-move,.018)]:
                s.tube([(x,.055+lift,z),(x+toe*.007,.039+lift,z+.052),(x+toe*.01,.022+lift,z+.09)], [w,w*.65,.001],'claw',10)
        flap = step*.035
        root = np.array([side*.17,.69,-.02])
        elbow = np.array([side*.40,.91+flap,-.13])
        wrist = np.array([side*.69,1.22+flap,.015])
        tips = [np.array(p) for p in [
            [side*1.15,1.29+flap,-.19],
            [side*1.075,.89+flap,-.48],
            [side*.80,.64+flap,-.75],
            [side*.45,.48,-.70],
            [side*.19,.46,-.42]]]
        # All membranes meet at the wrist, matching the visible finger anatomy.
        for a,b in zip(tips,tips[1:]):
            s.web(wrist,a,b,side)
        s.web(wrist,root,tips[-1],side)
        s.tube([root,elbow,wrist,tips[0]], [.067,.045,.031,.001],sides=16)
        for tip in tips[1:-1]:
            mid = wrist*.45+tip*.55+np.array([side*.035,.055,0])
            s.tube([wrist,mid,tip],[.018,.011,.001],'body',10)
        s.tube([wrist,wrist+np.array([side*.023,.065,.055]),wrist+np.array([side*.037,.098,.04])],[.023,.014,.001],'claw',10)
    tail = [(0,.43,-.45),(.035,.31,-.66),(.13+step*.012,.18,-.87),(.27+step*.025,.14,-1.07),(.40+step*.04,.22,-1.21),(.42+step*.05,.36,-1.23),(.33+step*.06,.42,-1.16)]
    s.tube(tail,[.146,.11,.076,.047,.027,.013,.001],sides=22)
    # Dorsal plates are embedded in the back/neck instead of floating above it.
    for x,y,z,h,r in [(0,.99,.405,.075,.028),(0,.86,.285,.09,.035),
                      (0,.79,.13,.105,.041),(0,.78,-.03,.12,.044),
                      (0,.745,-.20,.115,.043),(0,.65,-.37,.10,.039),
                      (.025,.49,-.57,.085,.032),(.08,.335,-.76,.068,.026),
                      (.18+step*.018,.22,-.94,.05,.020)]:
        s.tube([(x,y,z),(x,y+h*.66,z-.026),(x,y+h,z-.07)], [r,r*.6,.001],'ridge',10)
    return s.result()

AUTHORED = {21:rat,56:rat,34:dragon,39:dragon}

# Keep authored materials stable while poses change; source frame zero is original.
PALETTE_FRAME = {34: 0, 39: 0}

# Authored arachnids share the smooth geometry builder, with their own materials.
from aranas import make_generators, PROFILES as SPIDER_PROFILES
AUTHORED.update(make_generators(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in SPIDER_PROFILES})

from lobos import make_generators as make_wolves, PROFILES as WOLF_PROFILES
AUTHORED.update(make_wolves(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in WOLF_PROFILES})

from osos import make_generators as make_bears, PROFILES as BEAR_PROFILES
AUTHORED.update(make_bears(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in BEAR_PROFILES})

from serpientes import make_generators as make_snakes, PROFILES as SNAKE_PROFILES
AUTHORED.update(make_snakes(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in SNAKE_PROFILES})

from reptadores import make_generators as make_crawlers, PROFILES as CRAWLER_PROFILES
AUTHORED.update(make_crawlers(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in CRAWLER_PROFILES})

from artropodos import make_generators as make_arthropods, PROFILES as ARTHROPOD_PROFILES
AUTHORED.update(make_arthropods(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in ARTHROPOD_PROFILES})

from granja import make_generators as make_farm, PROFILES as FARM_PROFILES
AUTHORED.update(make_farm(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in FARM_PROFILES})

from bosque import make_generators as make_forest, PROFILES as FOREST_PROFILES
AUTHORED.update(make_forest(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in FOREST_PROFILES})

from caninos import make_generators as make_companions, PROFILES as COMPANION_PROFILES
AUTHORED.update(make_companions(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in COMPANION_PROFILES})

from esqueletos import make_generators as make_skeletons, PROFILES as SKELETON_PROFILES
AUTHORED.update(make_skeletons(DragonSculpt))
PALETTE_FRAME.update({oid: 0 for oid in SKELETON_PROFILES})
