# Cannonball structure rigs: build parametric roadside structures in headless Blender
# and render the control passes from the game's roadside billboard camera.
#
#   PY=$(lua art/rigs/setup_bpy.lua)
#   $PY -I art/rigs/rig.py art/rigs/structures-rigs.json OUT [--ids a,b] [--res 1024]
#                          [--passes clay,hint,shade,depth] [--threads 8] [--check]
#
# Per item, OUT/<id>/ gets:
#   clay.png   grey Workbench clay, studio light + cavity, RGBA (its alpha is THE silhouette)
#   hint.png   flat hint colours, no AA, RGBA (one colour per part material)
#   shade.png  hint colours lit (studio light, cavity, shadows) over a flat background: the
#              paint input for Qwen-Image-Edit
#   depth.png  Cycles view depth, near = white
#   rig.json   camera, size, anchor (ground contact, render px), px per metre, params
#
# Grammar: see art/rigs/README.md. Templates live in art/rigs/structures/<template>.json; the
# item list (variants = template + param overrides) lives in art/rigs/structures-rigs.json.
# Python because bpy forces it (forge rule: Lua > Rust > Go otherwise).
import json, math, os, sys, time
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
DIST = 400.0
SAFE = {k: getattr(math, k) for k in ('sin', 'cos', 'tan', 'pi', 'sqrt', 'radians', 'floor', 'ceil', 'atan2')}
SAFE.update({'range': range, 'min': min, 'max': max, 'abs': abs, 'round': round, 'int': int,
             'float': float, 'len': len, 'True': True, 'False': False, 'None': None})


def _arc(cx, cz, r, a0, a1, n=12):
    """Points on a circle arc (degrees, counter-clockwise from +u), for profiles."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def _stadium(w, d, n=8):
    """Rounded-end rectangle (w along u, d along v, ends radius d/2), counter-clockwise."""
    r = d / 2; c = w / 2 - r
    return _arc(c, 0, r, -90, 90, n) + _arc(-c, 0, r, 90, 270, n)


def _arches(L, H, n, span, spring, n_seg=10):
    """Bridge elevation: L long, deck top at H, n semicircular arches of width `span`
    springing at height `spring`, piers between. Simple polygon, counter-clockwise."""
    pts = [(-L / 2, 0)]
    pitch = L / n
    for i in range(n):
        cx = -L / 2 + pitch * (i + 0.5); r = span / 2
        pts += [(cx - r, 0), (cx - r, spring)] + _arc(cx, spring, r, 180, 0, n_seg)[1:-1] + [(cx + r, spring), (cx + r, 0)]
    return pts + [(L / 2, 0), (L / 2, H), (-L / 2, H)]


SAFE.update({'arc': _arc, 'stadium': _stadium, 'arches': _arches})


# ------------------------------------------------------------------ expressions
def E(x, env):
    """Evaluate a grammar value: strings are Python expressions over params, loop vars and the
    helpers above (one globals dict, so comprehensions see params too)."""
    if isinstance(x, str):
        return eval(x, {**SAFE, **env, '__builtins__': {}})
    if isinstance(x, list):
        return [E(v, env) for v in x]
    return x


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def colour(c, env):
    """'#rrggbb', a param name holding one, or an expression giving one."""
    if c is None:
        return '#9a9a9a'
    if isinstance(c, str) and c.startswith('#'):
        return c
    if isinstance(c, str) and c in env and isinstance(env[c], str):
        return colour(env[c], env)
    return colour(E(c, env), env)


# ------------------------------------------------------------------ geometry
def box_geo(sx, sy, sz):
    x, y = sx / 2, sy / 2
    v = [(-x, -y, 0), (x, -y, 0), (x, y, 0), (-x, y, 0), (-x, -y, sz), (x, -y, sz), (x, y, sz), (-x, y, sz)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return v, f


def cyl_geo(r, h, r2, seg):
    v, f = [], []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        v.append((r * math.cos(a), r * math.sin(a), 0))
    for k in range(seg):
        a = 2 * math.pi * k / seg
        v.append((r2 * math.cos(a), r2 * math.sin(a), h))
    for k in range(seg):
        n = (k + 1) % seg
        f.append((k, n, seg + n, seg + k))
    f.append(tuple(reversed(range(seg))))
    if r2 > 1e-6:
        f.append(tuple(range(seg, 2 * seg)))
    else:  # cone: collapse the top ring into one apex
        v = v[:seg] + [(0, 0, h)]
        f = [(k, (k + 1) % seg, seg) for k in range(seg)] + [tuple(reversed(range(seg)))]
    return v, f


def sphere_geo(r, seg, half=False):
    v, f = [], []
    rings = seg // 2
    hi = rings // 2 if half else rings  # half = upper hemisphere (dome), flat side at z=0
    for i in range(0, hi + 1):
        th = math.pi * i / rings
        for k in range(seg):
            a = 2 * math.pi * k / seg
            v.append((r * math.sin(th) * math.cos(a), r * math.sin(th) * math.sin(a), r * math.cos(th)))
    n_r = hi + 1
    for i in range(n_r - 1):
        for k in range(seg):
            n = (k + 1) % seg
            f.append((i * seg + k, i * seg + n, (i + 1) * seg + n, (i + 1) * seg + k))
    if half:
        f.append(tuple(range((n_r - 1) * seg, n_r * seg)))
    return v, f


def extrude_geo(profile, depth, axis):
    """Polygon profile (u, v) extruded `depth` along axis: 'y' profile in XZ centred on y=0,
    'x' profile in YZ centred on x=0, 'z' profile in XY from z=0 up."""
    n = len(profile)
    # make the profile counter-clockwise
    area = sum(profile[i][0] * profile[(i + 1) % n][1] - profile[(i + 1) % n][0] * profile[i][1] for i in range(n))
    if area < 0:
        profile = list(reversed(profile))
    d = depth / 2
    if axis == 'y':
        a = [(u, -d, w) for u, w in profile]; b = [(u, d, w) for u, w in profile]
    elif axis == 'x':
        a = [(d, u, w) for u, w in profile]; b = [(-d, u, w) for u, w in profile]
    else:
        a = [(u, w, 0) for u, w in profile]; b = [(u, w, depth) for u, w in profile]
    v = a + b
    f = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] if axis == 'z' else [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
    return v, f


def tube_geo(path, r, seg=6):
    v, f = [], []
    pts = [Vector(p) for p in path]
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        for k in range(seg):
            ang = 2 * math.pi * k / seg
            v.append(tuple(p + r * (math.cos(ang) * a + math.sin(ang) * b)))
    for i in range(len(pts) - 1):
        for k in range(seg):
            n = (k + 1) % seg
            f.append((i * seg + k, i * seg + n, (i + 1) * seg + n, (i + 1) * seg + k))
    return v, f


def rot_matrix(rot):
    rx, ry, rz = (math.radians(a) for a in rot)
    return (Matrix.Rotation(rz, 4, 'Z') @ Matrix.Rotation(ry, 4, 'Y') @ Matrix.Rotation(rx, 4, 'X'))


def local_matrix(p, env):
    at = Vector(E(p.get('at', [0, 0, 0]), env))
    M = Matrix.Translation(at) @ rot_matrix(E(p.get('rot', [0, 0, 0]), env))
    if 'scale' in p:
        s = E(p['scale'], env)
        M = M @ Matrix.Diagonal(Vector((*s, 1.0)))
    return M


def prim(p, env):
    k = p['p']
    if k == 'box':
        return box_geo(*E(p['size'], env))
    if k == 'cyl':
        r = E(p['r'], env); v, f = cyl_geo(r, E(p['h'], env), E(p.get('r2', r), env), int(E(p.get('seg', 16), env)))
        ax = p.get('axis', 'z')
        if ax != 'z':  # horizontal: centred on `at` along the axis
            h = E(p['h'], env)
            R = Matrix.Rotation(math.pi / 2, 3, 'Y') if ax == 'x' else Matrix.Rotation(-math.pi / 2, 3, 'X')
            v = [tuple(R @ Vector((x, y, z - h / 2))) for x, y, z in v]
        return v, f
    if k == 'sphere':
        return sphere_geo(E(p['r'], env), int(E(p.get('seg', 16), env)), p.get('half', False))
    if k == 'prism':  # gable roof: triangle w x h in XZ, ridge along Y (depth d)
        w, d, h = E(p['size'], env)
        return extrude_geo([(-w / 2, 0), (w / 2, 0), (0, h)], d, p.get('axis', 'y'))
    if k == 'extrude':
        return extrude_geo([tuple(q) for q in E(p['profile'], env)], E(p['depth'], env), p.get('axis', 'y'))
    if k == 'hip':  # hip roof / pyramid over a sx x sy rectangle, height h, ridge along the long side
        sx, sy, h = E(p['size'], env); sw = sx < sy
        a, b = (sy, sx) if sw else (sx, sy); r = max(0.0, (a - b) / 2)
        v = [(-a / 2, -b / 2, 0), (a / 2, -b / 2, 0), (a / 2, b / 2, 0), (-a / 2, b / 2, 0), (-r, 0, h), (r, 0, h)]
        f = [(0, 3, 2, 1), (0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4)]
        if sw:
            v = [(-y, x, z) for x, y, z in v]
        return v, f
    if k == 'beam':  # box of cross-section [sx, sy] running from `from` to `to`
        a, b = Vector(E(p['from'], env)), Vector(E(p['to'], env)); sx, sy = E(p.get('size', [0.1, 0.1]), env)
        d = b - a; L = d.length; z = d.normalized()
        x = (Vector((0, 0, 1)).cross(z) if abs(z.z) < 0.99 else Vector((1, 0, 0)).cross(z)).normalized(); y = z.cross(x)
        v, f = box_geo(sx, sy, L)
        return [tuple(a + q[0] * x + q[1] * y + q[2] * z) for q in v], f
    if k == 'shell':  # open polyline profile thickened by t (roofs, arches, canopies), extruded like extrude
        pts = [Vector(q) for q in E(p['profile'], env)]; t = E(p.get('t', 0.2), env)
        inner = []
        for i, q in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            inner.append(q - t * Vector((-d.y, d.x)))
        prof = [tuple(q) for q in pts] + [tuple(q) for q in reversed(inner)]
        return extrude_geo(prof, E(p['depth'], env), p.get('axis', 'y'))
    if k == 'tube':
        return tube_geo(E(p['path'], env), E(p['r'], env), int(E(p.get('seg', 6), env)))
    if k == 'wire':  # catenary-ish sagging cable between two points
        a, b = Vector(E(p['from'], env)), Vector(E(p['to'], env)); sag = E(p.get('sag', 0.3), env)
        pts = [tuple(a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))) for t in [i / 12 for i in range(13)]]
        return tube_geo(pts, E(p.get('r', 0.025), env), 5)
    raise ValueError('unknown primitive %r' % k)


def walk(parts, env, M, out, path='p'):
    """A part's `if` is evaluated per repeat iteration (it may use the loop variable); `let`
    binds names before both."""
    for n, p in enumerate(parts):
        env2 = dict(env)
        for k2, v2 in p.get('let', {}).items():
            env2[k2] = E(v2, env2)
        if 'repeat' in p:
            var, expr = next(iter(p['repeat'].items()))
            for val in E(expr, env2):
                env3 = dict(env2); env3[var] = val
                if 'if' not in p or E(p['if'], env3):
                    emit(p, env3, M, out, '%s.%d.%s' % (path, n, val))
        elif 'if' not in p or E(p['if'], env2):
            emit(p, env2, M, out, '%s.%d' % (path, n))


def emit(p, env, M, out, path):
    mats = [Matrix.Identity(4)]
    if p.get('sym') == 'x':
        mats.append(Matrix.Diagonal(Vector((-1, 1, 1, 1))))
    for S in mats:
        L = M @ S @ local_matrix(p, env)
        if 'parts' in p:
            walk(p['parts'], env, L, out, path)
        elif 'p' in p:
            v, f = prim(p, env)
            flip = L.determinant() < 0
            v = [tuple(L @ Vector(q)) for q in v]
            if flip:
                f = [tuple(reversed(face)) for face in f]
            out.append({'v': v, 'f': f, 'c': colour(p.get('c'), env), 'path': path})


def build(spec_env, tpl):
    out = []
    walk(tpl['parts'], spec_env, Matrix.Identity(4), out)
    return out


# ------------------------------------------------------------------ scene
def setup_scene(threads):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.threads_mode = 'FIXED'; sc.render.threads = threads
    sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False; sc.cycles.use_adaptive_sampling = False
    sc.cycles.samples = 1
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('world')
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam


def clear_meshes():
    for ob in list(bpy.data.objects):
        if ob.type == 'MESH':
            bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def make_objects(parts):
    """One object per hint colour (keeps big fences cheap)."""
    by = {}
    for pt in parts:
        by.setdefault(pt['c'], []).append(pt)
    obs = []
    for c, lst in by.items():
        verts, faces = [], []
        for pt in lst:
            o = len(verts); verts += pt['v']; faces += [tuple(i + o for i in face) for face in pt['f']]
        me = bpy.data.meshes.new('m' + c); me.from_pydata(verts, [], faces); me.update()
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new('o' + c, me); ob['hint'] = c
        bpy.context.scene.collection.objects.link(ob); obs.append(ob)
    return obs


def view_basis(pitch, yaw):
    """Camera looks at the origin from the front-left, raised `pitch` degrees: sees the -Y front
    (the side facing the approaching player) and the -X side (the road side, for an object on
    the right of the road). Mirror the sprite for the left of the road."""
    p, y = math.radians(pitch), math.radians(yaw)
    back = Vector((-math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    right = Vector((0, 0, 1)).cross(back).normalized()
    up = back.cross(right).normalized()
    return right, up, back


def frame_for(obs, basis, anchor, margin):
    right, up, _ = basis
    xs, ys = [], []
    for ob in obs:
        for v in ob.data.vertices:
            xs.append(v.co.dot(right)); ys.append(v.co.dot(up))
    a = Vector(anchor); ys.append(a.dot(up))
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    m = margin * max(x1 - x0, y1 - y0)
    return x0 - m, y0 - m, x1 + m, y1 + m


def place_camera(sc, cam, basis, frame, res):
    right, up, back = basis
    M = Matrix((right, up, back)).transposed().to_4x4(); M.translation = back * DIST
    cam.matrix_world = M
    x0, y0, x1, y1 = frame
    w, h = x1 - x0, y1 - y0
    if w >= h:
        rx, ry = res, max(64, int(round(res * h / w / 16)) * 16)
    else:
        ry, rx = res, max(64, int(round(res * w / h / 16)) * 16)
    # exact metres per pixel on both axes: grow the short side of the frame to the rounded size
    mpp = max(w / rx, h / ry)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.resolution_percentage = 100
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = mpp * max(rx, ry)
    cam.data.shift_x = cx / (mpp * max(rx, ry)); cam.data.shift_y = cy / (mpp * max(rx, ry))
    cam.data.clip_start = 1.0; cam.data.clip_end = DIST * 2
    return mpp, (cx, cy), (rx, ry)


def to_px(pt, basis, centre, mpp, size):
    right, up, _ = basis
    v = Vector(pt)
    x = (v.dot(right) - centre[0]) / mpp + size[0] / 2
    y = size[1] / 2 - (v.dot(up) - centre[1]) / mpp
    return [round(x, 2), round(y, 2)]


def depth_material(near, far):
    mat = bpy.data.materials.new('depth')
    if not mat.node_tree:
        mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    em = nt.nodes.new('ShaderNodeEmission'); out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    cd = nt.nodes.new('ShaderNodeCameraData'); mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value = near; mr.inputs['From Max'].default_value = far
    mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
    nt.links.new(cd.outputs['View Z Depth'], mr.inputs['Value'])
    nt.links.new(mr.outputs['Result'], em.inputs['Color'])
    return mat


def render(sc, obs, kind, path, bg, near, far):
    rs = sc.render
    sh = sc.display.shading
    rs.film_transparent = kind != 'shade'
    if kind in ('clay', 'hint', 'shade'):
        rs.engine = 'BLENDER_WORKBENCH'
        for ob in obs:
            ob.data.materials.clear()
        if kind == 'hint':
            sh.light = 'FLAT'; sh.color_type = 'OBJECT'; sh.show_cavity = False; sh.show_shadows = False
            sc.display.render_aa = 'OFF'; sc.view_settings.view_transform = 'Raw'; sc.view_settings.exposure = 0.0
            for ob in obs:
                ob.color = (*hex_rgb(ob['hint']), 1.0)
        else:
            sh.light = 'STUDIO'; sh.show_cavity = True; sh.cavity_type = 'BOTH'
            sh.cavity_ridge_factor = 1.0; sh.cavity_valley_factor = 1.0
            sh.show_shadows = True; sh.shadow_intensity = 0.35
            sc.display.light_direction = (-0.55, -0.35, 0.76)  # sun high from the upper left
            sc.display.render_aa = '8'; sc.view_settings.view_transform = 'Standard'
            sc.view_settings.exposure = 0.0 if kind == 'clay' else 0.45
            if kind == 'clay':
                sh.color_type = 'SINGLE'; sh.single_color = (0.62, 0.62, 0.62)
            else:
                sh.color_type = 'OBJECT'
                for ob in obs:
                    ob.color = (*(lin(c) for c in hex_rgb(ob['hint'])), 1.0)
                sc.world.color = tuple(lin(c) for c in hex_rgb(bg))
    else:
        rs.engine = 'CYCLES'; sc.view_settings.view_transform = 'Raw'
        m = depth_material(near, far)
        for ob in obs:
            ob.data.materials.clear(); ob.data.materials.append(m)
    rs.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ spec
def load_template(name):
    with open(os.path.join(HERE, 'structures', name + '.json')) as fh:
        return json.load(fh)


def item_env(tpl, item):
    env = {}
    for k, v in tpl.get('params', {}).items():
        env[k] = v
    env.update(item.get('params', {}))
    for k, v in tpl.get('derived', {}).items():  # derived values may use params
        env[k] = E(v, env)
    return env


def opts(argv):
    args, opt, i = [], {}, 0
    while i < len(argv):
        if argv[i].startswith('--'):
            if i + 1 < len(argv) and not argv[i + 1].startswith('--'):
                opt[argv[i][2:]] = argv[i + 1]; i += 2
            else:
                opt[argv[i][2:]] = '1'; i += 1
        else:
            args.append(argv[i]); i += 1
    return args, opt


def main(argv):
    args, opt = opts(argv)
    spec = json.load(open(args[0]))
    items = spec['items']
    if 'ids' in opt:
        want = opt['ids'].split(',')
        items = [it for it in items if it['id'] in want or any(it['id'].startswith(w.rstrip('*')) for w in want if w.endswith('*'))]
    res = int(opt.get('res', spec.get('render', {}).get('res', 1024)))
    passes = opt.get('passes', 'clay,hint,shade,depth').split(',')
    bg = spec.get('render', {}).get('background', '#8c9aa6')
    errs = []
    sc, cam = setup_scene(int(opt.get('threads', 8)))
    for it in items:
        t0 = time.time()
        tpl = load_template(it['template'])
        env = item_env(tpl, it)
        try:
            parts = build(env, tpl)
        except Exception as e:  # report the grammar error with the item, keep going
            errs.append('%s: %s: %s' % (it['id'], type(e).__name__, e)); continue
        nv = sum(len(p['v']) for p in parts)
        if 'check' in opt:
            print('%-28s parts %4d verts %6d' % (it['id'], len(parts), nv), flush=True); continue
        clear_meshes()
        obs = make_objects(parts)
        bpy.context.view_layer.update()
        view = {**tpl.get('view', {}), **spec.get('view', {}).get(it['template'], {}), **it.get('view', {})}
        pitch, yaw = view.get('pitch', 7), view.get('yaw', 35)
        basis = view_basis(pitch, yaw)
        anchor = E(tpl.get('anchor', [0, 0, 0]), env)
        frame = frame_for(obs, basis, anchor, view.get('margin', 0.03))
        mpp, centre, size = place_camera(sc, cam, basis, frame, res)
        rad = max((Vector(v.co).length for ob in obs for v in ob.data.vertices), default=1)
        out = os.path.join(args[1], it['id']); os.makedirs(out, exist_ok=True)
        for kind in passes:
            render(sc, obs, kind, os.path.join(out, kind + '.png'), bg, DIST - rad, DIST + rad)
        rig = {'schema': 'cannonball.rig/v1', 'id': it['id'], 'template': it['template'], 'params': env,
               'view': {'pitch': pitch, 'yaw': yaw}, 'size': list(size), 'metres_per_px': mpp,
               'anchor_px': to_px(anchor, basis, centre, mpp, size), 'background': bg,
               'camera': {'right': list(basis[0]), 'up': list(basis[1]), 'back': list(basis[2])},
               'parts': len(parts), 'verts': nv}
        with open(os.path.join(out, 'rig.json'), 'w') as fh:
            json.dump(rig, fh, indent=1, default=str)
        print('%-28s %4dx%-4d %5.1f s' % (it['id'], size[0], size[1], time.time() - t0), flush=True)
    for e in errs:
        print('FAIL', e)
    return 1 if errs else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]))
