# Cannonball car rigs: parametric low/mid-poly car bodies in headless Blender, rendered from
# the game's rear chase camera with a stylised cel (toon) material set.
# Python only because bpy forces it (forge rule: Lua > Rust > Go otherwise). Always run -I.
#
#   PY=$(lua art/rigs/setup_bpy.lua)
#   $PY -I art/rigs/cars/car_rig.py art/rigs/cars/cars.json art/rigs/cars/poses.json OUT
#        [--ids a,b] [--sheets body,turn,traffic] [--passes clay,hint,depth] [--paint HERO.png]
#        [--samples 12] [--threads 8] [--res 1024] [--blend 1]
#
# OUT/<id>/ gets <sheet>/<pose>[_p<paint>].png renders (RGBA, transparent film), hero/clay.png,
# hero/hint.png, hero/depth.png (near = white) for the flat pose, and rig.json with the camera,
# per-render projected reference points (ground, lamps) and the resolved parameters.
#
# Model: root (yaw, pitch about the ground point under mid-wheelbase) -> body_roll (roll) -> body,
# cabin, lamps, trim ... ; root -> axle hubs -> wheels. Only the two FRONT hubs carry `steer`
# (rotation about their own vertical kingpin axis). Rear wheels are parented rigidly to root,
# so they always stay aligned with the body: a steer value never reaches them.
import json, math, os, sys, time
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from bpy_extras.object_utils import world_to_camera_view

# ------------------------------------------------------------------ small helpers

def opts(argv):
    """Positional args plus --key value pairs (every flag takes a value)."""
    pos, kv, i = [], {}, 0
    while i < len(argv):
        if argv[i].startswith('--'):
            kv[argv[i][2:]] = argv[i + 1]; i += 2
        else:
            pos.append(argv[i]); i += 1
    return pos, kv


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin1(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(h):
    return tuple(lin1(c) for c in hex_rgb(h))


def interp(profile, t):
    """Catmull-Rom through [[t, v], ...] (clamped at the ends)."""
    ts = [p[0] for p in profile]; vs = [p[1] for p in profile]
    if t <= ts[0]:
        return vs[0]
    if t >= ts[-1]:
        return vs[-1]
    i = max(k for k in range(len(ts) - 1) if ts[k] <= t)
    t0, t1 = ts[i], ts[i + 1]; u = (t - t0) / (t1 - t0)
    p0 = vs[i - 1] if i > 0 else vs[i]; p1 = vs[i]; p2 = vs[i + 1]
    p3 = vs[i + 2] if i + 2 < len(vs) else vs[i + 1]
    # tension 0.5, slopes clamped to keep the curve monotone between keys
    m1 = (p2 - p0) * 0.5; m2 = (p3 - p1) * 0.5
    d = p2 - p1
    if d == 0:
        m1 = m2 = 0
    h00 = 2 * u ** 3 - 3 * u ** 2 + 1; h10 = u ** 3 - 2 * u ** 2 + u
    h01 = -2 * u ** 3 + 3 * u ** 2; h11 = u ** 3 - u ** 2
    return h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2


def smooth(a, b, x):
    x = min(1, max(0, (x - a) / (b - a)))
    return x * x * (3 - 2 * x)


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


# ------------------------------------------------------------------ materials (cel shading)
LIGHT = Vector((-0.52, -0.55, 0.65)).normalized()   # upper-left, warm, from the camera side
WARM = (1.0, 0.965, 0.90)
COOL = (0.80, 0.86, 1.0)


def _node_mix(nt, a, b, fac, blend='MIX'):
    n = nt.nodes.new('ShaderNodeMix'); n.data_type = 'RGBA'; n.blend_type = blend
    ins = [s for s in n.inputs if s.type == 'RGBA']
    for sock, v in ((ins[0], a), (ins[1], b)):
        if isinstance(v, tuple):
            sock.default_value = (*v, 1.0)
        else:
            nt.links.new(v, sock)
    f = n.inputs[0]
    if isinstance(fac, (int, float)):
        f.default_value = fac
    else:
        nt.links.new(fac, f)
    return [s for s in n.outputs if s.type == 'RGBA'][0]


def _math(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new('ShaderNodeMath'); n.operation = op; n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _band(nt, x, lo, hi):
    n = nt.nodes.new('ShaderNodeMapRange'); n.interpolation_type = 'SMOOTHSTEP'; n.clamp = True
    nt.links.new(x, n.inputs[0]); n.inputs[1].default_value = lo; n.inputs[2].default_value = hi
    n.inputs[3].default_value = 0.0; n.inputs[4].default_value = 1.0
    return n.outputs[0]


def _vdot(nt, a, b):
    n = nt.nodes.new('ShaderNodeVectorMath'); n.operation = 'DOT_PRODUCT'
    for i, v in enumerate((a, b)):
        if isinstance(v, (tuple, Vector)):
            n.inputs[i].default_value = tuple(v)
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs['Value']


MAT_SPECS = {}   # name -> (hex, gloss, env) so paints can be swapped by rebuilding


def toon(name, hex_colour, gloss=0.25, env=0.15, hint='#808080'):
    """Emission-only cel material: three soft-edged light bands, a hard specular band and a
    fresnel sky reflection. World-space normals, fixed light: identical look in every pose."""
    MAT_SPECS[name] = (hex_colour, gloss, env)
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*lin(hint), 1.0)        # Workbench hint pass colour
    nt = m.node_tree; nt.nodes.clear()
    base = lin(hex_colour)
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    N = geo.outputs['Normal']
    lam = _vdot(nt, N, LIGHT)
    t1 = _band(nt, lam, -0.30, -0.18)
    t2 = _band(nt, lam, 0.30, 0.42)
    shadow = tuple(base[i] * 0.50 * COOL[i] for i in range(3))
    mid = tuple(base[i] * 0.78 for i in range(3))
    lit = tuple(min(1.0, base[i] * 1.02 * WARM[i]) for i in range(3))
    col = _node_mix(nt, shadow, mid, t1)
    col = _node_mix(nt, col, lit, t2)
    # specular band: half vector between light and view
    h = nt.nodes.new('ShaderNodeVectorMath'); h.operation = 'ADD'
    nt.links.new(geo.outputs['Incoming'], h.inputs[0]); h.inputs[1].default_value = tuple(LIGHT)
    hn = nt.nodes.new('ShaderNodeVectorMath'); hn.operation = 'NORMALIZE'
    nt.links.new(h.outputs[0], hn.inputs[0])
    spec = _band(nt, _vdot(nt, N, hn.outputs[0]), 0.972, 0.982)
    if gloss > 0:
        col = _node_mix(nt, col, (1.0, 0.98, 0.94), _math(nt, 'MULTIPLY', spec, gloss), 'ADD')
    if env > 0:
        lw = nt.nodes.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.35
        nz = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(N, nz.inputs[0])
        sky = _math(nt, 'MULTIPLY_ADD', nz.outputs['Z'], 0.5)
        sky.node.inputs[2].default_value = 0.5
        envc = _node_mix(nt, (0.30, 0.26, 0.20), (0.62, 0.74, 0.95), sky)
        col = _node_mix(nt, col, envc, _math(nt, 'MULTIPLY', lw.outputs['Fresnel'], env), 'ADD')
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(col, em.inputs['Color'])
    em.inputs['Strength'].default_value = 1.0
    out = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(em.outputs[0], out.inputs['Surface'])
    return m


def outline_material():
    m = bpy.data.materials.get('outline') or bpy.data.materials.new('outline')
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*lin('#1d1512'), 1)
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(geo.outputs['Backfacing'], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1]); nt.links.new(tr.outputs[0], mix.inputs[2])
    out = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(mix.outputs[0], out.inputs['Surface'])
    return m


def depth_material(near, far):
    m = bpy.data.materials.new('depth'); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    cd = nt.nodes.new('ShaderNodeCameraData')
    v = _math(nt, 'SUBTRACT', 1.0, _math(nt, 'DIVIDE', _math(nt, 'SUBTRACT', cd.outputs['View Distance'], near), far - near), clamp=True)
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(v, em.inputs['Color'])
    out = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(em.outputs[0], out.inputs['Surface'])
    return m


def make_materials(car, paint):
    w = car['wheel']
    return {
        'paint': toon('paint', paint, gloss=0.55, env=0.30, hint='#d04030'),
        'trim': toon('trim', '#1b1c1f', gloss=0.30, env=0.20, hint='#202020'),
        'under': toon('under', '#141414', gloss=0.0, env=0.0, hint='#101010'),
        'glass': toon('glass', '#28323d', gloss=0.9, env=0.55, hint='#3050a0'),
        'interior': toon('interior', '#2a2624', gloss=0.05, env=0.05, hint='#503020'),
        'seat': toon('seat', '#2e2b2a', gloss=0.15, env=0.05, hint='#604030'),
        'lamp': toon('lamp', '#b3141a', gloss=0.8, env=0.25, hint='#ff2020'),
        'lamp_core': toon('lamp_core', '#e8342c', gloss=0.8, env=0.20, hint='#ff6040'),
        'lamp_clear': toon('lamp_clear', '#e6e1da', gloss=0.8, env=0.30, hint='#f0f0f0'),
        'chrome': toon('chrome', '#c7cbd0', gloss=0.9, env=0.45, hint='#c0c0c0'),
        'plate': toon('plate', '#e4e0d4', gloss=0.2, env=0.05, hint='#f0e8d0'),
        'tyre': toon('tyre', '#1e1e21', gloss=0.10, env=0.10, hint='#181818'),
        'rim': toon('rim', w.get('rim', '#c0c4c8'), gloss=0.7, env=0.35, hint='#a0a0b0'),
        'rim_dark': toon('rim_dark', '#121315', gloss=0.0, env=0.0, hint='#080808'),
        'bed': toon('bed', '#2c2d30', gloss=0.05, env=0.05, hint='#303030'),
        'skid': toon('skid', '#8e9399', gloss=0.3, env=0.2, hint='#909090'),
        'well': toon('well', '#0d0d0e', gloss=0.0, env=0.0, hint='#050505'),
        'outline': outline_material(),
    }


# ------------------------------------------------------------------ mesh construction
COLL = None


def new_obj(name, me, parent=None, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    ob.location = loc
    return ob


def empty(name, parent=None, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    COLL.objects.link(ob)
    ob.parent = parent; ob.location = loc
    return ob


def mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    return me


def superellipse_ring(M, hw, zb, zt, p, taper):
    zc, h = (zt + zb) / 2, (zt - zb) / 2; e = 2.0 / p; pts = []
    for k in range(M):
        th = -math.pi / 2 + 2 * math.pi * k / M
        u = spow(math.sin(th), e)
        x = hw * spow(math.cos(th), e) * (1 - taper * max(0.0, u) ** 2)
        pts.append((x, zc + h * u))
    return pts


def trapezoid_ring(M, hb, ht, zb, zt, r):
    """Rounded-top trapezoid (cabin section), counter-clockwise from bottom centre."""
    r = min(r, (zt - zb) * 0.45, ht * 0.9)
    path = [(0, zb), (hb, zb), (ht, zt), (-ht, zt), (-hb, zb)]
    # densify the perimeter, then round the two top corners by sampling arcs
    pts = []
    def seg(a, b, n):
        for i in range(n):
            pts.append((a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n))
    n_side = M // 5
    seg((0, zb), (hb, zb), n_side // 2 + 1)
    # side up to the corner start
    side = Vector((ht - hb, zt - zb)); L = side.length; d = side / L
    c1 = Vector((hb, zb)) + d * (L - r)
    seg((hb, zb), tuple(c1), n_side)
    top_a = Vector((ht - r, zt))
    for i in range(n_side):            # corner arc (quadratic Bezier through the corner)
        u = i / n_side; c = Vector((ht, zt))
        q = (1 - u) ** 2 * c1 + 2 * (1 - u) * u * c + u * u * top_a
        pts.append(tuple(q))
    seg(tuple(top_a), (-(ht - r), zt), n_side)
    c2 = Vector((-hb, zb)) + Vector((-(ht - hb), zt - zb)).normalized() * (L - r)
    top_b = Vector((-(ht - r), zt)); c = Vector((-ht, zt))
    for i in range(n_side):
        u = i / n_side
        q = (1 - u) ** 2 * top_b + 2 * (1 - u) * u * c + u * u * c2
        pts.append(tuple(q))
    seg(tuple(c2), (-hb, zb), n_side)
    seg((-hb, zb), (0, zb), n_side // 2 + 1)
    return pts


def loft(name, rings, ys, cap=(0.06, 0.06)):
    """rings[i] is a list of (x, z) at y = ys[i]; all rings have equal length. Ends are closed
    with shallow domes (scaled inner rings) so subdivision gives soft, believable corners."""
    M = len(rings[0]); verts = []; faces = []
    def add_ring(r, y):
        base = len(verts)
        for x, z in r:
            verts.append((x, y, z))
        return base
    idx = [add_ring(r, y) for r, y in zip(rings, ys)]
    for a, b in zip(idx, idx[1:]):
        for k in range(M):
            faces.append((a + k, a + (k + 1) % M, b + (k + 1) % M, b + k))
    for end, sign, depth in ((0, -1, cap[0]), (len(rings) - 1, 1, cap[1])):
        r = rings[end]; y = ys[end]
        cx = sum(p[0] for p in r) / M; cz = sum(p[1] for p in r) / M
        prev = idx[end]
        for s, dy in ((0.72, 0.55), (0.40, 0.85), (0.14, 0.98)):
            ring = [(cx + (x - cx) * s, cz + (z - cz) * s) for x, z in r]
            cur = add_ring(ring, y + sign * depth * dy)
            for k in range(M):
                f = (prev + k, prev + (k + 1) % M, cur + (k + 1) % M, cur + k)
                faces.append(f if sign > 0 else f[::-1])
            prev = cur
        c = len(verts); verts.append((cx, y + sign * depth, cz))
        for k in range(M):
            f = (prev + k, prev + (k + 1) % M, c)
            faces.append(f if sign > 0 else f[::-1])
    me = mesh_from(name, verts, faces)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    return me


def classify(me, rule, mats_order):
    """Assign material index per face from rule(center, normal) -> material name."""
    for p in me.polygons:
        name = rule(Vector(p.center), Vector(p.normal))
        p.material_index = mats_order.index(name)


def attach(ob, mats_order, M):
    ob.data.materials.clear()
    for n in mats_order:
        ob.data.materials.append(M[n])


def evaluated_copy(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def subsurf(ob, levels=2):
    m = ob.modifiers.new('sub', 'SUBSURF'); m.levels = levels; m.render_levels = levels
    return evaluated_copy(ob)


def boolean_cut(ob, cutters):
    for c in cutters:
        m = ob.modifiers.new('cut', 'BOOLEAN'); m.operation = 'DIFFERENCE'; m.solver = 'EXACT'
        m.object = c
        try:
            m.material_mode = 'TRANSFER'
        except Exception:
            pass
        c.hide_render = True; c.hide_viewport = True
    evaluated_copy(ob)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)


def smooth_all(ob, angle=None):
    for p in ob.data.polygons:
        p.use_smooth = True


def box_mesh(name, sx, sy, sz, bevel=0.0, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel, segments=seg, affect='EDGES', profile=0.5)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return me


def cyl_mesh(name, r, depth, seg=32, axis='Y', cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=depth)
    rot = {'X': Matrix.Rotation(math.pi / 2, 4, 'Y'), 'Y': Matrix.Rotation(math.pi / 2, 4, 'X'), 'Z': Matrix()}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return me


def polar_shape_mesh(name, outline, y, thick=0.012, rings=4):
    """A flat (x,z) star-convex outline at plane y, filled with a polar grid (so shrinkwrap can
    bend it), extruded `thick` toward -y (behind, towards the camera)."""
    cx = sum(p[0] for p in outline) / len(outline); cz = sum(p[1] for p in outline) / len(outline)
    n = len(outline); verts = []; faces = []
    for ri in range(rings, 0, -1):
        s = ri / rings
        for x, z in outline:
            verts.append((cx + (x - cx) * s, y, cz + (z - cz) * s))
    c = len(verts); verts.append((cx, y, cz))
    for ri in range(rings - 1):
        a, b = ri * n, (ri + 1) * n
        for k in range(n):
            faces.append((a + k, a + (k + 1) % n, b + (k + 1) % n, b + k))
    last = (rings - 1) * n
    for k in range(n):
        faces.append((last + k, last + (k + 1) % n, c))
    me = mesh_from(name, verts, faces)
    bm = bmesh.new(); bm.from_mesh(me)
    for f in bm.faces:
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
    if thick > 0:
        ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        for v in ext['geom']:
            if isinstance(v, bmesh.types.BMVert):
                v.co.y += thick
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    return me


def shape_outline(shape, x, z, w, h, rot=0.0, n=40):
    """Lamp/plate outlines in the rear (x, z) plane, centred at (x, z)."""
    pts = []
    if shape in ('oval', 'circle'):
        for k in range(n):
            a = 2 * math.pi * k / n
            pts.append((w / 2 * math.cos(a), h / 2 * math.sin(a)))
    elif shape in ('rect', 'bar', 'wrap', 'plate'):
        r = min(w, h) * (0.5 if shape == 'bar' else 0.22)
        for qx, qy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
            cx, cy = qx * (w / 2 - r), qy * (h / 2 - r)
            for k in range(n // 4):
                a = math.radians(a0 + 90 * k / (n // 4 - 1))
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    elif shape == 'wedge':
        # tapering toward the centre line (inner end thin)
        for k in range(n):
            u = k / (n - 1)
            pts.append((-w / 2 + w * u, h / 2 * (0.35 + 0.65 * u)))
        for k in range(n):
            u = 1 - k / (n - 1)
            pts.append((-w / 2 + w * u, -h / 2 * (0.35 + 0.65 * u)))
    elif shape == 'boomerang':
        # outer tall end sweeping to a slim inner blade
        for k in range(n):
            u = k / (n - 1)
            pts.append((w / 2 - w * u, h / 2 - h * 0.55 * u ** 1.5))
        for k in range(n):
            u = 1 - k / (n - 1)
            pts.append((w / 2 - w * u, h / 2 - h * 0.55 * u ** 1.5 - h * (0.45 + 0.55 * (1 - u)) * (1 - 0.6 * u)))
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    return [(x + px * c - py * s, z + px * s + py * c) for px, py in pts]


# ------------------------------------------------------------------ the car
class Car:
    def __init__(self, P, M):
        self.P = P; self.M = M
        L, W = P['length'], P['width']
        self.L, self.W = L, W
        self.y_rear = -L / 2
        self.root = empty('root')
        self.roll = empty('body_roll', self.root)
        self.outlined = []
        self.lamp_objs = []

    def T(self, t):
        return self.y_rear + t * self.L

    def top(self, t):
        return interp(self.P['top'], t)

    def hw(self, t):
        return interp(self.P['halfw'], t) * self.W / 2

    def bottom(self, t):
        c = self.P['clearance']
        # bumpers rise slightly at both ends
        lift = self.P.get('rearLift', 0.20)
        return c + lift * (1 - smooth(0.0, 0.16, t)) + 0.12 * smooth(0.90, 1.0, t)

    # -- body
    def build_body(self):
        P, M = self.P, self.M
        sec = P['section']; n = 34
        ts = [0.5 - 0.5 * math.cos(math.pi * i / (n - 1)) for i in range(n)]   # denser at the ends
        rings = [superellipse_ring(56, self.hw(t), self.bottom(t), self.top(t), sec['p'], sec['taper']) for t in ts]
        me = loft('body', rings, [self.T(t) for t in ts], cap=(0.07, 0.09))
        order = ['paint', 'trim', 'under', 'skid', 'interior', 'bed', 'well']
        rl = P.get('rearLower', 0.4); skid = P.get('skid', False)
        yr = self.y_rear

        def rule(c, nrm):
            if nrm.z < -0.55:
                return 'under'
            if c.y < yr + 0.35 and nrm.y < -0.35 and c.z < rl:
                return 'skid' if skid and c.z < rl - 0.12 and abs(c.x) < self.W * 0.30 else 'trim'
            if c.y > -yr - 0.35 and nrm.y > 0.35 and c.z < rl * 0.9:
                return 'trim'
            return 'paint'
        ob = new_obj('body', me, self.roll); attach(ob, order, M)
        subsurf(ob, 2)
        classify(ob.data, rule, order)   # on the dense mesh: clean region borders
        # wheel arches, cockpit, bed
        cut = []
        well = M['well']
        for t_ax in (P['rearAxle'] / self.L, (P['rearAxle'] + P['wheelbase']) / self.L):
            c = new_obj('arch', cyl_mesh('arch', P['wheelR'] + 0.045, self.W + 0.6, 40, 'X'), None,
                        (0, self.T(t_ax), P['wheelR']))
            c.data.materials.append(well); cut.append(c)
        cab = P['cabin']
        if cab['type'] == 'open':
            t0, t1 = cab['cockpit']
            hwc = self.hw((t0 + t1) / 2) * 0.80
            zt = self.top((t0 + t1) / 2)
            c = new_obj('cockpit', box_mesh('cockpit', hwc * 2, (t1 - t0) * self.L, 0.9, bevel=0.10, seg=3), None,
                        (0, self.T((t0 + t1) / 2), zt - 0.30 + 0.45))
            c.data.materials.append(M['interior']); cut.append(c)
        if 'bed' in P:
            b = P['bed']; hwb = self.W / 2 - b['wall']
            c = new_obj('bedcut', box_mesh('bedcut', hwb * 2, (b['t1'] - b['t0']) * self.L, 2.0, bevel=0.03), None,
                        (0, self.T((b['t0'] + b['t1']) / 2), b['floor'] + 1.0))
            c.data.materials.append(M['bed']); cut.append(c)
        boolean_cut(ob, cut)
        smooth_all(ob)
        self.body = ob
        self.outlined.append(ob)

    # -- cabin / greenhouse
    def build_cabin(self):
        P, M = self.P, self.M; cab = P['cabin']
        if cab['type'] == 'open':
            return self.build_open()
        rb, rt, ft, fb = cab['rearBase'], cab['rearTop'], cab['frontTop'], cab['frontBase']
        roofZ = cab['roofZ']; n = 30
        ts = [rb + (fb - rb) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1))) for i in range(n)]
        rings = []
        for t in ts:
            base = self.top(t) - 0.10
            if t < rt:
                u = smooth(rb, rt, t) ** 0.8
            elif t > ft:
                u = smooth(fb, ft, t) ** 0.9
            else:
                u = 1.0
            crown = 0.012 * math.sin(math.pi * min(1, max(0, (t - rt) / max(1e-3, ft - rt))))
            zt = max(base + 0.04, base + (roofZ + crown - base) * u)
            hb = self.hw(t) * cab['baseW']
            ht = max(0.05, hb - (hb - cab['roofW'] * self.W / 2) * min(1, u * 1.2))
            rings.append(trapezoid_ring(60, hb, ht, base, zt, 0.07))
        me = loft('cabin', rings, [self.T(t) for t in ts], cap=(0.02, 0.02))
        order = ['paint', 'glass', 'trim']
        roof_mat = 'glass' if cab.get('roof') == 'glass' else 'paint'
        pill = cab.get('pillars', 0.12)
        roof_len = ft - rt

        def rule(c, nrm):
            t = (c.y - self.y_rear) / self.L
            belt = self.top(t)
            if c.z < belt + 0.035:
                return 'paint'
            if nrm.z > 0.80 and rt - 0.01 <= t <= ft + 0.01:
                return roof_mat
            if nrm.y < -0.30:          # rear window, framed by the C-pillars
                lim = self.hw(t) * cab['baseW'] * 0.78
                return 'glass' if abs(c.x) < lim and c.z < roofZ - 0.04 else 'paint'
            if nrm.y > 0.30:           # windscreen
                lim = self.hw(t) * cab['baseW'] * 0.84
                return 'glass' if abs(c.x) < lim and c.z < roofZ - 0.03 else 'paint'
            if abs(nrm.x) > 0.35:      # side glass between pillars
                if t < rt + pill * roof_len or t > ft + 0.01 or c.z > roofZ - 0.045:
                    return 'paint'
                return 'glass'
            return roof_mat if c.z > roofZ - 0.05 else 'paint'
        ob = new_obj('cabin', me, self.roll); attach(ob, order, M)
        subsurf(ob, 2); classify(ob.data, rule, order); smooth_all(ob)
        self.outlined.append(ob)
        self.cabin = ob

    def build_open(self):
        P, M = self.P, self.M; cab = P['cabin']
        seatY = self.T(cab['seatT']); ztop = self.top(cab['seatT'])
        for sx in (-1, 1):
            x = sx * self.W * 0.215
            back = new_obj('seat', box_mesh('seat', 0.44, 0.12, 0.50, bevel=0.05, seg=3), self.roll,
                           (x, seatY + 0.02, ztop - 0.12))
            back.rotation_euler = (math.radians(-14), 0, 0)
            back.data.materials.append(M['seat']); smooth_all(back)
            head = new_obj('head', box_mesh('head', 0.26, 0.11, 0.17, bevel=0.05, seg=3), self.roll,
                           (x, seatY - 0.03, ztop + 0.22))
            head.rotation_euler = (math.radians(-14), 0, 0)
            head.data.materials.append(M['seat']); smooth_all(head)
            self.outlined += [back, head]
            if cab.get('hoops'):
                # roll hoop: half torus behind the headrest
                bm = bmesh.new(); r, rr, seg = 0.17, 0.022, 20
                verts_rings = []
                for i in range(seg + 1):
                    a = math.pi * i / seg
                    cpos = Vector((x + r * math.cos(a), seatY - 0.13, ztop - 0.02 + r * math.sin(a) * 1.25))
                    tan = Vector((-math.sin(a), 0, math.cos(a) * 1.25)).normalized()
                    nrm = tan.cross(Vector((0, 1, 0))).normalized()
                    bi = Vector((0, 1, 0))
                    ring = []
                    for k in range(10):
                        b = 2 * math.pi * k / 10
                        ring.append(bm.verts.new(cpos + rr * (math.cos(b) * nrm + math.sin(b) * bi)))
                    verts_rings.append(ring)
                for a, b in zip(verts_rings, verts_rings[1:]):
                    for k in range(10):
                        bm.faces.new((a[k], a[(k + 1) % 10], b[(k + 1) % 10], b[k]))
                me = bpy.data.meshes.new('hoop'); bm.to_mesh(me); bm.free()
                h = new_obj('hoop', me, self.roll); h.data.materials.append(M['trim']); smooth_all(h)
        if cab.get('tonneau'):
            t = cab['tonneau']
            tn = new_obj('tonneau', box_mesh('tonneau', self.hw(t) * 1.50, 0.16, 0.07, bevel=0.03, seg=3), self.roll,
                         (0, self.T(t), self.top(t) - 0.03))
            tn.data.materials.append(M['trim']); smooth_all(tn); self.outlined.append(tn)
        # windscreen: curved frame + glass, leaning back
        s0, s1 = cab['screen']; zb = self.top(s1) - 0.02; zt = cab['screenTop']
        yb, yt = self.T(s1), self.T(s0)
        def screen(name, inset, mat, off):
            nu, nv = 12, 6; verts = []; faces = []
            for j in range(nv + 1):
                v = j / nv; z = zb + (zt - zb) * v; y = yb + (yt - yb) * v
                hwv = self.hw(s1) * (0.93 - 0.10 * v) - inset
                for i in range(nu + 1):
                    u = -1 + 2 * i / nu; x = u * hwv
                    verts.append((x, y - 0.10 * u * u + off, z))
            for j in range(nv):
                for i in range(nu):
                    a = j * (nu + 1) + i
                    faces.append((a, a + 1, a + nu + 2, a + nu + 1))
            me = mesh_from(name, verts, faces)
            ob = new_obj(name, me, self.roll)
            sol = ob.modifiers.new('sol', 'SOLIDIFY'); sol.thickness = 0.02
            evaluated_copy(ob); ob.data.materials.append(M[mat]); smooth_all(ob)
            return ob
        frame = screen('screen_frame', 0.0, 'trim', 0.0)
        glass = screen('screen_glass', 0.035, 'glass', -0.012)
        self.outlined.append(frame)
        mirror = new_obj('rv_mirror', box_mesh('rv', 0.18, 0.03, 0.05, bevel=0.012), self.roll,
                         (0, yt - 0.04, zt - 0.07))
        mirror.data.materials.append(M['trim'])

    # -- rear details
    def project_rear(self, ob, offset=0.004):
        """Decal projection: every vertex is ray-cast along +Y onto the body (both share the
        body_roll space) and lifted `offset` along the surface normal; a ray that misses the
        silhouette falls back to the closest surface point, so nothing floats."""
        targets = [self.body] + ([self.cabin] if getattr(self, 'cabin', None) else []); miss = 0
        for v in ob.data.vertices:
            best = None
            for tgt in targets:
                hit, loc, nrm, _ = tgt.ray_cast(Vector((v.co.x, self.y_rear - 1.0, v.co.z)), Vector((0, 1, 0)))
                if hit and (best is None or loc.y < best[0].y):
                    best = (loc, nrm)
            if best is None:
                miss += 1
                cands = [tgt.closest_point_on_mesh(v.co) for tgt in targets]
                cands = [(c[1], c[2]) for c in cands if c[0] ]
                best = min(cands, key=lambda c: (c[0] - v.co).length)
            loc, nrm = best
            v.co = loc + nrm * offset
        ob.data.update()
        return miss

    def rear_shape(self, name, outline, mat, offset, thick=0.0):
        ob = new_obj(name, polar_shape_mesh(name, outline, self.y_rear - 0.4, thick), self.roll)
        miss = self.project_rear(ob, offset)
        ob.data.materials.append(self.M[mat]); smooth_all(ob)
        if miss:
            print(f'note: {name}: {miss} vertices wrapped to the nearest surface', file=sys.stderr)
        return ob

    def build_rear(self):
        P = self.P
        if 'panel' in P:
            p = P['panel']
            self.rear_shape('panel', shape_outline('rect', 0, p['z'], p['w'] * self.W, p['h']), 'trim', 0.003)
        for lamp in P['lamps']:
            sides = [0] if lamp.get('center') else [-1, 1]
            for sx in sides:
                # x is a fraction of the REAR face half-width; keep the lamp on that face
                rhw = self.hw(0.0)
                w, h = lamp['w'], lamp['h']
                x = sx * min(lamp['x'] * rhw, rhw * 0.90 - w / 2) if sx else 0.0
                rot = lamp.get('rot', 0) * (sx if sx else 1)
                parts = []
                shape = lamp['shape']
                if shape == 'L':
                    parts = [('rect', x + sx * (w * 0.5 - 0.035), lamp['z'], 0.07, h, 0),
                             ('rect', x, lamp['z'] + h / 2 - 0.03, w, 0.06, 0)]
                elif shape == 'tribar':
                    for k in range(3):
                        parts.append(('rect', x + sx * (k - 1) * w / 3.2, lamp['z'], w / 4.4, h, 0))
                elif shape == 'wrap':
                    parts = [('rect', x, lamp['z'], w, h, 0)]
                else:
                    parts = [(shape, x, lamp['z'], w, h, rot)]
                mat = lamp.get('mat', 'lamp')
                for k, (shp, px, pz, pw, ph, pr) in enumerate(parts):
                    outline = shape_outline(shp, px, pz, pw, ph, pr)
                    if sx < 0 and shp in ('wedge', 'boomerang'):
                        outline = [(2 * px - ox, oz) for ox, oz in outline]
                    if lamp.get('rim'):
                        rim = shape_outline(shp, px, pz, pw + 0.035, ph + 0.035, pr)
                        if sx < 0 and shp in ('wedge', 'boomerang'):
                            rim = [(2 * px - ox, oz) for ox, oz in rim]
                        self.rear_shape(f'lamprim_{sx}_{k}', rim, 'trim', 0.004)
                    ob = self.rear_shape(f'lamp_{sx}_{k}', outline, mat, 0.008)
                    if lamp.get('brake', mat == 'lamp'):
                        self.lamp_objs.append(ob)   # brake-lamp reference points
                    if mat == 'lamp' and shp not in ('circle',):
                        # a brighter inner core reads as a lens at small sizes
                        core = shape_outline(shp, px, pz, pw * 0.62, ph * 0.45, pr)
                        if sx < 0 and shp in ('wedge', 'boomerang'):
                            core = [(2 * px - ox, oz) for ox, oz in core]
                        self.rear_shape(f'lampcore_{sx}_{k}', core, 'lamp_core', 0.011)
        pl = P.get('plate')
        if pl:
            self.rear_shape('plate_rim', shape_outline('plate', 0, pl['z'], pl['w'] + 0.04, pl['h'] + 0.04), 'trim', 0.004)
            self.rear_shape('plate', shape_outline('plate', 0, pl['z'], pl['w'], pl['h']), 'plate', 0.008)
        if P.get('bumper'):
            b = new_obj('bumper', box_mesh('bumper', self.W * 0.97, 0.20, 0.17, bevel=0.035, seg=3), self.roll,
                        (0, self.y_rear + 0.04, self.bottom(0.0) + 0.02))
            b.data.materials.append(self.M['skid']); smooth_all(b); self.outlined.append(b)
        if P.get('diffuser'):
            for k in range(-2, 3):
                f = new_obj('fin', box_mesh('fin', 0.015, 0.25, 0.10, bevel=0.004), self.roll,
                            (k * self.W * 0.12, self.y_rear + 0.10, self.bottom(0.0) + 0.02))
                f.data.materials.append(self.M['trim'])
        ex = P.get('exhaust', {'type': 'none'})
        xs = {'dual': lambda x: [-x, x], 'quad': lambda x: [-x, -x + 0.11, x - 0.11, x],
              'triple': lambda x: [-0.10, 0.0, 0.10], 'single': lambda x: [-x], 'none': lambda x: []}[ex['type']](ex.get('x', 0) * self.W / 2)
        for i, x in enumerate(xs):
            r = ex['r'] * (0.7 if ex['type'] == 'triple' and abs(x) < 1e-6 else 1)
            tip = new_obj('exhaust', cyl_mesh('ex', r, 0.30, 24, 'Y'), self.roll, (x, self.y_rear + 0.10, ex['z']))
            tip.data.materials.append(self.M['chrome']); smooth_all(tip)
            hole = new_obj('exhole', cyl_mesh('exh', r * 0.72, 0.02, 24, 'Y'), self.roll, (x, self.y_rear - 0.052, ex['z']))
            hole.data.materials.append(self.M['rim_dark'])
            self.outlined.append(tip)
        sp = P.get('spoiler', {'type': 'none'})
        if sp['type'] == 'wing':
            y = self.y_rear + 0.30
            w = new_obj('wing', box_mesh('wing', sp['w'], sp['chord'], sp['t'] * 2, bevel=0.012, seg=2), self.roll,
                        (0, y, sp['z'] + 0.10))
            w.rotation_euler = (math.radians(-6), 0, 0)
            w.data.materials.append(self.M['trim']); smooth_all(w); self.outlined.append(w)
            for sx in (-1, 1):
                up = new_obj('upright', box_mesh('up', 0.03, 0.10, 0.16, bevel=0.008), self.roll,
                             (sx * sp['w'] * 0.30, y, sp['z'] + 0.02))
                up.data.materials.append(self.M['trim'])
                ep = new_obj('endplate', box_mesh('ep', 0.012, sp['chord'] * 1.1, 0.11, bevel=0.004), self.roll,
                             (sx * sp['w'] / 2, y, sp['z'] + 0.10))
                ep.data.materials.append(self.M['trim'])
        elif sp['type'] in ('lip', 'ducktail'):
            h = 0.03 if sp['type'] == 'lip' else 0.06
            lp = new_obj('lip', box_mesh('lip', sp['w'], 0.12, h, bevel=h * 0.45, seg=2), self.roll,
                         (0, self.y_rear + 0.10, sp['z']))
            lp.rotation_euler = (math.radians(10), 0, 0)
            lp.data.materials.append(self.M['paint' if sp['type'] == 'ducktail' else 'trim']); smooth_all(lp)
            self.outlined.append(lp)
        elif sp['type'] == 'roof':
            cab = P['cabin']
            y = self.T(cab['rearTop']) - 0.06
            rs = new_obj('roofspoiler', box_mesh('rs', sp['w'], 0.22, 0.04, bevel=0.018, seg=2), self.roll,
                         (0, y, cab['roofZ'] - 0.005))
            rs.rotation_euler = (math.radians(-4), 0, 0)
            rs.data.materials.append(self.M['paint']); smooth_all(rs); self.outlined.append(rs)
        mi = P.get('mirrors')
        if mi:
            for sx in (-1, 1):
                x = sx * (self.hw(mi['t']) + 0.07)
                bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
                for v in bm.verts:
                    v.co = Vector((v.co.x * 0.085, v.co.y * 0.055, v.co.z * 0.055))
                me = bpy.data.meshes.new('mirror'); bm.to_mesh(me); bm.free()
                m = new_obj('mirror', me, self.roll, (x, self.T(mi['t']), mi['z']))
                m.data.materials.append(self.M['paint']); smooth_all(m); self.outlined.append(m)
                g = new_obj('mirror_glass', box_mesh('mg', 0.13, 0.01, 0.07, bevel=0.02, seg=2), self.roll,
                            (x, self.T(mi['t']) - 0.056, mi['z']))
                g.data.materials.append(self.M['glass'])
                st = new_obj('stalk', box_mesh('st', 0.09, 0.04, 0.02), self.roll,
                             (x - sx * 0.07, self.T(mi['t']), mi['z'] - 0.03))
                st.data.materials.append(self.M['trim'])

    # -- wheels
    def build_wheels(self):
        P, M = self.P, self.M
        R, Wt = P['wheelR'], P['tyreW']; rim_r = R * 0.68
        style = P['wheel'].get('style', 'spoke5')
        self.hubs = {}
        for axle, t_ax in (('rear', P['rearAxle']), ('front', P['rearAxle'] + P['wheelbase'])):
            for sx in (-1, 1):
                hub = empty(f'hub_{axle}_{sx}', self.root, (sx * P['track'] / 2, self.y_rear + t_ax, R))
                self.hubs[(axle, sx)] = hub
                self.wheel(hub, sx, R, Wt, rim_r, style)

    def wheel(self, hub, sx, R, Wt, rim_r, style):
        M = self.M
        # tyre: revolve a rounded cross-section about the X axis
        prof = []
        for k in range(20):
            a = 2 * math.pi * k / 20
            px = (Wt / 2) * spow(math.cos(a), 0.55)
            pr = (R + rim_r * 0.95) / 2 + ((R - rim_r * 0.95) / 2) * spow(math.sin(a), 0.6)
            prof.append((px, pr))
        seg = 40; verts = []; faces = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            for px, pr in prof:
                verts.append((px, pr * math.cos(th), pr * math.sin(th)))
        np_ = len(prof)
        for i in range(seg):
            for k in range(np_):
                a = i * np_ + k; b = i * np_ + (k + 1) % np_
                c = ((i + 1) % seg) * np_ + (k + 1) % np_; d = ((i + 1) % seg) * np_ + k
                faces.append((a, b, c, d))
        me = mesh_from('tyre', verts, faces)
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        ty = new_obj('tyre', me, hub); ty.data.materials.append(M['tyre']); smooth_all(ty)
        self.outlined.append(ty)
        face_x = sx * (Wt / 2 - 0.012)
        # dark barrel, then the rim face on the outer side
        barrel = new_obj('barrel', cyl_mesh('barrel', rim_r * 0.98, Wt * 0.9, 32, 'X'), hub)
        barrel.data.materials.append(M['rim_dark'])
        lip_bm = bmesh.new()
        bmesh.ops.create_circle(lip_bm, cap_ends=False, segments=36, radius=rim_r)
        me = bpy.data.meshes.new('lip'); lip_bm.to_mesh(me); lip_bm.free()
        lip = new_obj('lip', cyl_mesh('lip', rim_r, 0.02, 36, 'X'), hub, (face_x, 0, 0))
        lip.data.materials.append(M['rim'])
        n_sp, sw = {'spoke5': (5, 0.30), 'turbine': (10, 0.10), 'mesh': (12, 0.07), 'split': (10, 0.08), 'steel': (0, 0)}[style]
        hole = new_obj('rimhole', cyl_mesh('rh', rim_r * 0.90, 0.024, 36, 'X'), hub, (face_x + sx * 0.002, 0, 0))
        hole.data.materials.append(M['rim_dark'])
        if style == 'steel':
            d = new_obj('disc', cyl_mesh('disc', rim_r * 0.86, 0.02, 36, 'X'), hub, (face_x + sx * 0.006, 0, 0))
            d.data.materials.append(M['rim'])
        for k in range(n_sp):
            a = 2 * math.pi * k / n_sp + (0.12 if style == 'split' and k % 2 else 0)
            sp = new_obj('spoke', box_mesh('sp', 0.016, rim_r * sw * (1.0 if style != 'spoke5' else 0.9), rim_r * 0.82), hub,
                         (face_x + sx * 0.008, math.sin(a) * -rim_r * 0.45, math.cos(a) * rim_r * 0.45))
            sp.rotation_euler = (a + (0.35 if style == 'turbine' else 0), 0, 0)
            sp.data.materials.append(M['rim'])
        cap = new_obj('cap', cyl_mesh('cap', rim_r * 0.20, 0.03, 20, 'X'), hub, (face_x + sx * 0.012, 0, 0))
        cap.data.materials.append(M['rim'])

    def build(self):
        self.build_body()
        self.build_cabin()
        self.build_rear()
        self.build_wheels()
        self.make_outlines()

    def make_outlines(self, t=0.011):
        self.outline_objs = []
        for ob in self.outlined:
            if ob.name not in bpy.data.objects:
                continue
            bm = bmesh.new(); bm.from_mesh(ob.data)
            bm.normal_update()
            for v in bm.verts:
                v.co += v.normal * t
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
            me = bpy.data.meshes.new(ob.name + '_ol'); bm.to_mesh(me); bm.free()
            me.materials.clear(); me.materials.append(self.M['outline'])
            for p in me.polygons:
                p.material_index = 0; p.use_smooth = True
            o = new_obj(ob.name + '_ol', me, ob.parent, ob.location.copy())
            o.rotation_euler = ob.rotation_euler.copy()
            o.visible_shadow = False
            self.outline_objs.append(o)

    def pose(self, p):
        # Yaw/pitch pivot on the ground under the REAR axle: the chase camera follows the
        # rear of the car, so a turn swings the (mostly hidden) nose, not the tail.
        self.root.rotation_mode = 'ZXY'
        e = Euler((math.radians(p['pitch']), 0, math.radians(p['yaw'])), 'ZXY')
        self.root.rotation_euler = e
        pivot = Vector((0, self.y_rear + self.P['rearAxle'], 0))
        self.root.location = pivot - e.to_matrix() @ pivot
        self.roll.rotation_euler = (0, math.radians(p['roll']), 0)
        for (axle, sx), hub in self.hubs.items():
            # Only front hubs steer. Rear hubs are rigid: aligned with the body in every pose.
            hub.rotation_euler = (0, 0, math.radians(p['steer']) if axle == 'front' else 0.0)
        bpy.context.view_layer.update()


# ------------------------------------------------------------------ scene / camera / render
def setup_scene(threads, samples, res):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'; sc.cycles.samples = samples
    sc.cycles.use_denoising = False; sc.cycles.use_adaptive_sampling = False
    sc.cycles.transparent_max_bounces = 16; sc.cycles.max_bounces = 0
    sc.cycles.seed = 0
    sc.render.threads_mode = 'FIXED'; sc.render.threads = threads
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res; sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('world')
    sc.world.color = (0, 0, 0)
    global COLL
    COLL = sc.collection
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    COLL.objects.link(cam); sc.camera = cam
    return sc, cam


def place_camera(cam, cfg, car):
    yr = car.y_rear
    pos = Vector((0, yr - cfg['distance'], cfg['height']))
    target = Vector((0, yr + 1.5, cfg['targetZ']))
    d = target - pos
    cam.location = pos
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = cfg['lensMm']; cam.data.sensor_width = cfg['sensorMm']; cam.data.sensor_fit = 'HORIZONTAL'
    cam.data.clip_start = 0.5; cam.data.clip_end = 60
    return pos, target


def project(sc, cam, co):
    v = world_to_camera_view(sc, cam, Vector(co))
    res = sc.render.resolution_x
    return [round(v.x * res, 2), round((1 - v.y) * res, 2)]


def render(sc, path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def set_paint(M, hex_colour):
    _, gloss, env = MAT_SPECS['paint']
    toon('paint', hex_colour, gloss, env, hint='#d04030')


def hero_passes(sc, car, outdir, passes):
    obs = [o for o in bpy.data.objects if o.type == 'MESH']
    ols = set(o.name for o in car.outline_objs)
    saved = {o.name: [s.material for s in o.material_slots] for o in obs}
    for o in obs:
        if o.name in ols:
            o.hide_render = True
    os.makedirs(outdir, exist_ok=True)
    if 'clay' in passes or 'hint' in passes:
        sc.render.engine = 'BLENDER_WORKBENCH'
        sh = sc.display.shading
        sc.display.render_aa = '8'
        for kind in ('clay', 'hint'):
            if kind not in passes:
                continue
            if kind == 'clay':
                sh.light = 'STUDIO'; sh.color_type = 'SINGLE'; sh.single_color = (0.62, 0.62, 0.62)
                sh.show_cavity = True; sh.cavity_type = 'BOTH'; sh.show_shadows = True; sh.shadow_intensity = 0.35
                sc.display.light_direction = tuple(LIGHT)
            else:
                sh.light = 'FLAT'; sh.color_type = 'MATERIAL'; sh.show_cavity = False; sh.show_shadows = False
            render(sc, os.path.join(outdir, kind + '.png'))
        sc.render.engine = 'CYCLES'
    if 'depth' in passes:
        near, far = 4.0, 14.0
        dm = depth_material(near, far)
        for o in obs:
            if o.name in ols:
                continue
            for s in o.material_slots:
                s.material = dm
        render(sc, os.path.join(outdir, 'depth.png'))
        for o in obs:
            for s, m in zip(o.material_slots, saved[o.name]):
                s.material = m
    for o in obs:
        o.hide_render = False


def render_keycard(out, threads, samples):
    """Garage prop: a keyring, short strap and a plain white key card (no marks or text),
    hanging from the ring, seen straight on with the same cel materials and light."""
    sc, cam = setup_scene(threads, samples, 512)
    M = {'card': toon('card', '#f4f3ef', 0.6, 0.25), 'edge': toon('edge', '#c9ccd2', 0.5, 0.2),
         'ring': toon('ring', '#c9ccd0', 0.9, 0.45), 'strap': toon('strap', '#2c2f36', 0.2, 0.1),
         'stripe': toon('stripe', '#9aa3ad', 0.4, 0.2), 'outline': outline_material()}
    parts = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=1, radius2=1, depth=1)
    me = bpy.data.meshes.new('ringm'); bm.to_mesh(me); bm.free()
    # torus ring
    bm = bmesh.new(); R, r, nu, nv = 0.17, 0.018, 40, 10; rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu; ring = []
        for k in range(nv):
            b = 2 * math.pi * k / nv
            ring.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), r * math.sin(b), 1.30 + (R + r * math.cos(b)) * math.sin(a))))
        rings.append(ring)
    for i in range(nu):
        a, b2 = rings[i], rings[(i + 1) % nu]
        for k in range(nv):
            bm.faces.new((a[k], a[(k + 1) % nv], b2[(k + 1) % nv], b2[k]))
    me = bpy.data.meshes.new('ring'); bm.to_mesh(me); bm.free()
    ring = new_obj('ring', me); ring.data.materials.append(M['ring']); smooth_all(ring); parts.append(ring)
    strap = new_obj('strap', box_mesh('strap', 0.11, 0.03, 0.30, bevel=0.012, seg=2), None, (0, 0, 1.0))
    strap.data.materials.append(M['strap']); parts.append(strap)
    card = new_obj('card', box_mesh('card', 0.54, 0.03, 0.86, bevel=0.06, seg=4), None, (0, 0, 0.42))
    card.data.materials.append(M['card']); parts.append(card)
    stripe = new_obj('stripe', box_mesh('stripe', 0.40, 0.004, 0.035), None, (0, -0.016, 0.20))
    stripe.data.materials.append(M['stripe'])
    for ob in parts:
        bm = bmesh.new(); bm.from_mesh(ob.data); bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * 0.012
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        me = bpy.data.meshes.new(ob.name + '_ol'); bm.to_mesh(me); bm.free()
        o = new_obj(ob.name + '_ol', me, None, ob.location.copy()); o.data.materials.append(M['outline'])
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.75
    cam.location = (0, -6, 0.78); cam.rotation_euler = (math.radians(90), 0, 0)
    os.makedirs(out, exist_ok=True)
    render(sc, os.path.join(out, 'keycard.png'))
    print('keycard rendered', flush=True)


# ------------------------------------------------------------------ departure scenes
# The garage departure shows the chosen car three more times: parked outside (exterior), the
# driver door opened (door) and the first-person cabin (cabin). For a rig car these views are
# rendered from the same parametric body, hollowed into a cockpit with a seat, dashboard,
# steering wheel and an opening driver door (left-hand drive, -x side).

class SceneCar(Car):
    """The rig car opened up for the departure views. Instead of solid booleans the shells
    are cut open (faces deleted): seen from inside, a shell's back faces render in the
    interior colour (see inside_materials), so the cockpit is a clean cavity."""

    def __init__(self, P, M, door_open):
        super().__init__(P, M)
        self.door_open = door_open

    def _split(self, ob, pick):
        """Remove faces where pick(center, normal) is true; return them as a new object."""
        me = ob.data
        keep = bpy.data.meshes.new(ob.name + '_piece'); keep = me.copy()
        bm = bmesh.new(); bm.from_mesh(me)
        sel = [f for f in bm.faces if pick(f.calc_center_median(), f.normal)]
        bmesh.ops.delete(bm, geom=sel, context='FACES'); bm.to_mesh(me); bm.free(); me.update()
        bm = bmesh.new(); bm.from_mesh(keep)
        rest = [f for f in bm.faces if not pick(f.calc_center_median(), f.normal)]
        bmesh.ops.delete(bm, geom=rest, context='FACES'); bm.to_mesh(keep); bm.free(); keep.update()
        return new_obj(ob.name + '_piece', keep, ob.parent, ob.location.copy()) if len(keep.polygons) else None

    def build(self):
        P, M = self.P, self.M; cab = P['cabin']
        self.build_body()
        self.build_cabin()
        y0, y1 = self.T(cab['rearBase'] + 0.04), self.T(cab['frontBase'] - 0.03)
        hw = self.hw(0.5)
        # open the body top under the greenhouse and drop the greenhouse floor
        for piece in (self._split(self.body, lambda c, n: n.z > 0.25 and y0 < c.y < y1 and abs(c.x) < hw * 0.84),
                      self._split(self.cabin, lambda c, n: n.z < -0.4)):
            if piece:
                bpy.data.objects.remove(piece, do_unlink=True)
        self.build_interior()
        self.build_rear()
        self.build_wheels()
        if self.door_open:
            self.open_door()
        self.make_outlines()

    def build_interior(self):
        P, M = self.P, self.M; cab = P['cabin']
        x = -0.36
        seat_y = self.T(cab['rearTop'] + 0.07)
        floor = P['clearance'] + 0.14
        def part(name, sx, sy, sz, loc, mat, rot=(0, 0, 0), bevel=0.04):
            o = new_obj(name, box_mesh(name, sx, sy, sz, bevel=bevel, seg=3), self.roll, loc)
            o.rotation_euler = rot; o.data.materials.append(M[mat]); smooth_all(o)
            self.outlined.append(o)
            return o
        part('floor', self.hw(0.45) * 1.7, (cab['frontBase'] - cab['rearBase']) * self.L, 0.04,
             (0, self.T((cab['rearBase'] + cab['frontBase']) / 2), floor - 0.02), 'interior', bevel=0.0)
        for sx in (-1, 1):
            part('seat_base', 0.48, 0.50, 0.14, (sx * 0.36, seat_y + 0.10, floor + 0.12), 'seat')
            part('seat_back', 0.48, 0.12, 0.62, (sx * 0.36, seat_y - 0.14, floor + 0.46), 'seat', (math.radians(-16), 0, 0))
        part('console', 0.20, 1.0, 0.22, (0, seat_y + 0.45, floor + 0.12), 'interior')
        dash_y = self.T(cab['frontBase']) - 0.30
        dash_z = self.top(cab['frontBase'] - 0.04) - 0.02
        part('dash', self.hw(0.62) * 1.70, 0.50, 0.30, (0, dash_y, dash_z - 0.13), 'interior', bevel=0.08)
        part('screen', 0.30, 0.025, 0.19, (0.02, dash_y - 0.26, dash_z + 0.03), 'glass', (math.radians(-18), 0, 0), bevel=0.012)
        bm = bmesh.new(); R, r, nu, nv = 0.175, 0.022, 36, 10; rings = []
        for i in range(nu):
            a = 2 * math.pi * i / nu; ring = []
            for k in range(nv):
                b = 2 * math.pi * k / nv
                ring.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), r * math.sin(b), (R + r * math.cos(b)) * math.sin(a))))
            rings.append(ring)
        for i in range(nu):
            a, b2 = rings[i], rings[(i + 1) % nu]
            for k in range(nv):
                bm.faces.new((a[k], a[(k + 1) % nv], b2[(k + 1) % nv], b2[k]))
        for k in range(3):
            ang = math.radians(-90 + 120 * k)
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((math.cos(ang) * R / 2, 0, math.sin(ang) * R / 2))
                                  @ Matrix.Rotation(-ang, 4, 'Y') @ Matrix.Diagonal((R, 0.02, 0.035, 1)))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.06, radius2=0.06, depth=0.05,
                              matrix=Matrix.Rotation(math.pi / 2, 4, 'X'))
        me = bpy.data.meshes.new('wheel'); bm.to_mesh(me); bm.free()
        sw = new_obj('steering', me, self.roll, (x, dash_y - 0.42, dash_z - 0.04))
        sw.rotation_euler = (math.radians(-22), 0, 0)
        sw.data.materials.append(M['trim']); smooth_all(sw); self.outlined.append(sw)

    def open_door(self):
        """Cut the driver door out of the body and cabin shells, give it real thickness
        (outer skin keeps the toon body paint, the inside becomes a darker trimmed panel with
        an armrest, pull handle, release lever and speaker) and swing it on its front hinge.
        Without thickness the camera, which stands behind the open door, saw only the
        shells' back faces: flat, untextured grey slabs."""
        P, M = self.P, self.M; cab = P['cabin']
        d0, d1 = cab['rearTop'] + 0.06, cab['frontBase'] - 0.03
        y0, y1 = self.T(d0), self.T(d1)
        z0 = P['clearance'] + 0.10; z1 = cab['roofZ'] - 0.05
        x_in = -self.hw(0.5) * 0.45
        def pick(c, n):
            return c.x < x_in and y0 < c.y < y1 and z0 < c.z < z1 and n.x < -0.2
        hinge = Vector((-self.hw(d1) * 0.98, y1, 0))
        ang = math.radians(-62)
        R = Matrix.Rotation(ang, 3, 'Z')
        if 'door_panel' not in M:
            M['door_panel'] = toon('door_panel', '#4d4641', gloss=0.10, env=0.06, hint='#504038')
            M['door_cap'] = toon('door_cap', '#24211f', gloss=0.20, env=0.10, hint='#302820')
            M['door_insert'] = toon('door_insert', '#7a6f63', gloss=0.05, env=0.04, hint='#706050')
        parts = []
        skin_z = []          # (z, inner x) samples of the door skin for placing the trim
        for ob, thick, inner in ((self.body, 0.07, 'door_panel'), (self.cabin, 0.03, 'door_cap')):
            p = self._split(ob, pick)
            if p is None:
                continue
            mats = list(p.data.materials)
            if inner and M[inner] not in mats:
                p.data.materials.append(M[inner])
            sol = p.modifiers.new('door_skin', 'SOLIDIFY')
            sol.thickness = thick; sol.offset = -1.0; sol.use_rim = True; sol.use_even_offset = True
            evaluated_copy(p)
            me = p.data
            ii = list(me.materials).index(M[inner])
            glass = list(me.materials).index(M['glass']) if M['glass'] in list(me.materials) else -1
            for f in me.polygons:
                # the solidified inner shell faces into the car (+x); window glass
                # stays glass, painted window frame turns into dark trim
                if f.normal.x > 0.35 and f.material_index != glass:
                    f.material_index = ii
                    if ob is self.body:
                        skin_z.append((f.center.z, f.center.x))
            parts.append(p)
        if skin_z:
            def inner_x(z, band=0.08):
                xs = [x for zz, x in skin_z if abs(zz - z) < band] or [x for _, x in skin_z]
                return sum(xs) / len(xs)
            zs = [z for z, _ in skin_z]
            lo, hi = min(zs), max(zs)
            span = y1 - y0
            def trim(name, sx, sy, sz, y, z, mat, bevel=0.012, inset=0.0):
                o = new_obj(name, box_mesh(name, sx, sy, sz, bevel=bevel, seg=2), self.body.parent,
                            (inner_x(z) + sx / 2 - 0.004 + inset, y, z))
                o.data.materials.append(M[mat]); smooth_all(o)
                parts.append(o)
                return o
            arm_z = lo + (hi - lo) * 0.62
            # armrest running most of the door, a pull grip and a lower map pocket
            trim('door_armrest', 0.075, span * 0.55, 0.055, y0 + span * 0.42, arm_z, 'door_cap', 0.018)
            trim('door_grip', 0.05, 0.16, 0.035, y0 + span * 0.62, arm_z + 0.06, 'door_cap', 0.012)
            trim('door_pocket', 0.04, span * 0.60, 0.11, y0 + span * 0.48, lo + (hi - lo) * 0.22, 'door_cap', 0.012)
            trim('door_insert', 0.012, span * 0.62, (hi - lo) * 0.20, y0 + span * 0.46,
                 arm_z + (hi - lo) * 0.16, 'door_insert', 0.006)
            trim('door_sill', 0.03, span * 0.94, 0.03, y0 + span * 0.5, hi - 0.015, 'door_cap', 0.008)
            trim('door_release', 0.02, 0.07, 0.03, y0 + span * 0.80, arm_z + 0.14, 'chrome', 0.006)
            spk = new_obj('door_speaker', cyl_mesh('door_speaker', 0.075, 0.02, seg=28, axis='X'),
                          self.body.parent, (inner_x(lo + 0.12) + 0.008, y0 + span * 0.80, lo + (hi - lo) * 0.24))
            spk.data.materials.append(M['door_insert']); smooth_all(spk); parts.append(spk)
        for p in parts:
            # pieces live in their parent's space; swing every vertex about the hinge
            off = p.location.copy()
            for v in p.data.vertices:
                v.co = R @ (v.co + off - hinge) + hinge - off
            p.data.update(); self.outlined.append(p)
        for ob in list(self.roll.children):
            if ob.name.startswith(('mirror', 'stalk')) and ob.location.x < 0:
                ob.location = R @ (ob.location - hinge) + hinge
                ob.rotation_euler = (0, 0, ang)


def inside_materials(M, hex_colour='#3b3633'):
    """Back faces (a shell seen from inside) render as flat interior trim."""
    for name, m in M.items():
        if name in ('outline', 'clear') or not m.node_tree:
            continue
        nt = m.node_tree
        out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
        src = out.inputs['Surface'].links[0].from_socket
        geo = nt.nodes.new('ShaderNodeNewGeometry')
        em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*lin(hex_colour), 1)
        mix = nt.nodes.new('ShaderNodeMixShader')
        nt.links.new(geo.outputs['Backfacing'], mix.inputs[0])
        nt.links.new(src, mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs['Surface'])


def look(cam, pos, target, lens, roll=0.0):
    cam.location = Vector(pos)
    d = Vector(target) - Vector(pos)
    q = d.to_track_quat('-Z', 'Y')
    cam.rotation_euler = (q @ __import__('mathutils').Quaternion((0, 0, 1), roll)).to_euler()
    cam.data.lens = lens; cam.data.sensor_width = 36; cam.data.sensor_fit = 'HORIZONTAL'
    cam.data.clip_start = 0.05; cam.data.clip_end = 80


def render_scenes(P, out, threads, samples, cfg):
    os.makedirs(out, exist_ok=True)
    shots = cfg['scenes']
    for door_open, names in ((True, ['door']), (False, ['exterior', 'cabin'])):
        sc, cam = setup_scene(threads, samples, 1024)
        M = make_materials(P, P['paints'][0])
        M['clear'] = bpy.data.materials.new('clear'); M['clear'].use_nodes = True
        nt = M['clear'].node_tree; nt.nodes.clear()
        tr = nt.nodes.new('ShaderNodeBsdfTransparent'); o = nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(tr.outputs[0], o.inputs['Surface'])
        car = SceneCar(P, M, door_open); car.build()
        inside_materials(M)
        for name in names:
            s = shots[name]
            sc.render.resolution_x, sc.render.resolution_y = s['size']
            car.root.rotation_euler = (0, 0, math.radians(s.get('yaw', 0)))
            bpy.context.view_layer.update()
            look(cam, s['camera'], s['target'], s['lens'], math.radians(s.get('roll', 0)))
            cam.data.shift_x, cam.data.shift_y = s.get('shift', [0, 0])
            inside = name == 'cabin'
            for ol in car.outline_objs:
                ol.hide_render = inside
            if inside:
                # see out through the windscreen: its glass faces become clear
                gi = [i for i, sl in enumerate(car.cabin.material_slots) if sl.material == M['glass']]
                car.cabin.data.materials.append(M['clear']); ci = len(car.cabin.data.materials) - 1
                for p in car.cabin.data.polygons:
                    # windscreen, and the glass roof when the car has one
                    if p.material_index in gi and (p.normal.y > 0.3 or p.normal.z > 0.75):
                        p.material_index = ci
            render(sc, os.path.join(out, name + '.png'))
        print('scenes:', names, flush=True)


def main(argv):
    pos, kv = opts(argv)
    cars_path, poses_path, out = pos[:3]
    cars = json.load(open(cars_path))['cars']; poses = json.load(open(poses_path))
    ids = kv.get('ids'); ids = ids.split(',') if ids else None
    sheets = kv.get('sheets', 'body,turn,traffic').split(',')
    passes = [p for p in kv.get('passes', '').split(',') if p]
    samples = int(kv.get('samples', 12)); threads = min(8, int(kv.get('threads', 8)))
    res = int(kv.get('res', poses['camera']['renderPx']))
    cfg = poses['camera']
    if kv.get('prop') == 'keycard':
        return render_keycard(os.path.join(out, 'props'), threads, samples)
    if kv.get('prop') == 'scenes':
        P = [c for c in cars if c['id'] == kv.get('ids', 'electric_roadster')][0]
        return render_scenes(P, os.path.join(out, P['id'], 'scenes'), threads, samples, poses)
    global LIGHT
    LIGHT = Vector(cfg['lightDirection']).normalized()
    for P in cars:
        if ids and P['id'] not in ids:
            continue
        t0 = time.time()
        sc, cam = setup_scene(threads, samples, res)
        M = make_materials(P, P['paints'][0])
        car = Car(P, M); car.build()
        cpos, ctarget = place_camera(cam, cfg, car)
        cdir = os.path.join(out, P['id']); os.makedirs(cdir, exist_ok=True)
        if kv.get('blend') == '1':
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(cdir, 'car.blend'))
        record = {'id': P['id'], 'params': P, 'camera': {**cfg, 'position': list(cpos), 'target': list(ctarget), 'renderPx': res},
                  'render': {'engine': 'CYCLES', 'samples': samples, 'seed': 0, 'blender': bpy.app.version_string,
                             'material': 'emission cel: 3 soft bands + specular band + fresnel sky, outline hull 11 mm'},
                  'renders': []}
        lamp_pts = [o for o in car.lamp_objs]
        for sheet in sheets:
            use = P.get('use', [])
            if sheet in ('body', 'turn') and 'player' not in use:
                continue
            if sheet == 'traffic' and 'traffic' not in use:
                continue
            paints = list(enumerate(P['paints'])) if sheet == 'traffic' else [(0, P['paints'][0])]
            for pi, paint in paints:
                set_paint(M, paint)
                for k, p in enumerate(poses['sheets'][sheet]):
                    car.pose(p)
                    name = f"{p['name']}" + (f"_p{pi}" if sheet == 'traffic' else '')
                    path = os.path.join(cdir, sheet, name + '.png')
                    os.makedirs(os.path.dirname(path), exist_ok=True)
                    render(sc, path)
                    lamps = []
                    for o in lamp_pts:
                        c = sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
                        lamps.append(project(sc, cam, c))
                    record['renders'].append({
                        'sheet': sheet, 'index': k, 'pose': p, 'paint': paint, 'paintIndex': pi,
                        'file': os.path.relpath(path, cdir),
                        'groundCentre': project(sc, cam, car.root.matrix_world @ Vector((0, 0, 0))),
                        'groundRear': project(sc, cam, car.root.matrix_world @ Vector((0, car.y_rear, 0))),
                        'lamps': lamps,
                    })
        if passes:
            set_paint(M, P['paints'][0]); car.pose(poses['sheets']['body'][0])
            hero_passes(sc, car, os.path.join(cdir, 'hero'), passes)
            render(sc, os.path.join(cdir, 'hero', 'beauty.png'))
        record['seconds'] = round(time.time() - t0, 1)
        json.dump(record, open(os.path.join(cdir, 'rig.json'), 'w'), indent=1)
        print(f"{P['id']}: {len(record['renders'])} renders in {record['seconds']} s", flush=True)


if __name__ == '__main__':
    argv = sys.argv[1:]
    main(argv)
