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


def dragon(views, phase):
    s = Sculpt(views)
    step = [0.,1.,-1.][phase%3]
    s.ellipsoid((0,.55,-.1),(.28,.34,.40))
    s.ellipsoid((0,.57,.16),(.24,.28,.24))
    s.ellipsoid((0,.50,.30),(.17,.22,.055),'light',28,16)
    s.tube([(0,.62,.18),(0,.80,.35),(0,1.02,.45),(0,1.17,.54)],[.19,.15,.12,.14],sides=24)
    s.ellipsoid((0,1.17,.59),(.18,.145,.23))
    s.ellipsoid((0,1.12,.78),(.14,.085,.16))
    s.ellipsoid((0,1.055,.77),(.127,.035,.16),'light',24,10)
    s.ellipsoid((0,1.10,.80),(.13,.017,.135),'eye',24,8)
    for side in [-1,1]:
        s.ellipsoid((side*.145,1.215,.68),(.04,.044,.055),'claw',16,10)
        s.ellipsoid((side*.170,1.216,.698),(.011,.028,.02),'eye',12,8)
        s.ellipsoid((side*.071,1.172,.86),(.017,.011,.022),'eye',12,8)
        s.tube([(side*.125,1.28,.52),(side*.20,1.39,.42),(side*.23,1.47,.31)],[.054,.033,.002],'claw',12)
        for z in [.74,.83]:
            s.tube([(side*.109,1.105,z),(side*.105,1.048,z+.014)],[.021,.002],'claw',10)
        # Powerful rear legs and small forelegs stay separately articulated.
        move = side*step*.065
        s.ellipsoid((side*.25,.38,-.23),(.18,.24,.20))
        s.tube([(side*.29,.35,-.19),(side*.33,.14,-.04+move),(side*.32,.065,.14+move)],[.12,.074,.066],sides=18)
        s.ellipsoid((side*.32,.06,.17+move),(.12,.055,.16),segments=24,rings=12)
        s.tube([(side*.18,.62,.20),(side*.30,.39,.33),(side*.27,.26,.50-move)],[.075,.049,.04],sides=14)
        for toe in [-1,0,1]:
            s.tube([(side*.32+toe*.07,.075,.26+move),(side*.32+toe*.082,.03,.38+move)],[.03,.001],'claw',10)
            s.tube([(side*.27+toe*.031,.27,.49-move),(side*.27+toe*.04,.19,.55-move)],[.019,.001],'claw',8)
        # A thin, scalloped web between individually shaped wing fingers.
        flap = step*.08
        root = np.array([side*.16,.81,-.02])
        elbow = np.array([side*.49,1.09+flap,-.13])
        wrist = np.array([side*.83,1.28+flap,-.03])
        rim = [wrist,
               [side*1.18,1.05+flap,-.27],
               [side*.86,.82+flap,-.27],
               [side*1.02,.67+flap,-.59],
               [side*.68,.66+flap,-.45],
               [side*.66,.43+flap,-.79],
               [side*.39,.50,-.53], [side*.23,.42,-.38]]
        s.membrane(elbow,rim)
        s.membrane(root,[elbow,rim[-1]])
        s.tube([root,elbow,wrist],[.08,.055,.026],sides=14)
        for end in [rim[1],rim[3],rim[5],rim[7]]:
            s.tube([elbow,(elbow+np.array(end))*.5,end],[.031,.018,.004],sides=10)
        s.tube([wrist,wrist+np.array([side*.045,.10,.04])],[.022,.001],'claw',10)
    tail = [(0,.52,-.40),(.025,.36,-.63),(.10+step*.018,.20,-.84),(.20+step*.04,.16,-1.06),(.32+step*.06,.26,-1.22),(.30+step*.09,.43,-1.32),(.20+step*.10,.51,-1.28)]
    s.tube(tail,[.16,.12,.085,.057,.033,.019,.001],sides=20)
    for j in range(7):
        z = .36-j*.13
        y = .88 if j>2 else 1.04-j*.055
        s.tube([(0,y,z),(0,y+.12,z-.04)],[.053,.001],'light',8)
    return s.result()


AUTHORED = {21:rat,56:rat,34:dragon,39:dragon}
