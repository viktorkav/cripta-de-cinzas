# Blender: anima os rigs Mixamo da Tripo com poses por direção-alvo e exporta GLB.
# Uso: blender -b --factory-startup --python animar.py -- <saida_dir> <rig.fbx>... [--preview <png_dir>]
import bpy, sys, os, math, json
from mathutils import Vector, Matrix, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
preview_dir = None
if "--preview" in argv:
    i = argv.index("--preview"); preview_dir = argv[i + 1]; argv = argv[:i] + argv[i + 2:]
only = None
if "--only" in argv:
    i = argv.index("--only"); only = argv[i + 1].split(","); argv = argv[:i] + argv[i + 2:]
out_dir = argv[0]; files = argv[1:]

# Referencial canônico dos FBX da Tripo: frente +X, esquerda +Y, cima +Z
F = Vector((1, 0, 0)); L = Vector((0, 1, 0)); U = Vector((0, 0, 1))

def v(f=0.0, u=0.0, l=0.0):
    return (F * f + U * u + L * l).normalized()

def mirror(d):
    return Vector((d.x, -d.y, d.z))

BODY = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
        "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
        "RightShoulder", "RightArm", "RightForeArm", "RightHand",
        "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

# Ajustes por personagem (torção da mão para orientar arma, abertura dos braços)
CHAR = {
    "heroi":     {"rhand_twist": 0, "lhand_twist": 0, "lfore": v(f=0.85, u=-0.35, l=0.15)},
    "esqueleto": {"rhand_twist": 0, "lhand_twist": 0},
    "cultista":  {"rhand_twist": 0, "lhand_twist": 0},
    "bruto":     {"rhand_twist": 0, "lhand_twist": 0, "lfore": v(f=0.85, u=-0.35, l=0.15)},
    "diabrete":  {"rhand_twist": 0, "lhand_twist": 0},
    "chefe":     {"rhand_twist": 0, "lhand_twist": 0},
}


def neutral(c):
    cfg = CHAR.get(c, {})
    n = {
        "Spine": {"rot": [(L, 4)]},
        "LeftArm": {"dir": v(f=0.12, u=-1, l=0.32)},
        "LeftForeArm": {"dir": cfg.get("lfore", v(f=0.7, u=-0.6, l=0.08))},
        "LeftHand": {"dir": cfg.get("lfore", v(f=0.7, u=-0.6, l=0.08)), "twist": cfg.get("lhand_twist", 0)},
        "RightArm": {"dir": v(f=0.1, u=-1, l=-0.3)},
        "RightForeArm": {"dir": v(f=0.75, u=-0.55, l=-0.05)},
        "RightHand": {"dir": v(f=0.75, u=-0.55, l=-0.05), "twist": cfg.get("rhand_twist", 0)},
        "LeftUpLeg": {"dir": v(f=0.04, u=-1, l=0.1)},
        "LeftLeg": {"dir": v(f=-0.06, u=-1, l=0.04)},
        "RightUpLeg": {"dir": v(f=0.04, u=-1, l=-0.1)},
        "RightLeg": {"dir": v(f=-0.06, u=-1, l=-0.04)},
    }
    return n


def merge(base, over):
    out = {k: (dict(vv) if isinstance(vv, dict) else vv) for k, vv in base.items()}
    for k, vv in over.items():
        if k == "_hips_loc":
            out[k] = vv; continue
        d = out.setdefault(k, {})
        for kk, val in vv.items():
            if kk == "rot":
                d["rot"] = list(d.get("rot", [])) + list(val)
            else:
                d[kk] = val
    return out


def short(n):
    return n.split(":")[-1]


def ordered(arm):
    res = []
    def walk(b):
        res.append(b)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return res


def apply_pose(arm, spec, height):
    pbs = arm.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    bpy.context.view_layer.update()
    dacc = {}
    for b in ordered(arm):
        nm = short(b.name)
        pb = pbs[b.name]
        dpar = dacc.get(b.parent.name, Matrix.Identity(3)) if b.parent else Matrix.Identity(3)
        s = spec.get(nm)
        if not s and not (nm == "Hips" and "_hips_loc" in spec):
            dacc[b.name] = dpar
            continue
        s = s or {}
        bpy.context.view_layer.update()
        M = pb.matrix.copy()
        rot = M.to_3x3()
        if "dir" in s:
            cur = (rot @ Vector((0, 1, 0))).normalized()
            tgt = (dpar @ s["dir"]).normalized()
            q = cur.rotation_difference(tgt)
            rot = q.to_matrix() @ rot
        rown = Matrix.Identity(3)
        for axis, deg in s.get("rot", []):
            rown = Matrix.Rotation(math.radians(deg), 3, (dpar @ axis).normalized()) @ rown
        rot = rown @ rot
        if s.get("twist"):
            y = (rot @ Vector((0, 1, 0))).normalized()
            rot = Matrix.Rotation(math.radians(s["twist"]), 3, y) @ rot
        loc = M.translation.copy()
        if nm == "Hips" and "_hips_loc" in spec:
            off = spec["_hips_loc"]
            loc = loc + (F * off[0] + U * off[1] + L * off[2]) * height
        newM = Matrix.Translation(loc) @ rot.to_4x4()
        pb.matrix = newM
        dacc[b.name] = rown @ dpar
    bpy.context.view_layer.update()


def key_all(arm, frame):
    for pb in arm.pose.bones:
        if short(pb.name) in BODY:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if short(pb.name) == "Hips":
                pb.keyframe_insert("location", frame=frame)


def anims(c):
    n = neutral(c)
    A = {}
    # IDLE: respiração
    A["idle"] = (True, [
        (0, n),
        (30, merge(n, {"Spine": {"rot": [(L, 2.5)]}, "Spine2": {"rot": [(L, -1.5)]}, "_hips_loc": (0, -0.008, 0),
                       "Head": {"rot": [(L, -2)]},
                       "LeftArm": {"rot": [(F, 2)]}, "RightArm": {"rot": [(F, -2)]}})),
        (60, n),
    ])
    # WALK: ciclo de 24 quadros
    def stride(s):  # s=+1 perna esquerda à frente
        return merge(n, {
            "LeftUpLeg": {"rot": [(L, -26 * s)]}, "LeftLeg": {"rot": [(L, 8 if s > 0 else 34)]},
            "RightUpLeg": {"rot": [(L, 26 * s)]}, "RightLeg": {"rot": [(L, 34 if s > 0 else 8)]},
            "LeftArm": {"rot": [(L, 12 * s)]}, "RightArm": {"rot": [(L, -18 * s)]},
            "Spine1": {"rot": [(U, -6 * s)]}, "Spine": {"rot": [(L, 5)]},
            "_hips_loc": (0, -0.022, 0), "Hips": {"rot": [(U, 5 * s)]},
        })
    def passing(s):  # s=+1: perna direita passando (dobrada)
        return merge(n, {
            "LeftUpLeg": {"rot": [(L, 4 * s)]}, "LeftLeg": {"rot": [(L, 4 if s > 0 else 48)]},
            "RightUpLeg": {"rot": [(L, -4 * s)]}, "RightLeg": {"rot": [(L, 48 if s > 0 else 4)]},
            "Spine": {"rot": [(L, 5)]},
            "_hips_loc": (0, 0.012, 0),
        })
    A["walk"] = (True, [(0, stride(1)), (6, passing(1)), (12, stride(-1)), (18, passing(-1)), (24, stride(1))])
    # ATTACK: preparação, golpe, recuperação (impacto no quadro 13)
    wind = merge(n, {
        "Spine1": {"rot": [(U, -24)]}, "Spine": {"rot": [(L, -6)]},
        "RightArm": {"dir": v(f=-0.25, u=0.75, l=-0.55)}, "RightForeArm": {"dir": v(f=-0.1, u=1, l=-0.25)},
        "RightHand": {"dir": v(f=-0.1, u=1, l=-0.25)},
        "LeftArm": {"dir": v(f=0.5, u=-0.6, l=0.45)},
        "_hips_loc": (-0.02, -0.025, 0),
        "LeftUpLeg": {"rot": [(L, -10)]}, "RightUpLeg": {"rot": [(L, 10)]}, "RightLeg": {"rot": [(L, 12)]},
    })
    strike = merge(n, {
        "Spine1": {"rot": [(U, 28)]}, "Spine": {"rot": [(L, 16)]},
        "RightArm": {"dir": v(f=1, u=-0.25, l=0.15)}, "RightForeArm": {"dir": v(f=1, u=-0.45, l=0.4)},
        "RightHand": {"dir": v(f=1, u=-0.45, l=0.4)},
        "LeftArm": {"dir": v(f=-0.1, u=-1, l=0.5)},
        "_hips_loc": (0.08, -0.045, 0),
        "LeftUpLeg": {"rot": [(L, -28)]}, "LeftLeg": {"rot": [(L, 20)]},
        "RightUpLeg": {"rot": [(L, 22)]}, "RightLeg": {"rot": [(L, 18)]},
    })
    A["attack"] = (False, [(0, n), (9, wind), (13, strike), (18, strike), (30, n)])
    # HIT: recuo
    hit = merge(n, {"Spine": {"rot": [(L, -16)]}, "Spine2": {"rot": [(L, -6)]}, "Head": {"rot": [(L, -18)]},
                    "_hips_loc": (-0.05, -0.01, 0),
                    "LeftArm": {"rot": [(F, 12)]}, "RightArm": {"rot": [(F, -12)]}})
    A["hit"] = (False, [(0, n), (4, hit), (15, n)])
    # DEATH: cai para trás e fica
    kneel = merge(n, {"LeftUpLeg": {"rot": [(L, -38)]}, "LeftLeg": {"rot": [(L, 70)]},
                      "RightUpLeg": {"rot": [(L, -30)]}, "RightLeg": {"rot": [(L, 62)]},
                      "Spine": {"rot": [(L, 22)]}, "Head": {"rot": [(L, 15)]},
                      "_hips_loc": (-0.03, -0.17, 0)})
    fall = merge(n, {"Hips": {"rot": [(L, -84)]}, "_hips_loc": (-0.22, -0.43, 0),
                     "LeftUpLeg": {"rot": [(L, -20)]}, "LeftLeg": {"rot": [(L, 25)]},
                     "RightUpLeg": {"rot": [(L, -8)]}, "RightLeg": {"rot": [(L, 10)]},
                     "LeftArm": {"dir": v(f=0.1, u=-0.2, l=1)}, "RightArm": {"dir": v(f=-0.2, u=-0.2, l=-1)},
                     "RightForeArm": {"dir": v(f=0.6, u=-0.1, l=-0.8)}, "RightHand": {"dir": v(f=0.6, u=-0.1, l=-0.8), "twist": 90},
                     "LeftForeArm": {"dir": v(f=0.4, u=-0.1, l=0.9)}, "LeftHand": {"dir": v(f=0.4, u=-0.1, l=0.9)},
                     "Head": {"rot": [(U, 25)]}})
    A["death"] = (False, [(0, n), (10, kneel), (24, fall), (30, merge(fall, {"_hips_loc": (-0.22, -0.445, 0)})), (45, fall)])
    # CAST: braços erguem e empurram
    up = merge(n, {"RightArm": {"dir": v(f=0.55, u=0.8, l=-0.3)}, "RightForeArm": {"dir": v(f=0.3, u=1, l=-0.1)},
                   "RightHand": {"dir": v(f=0.3, u=1, l=-0.1)},
                   "LeftArm": {"dir": v(f=0.55, u=0.8, l=0.3)}, "LeftForeArm": {"dir": v(f=0.3, u=1, l=0.1)},
                   "LeftHand": {"dir": v(f=0.3, u=1, l=0.1)},
                   "Spine": {"rot": [(L, -10)]}, "Head": {"rot": [(L, -10)]}, "_hips_loc": (-0.02, 0.0, 0)})
    push = merge(n, {"RightArm": {"dir": v(f=1, u=0.05, l=-0.2)}, "RightForeArm": {"dir": v(f=1, u=0.1, l=0.0)},
                     "RightHand": {"dir": v(f=1, u=0.1, l=0.0)},
                     "LeftArm": {"dir": v(f=1, u=0.05, l=0.2)}, "LeftForeArm": {"dir": v(f=1, u=0.1, l=0.0)},
                     "LeftHand": {"dir": v(f=1, u=0.1, l=0.0)},
                     "Spine": {"rot": [(L, 14)]}, "_hips_loc": (0.05, -0.03, 0),
                     "LeftUpLeg": {"rot": [(L, -20)]}, "RightUpLeg": {"rot": [(L, 15)]}, "RightLeg": {"rot": [(L, 15)]}})
    A["cast"] = (False, [(0, n), (11, up), (16, push), (21, push), (34, n)])
    # SPIN: braço da arma estendido para o lado (o giro é feito no Godot)
    spin = merge(n, {"RightArm": {"dir": v(f=0.15, u=0.0, l=-1)}, "RightForeArm": {"dir": v(f=0.25, u=0.9, l=-0.3)},
                     "RightHand": {"dir": v(f=0.25, u=0.9, l=-0.3)},
                     "LeftArm": {"dir": v(f=-0.1, u=-0.3, l=1)},
                     "Spine": {"rot": [(L, 10)]}, "_hips_loc": (0, -0.05, 0),
                     "LeftUpLeg": {"dir": v(f=0.1, u=-1, l=0.35)}, "RightUpLeg": {"dir": v(f=0.1, u=-1, l=-0.35)}})
    A["spin"] = (False, [(0, n), (6, spin), (24, spin), (32, n)])
    # VICTORY: espada ao alto
    vic = merge(n, {"RightArm": {"dir": v(f=-0.1, u=0.8, l=-0.55)}, "RightForeArm": {"dir": v(f=0.05, u=1, l=-0.2)},
                    "RightHand": {"dir": v(f=0.05, u=1, l=-0.2)},
                    "LeftArm": {"dir": v(f=0.3, u=-0.8, l=0.5)},
                    "Spine": {"rot": [(L, -8)]}, "Head": {"rot": [(L, -12)]}, "_hips_loc": (0, 0.01, 0)})
    A["victory"] = (False, [(0, n), (12, vic), (50, vic), (62, n)])
    return A


_mp = os.path.join(out_dir, "manifest_personagens.json")
manifest = json.load(open(_mp)) if os.path.exists(_mp) else {}
for f in files:
    c = os.path.basename(f).split("_rig")[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if f.lower().endswith(".glb"):
        # 11/11: rig da Tripo sobre o GLB reparado do Lab (nó #138) chega em GLB com meshopt
        bpy.ops.import_scene.gltf(filepath=f, bone_heuristic="BLENDER")
        _arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        for o in list(bpy.data.objects):
            if o.type == "MESH" and o.parent != _arm:
                bpy.data.objects.remove(o, do_unlink=True) # forma de osso (Icosphere) do importador
    else:
        bpy.ops.import_scene.fbx(filepath=f, automatic_bone_orientation=False)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    # medidas
    zs = []; xs = []; ys = []
    for o in meshes:
        for vv in o.data.vertices:
            w = o.matrix_world @ vv.co; zs.append(w.z); xs.append(w.x); ys.append(w.y)
    zmin, zmax = min(zs), max(zs)
    height = zmax - zmin
    hips = arm.matrix_world @ arm.data.bones["mixamorig:Hips"].head_local
    manifest[c] = {"zmin": zmin, "zmax": zmax, "height": height, "hips": [hips.x, hips.y, hips.z]}
    A = anims(c)
    if only:
        A = {k: vv for k, vv in A.items() if k in only}
    if arm.animation_data is None:
        arm.animation_data_create()
    for name, (loop, keys) in A.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for frame, spec in keys:
            apply_pose(arm, spec, height)
            key_all(arm, frame)
        act.frame_range = (keys[0][0], keys[-1][0])
        manifest[c].setdefault("anims", {})[name] = {"loop": loop, "frames": keys[-1][0]}
    # pré-visualização: um quadro-chave de cada animação
    if preview_dir:
        os.makedirs(preview_dir, exist_ok=True)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.color_type = "TEXTURE"
        sc.display.shading.light = "FLAT"
        sc.render.resolution_x = 360; sc.render.resolution_y = 360
        sc.render.film_transparent = False
        cam = bpy.data.cameras.new("cam"); cam.type = "ORTHO"; cam.ortho_scale = height * 1.5
        co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
        ang = math.radians(35)
        co.location = (3 * math.cos(ang), -3 * math.sin(ang), zmin + height * 0.55)
        co.rotation_euler = (math.radians(90), 0, math.radians(90) - ang)
        snaps = {"idle": 0, "walk": 0, "attack": 9, "strike": ("attack", 13), "hit": 4, "death": 45, "cast": 11,
                 "spin": 6, "victory": 12, "walk6": ("walk", 6)}
        for label, val in snaps.items():
            an, fr = (val if isinstance(val, tuple) else (label, val))
            act = bpy.data.actions.get(an)
            if not act:
                continue
            arm.animation_data.action = act
            sc.frame_set(fr)
            sc.render.filepath = os.path.join(preview_dir, f"{c}_{label}.png")
            bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions.get("idle")
    bpy.ops.object.mode_set(mode="OBJECT")
    if not only:
        out = os.path.join(out_dir, c + ".glb")
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                                  export_animation_mode="ACTIONS", export_force_sampling=True,
                                  export_frame_range=False, export_image_format="AUTO",
                                  export_yup=True, export_apply=False, export_skins=True)
        print("EXPORT", out)

with open(os.path.join(out_dir, "manifest_personagens.json"), "w") as fh:
    json.dump(manifest, fh, indent=1)
print("MANIFEST", json.dumps({k: {kk: vv for kk, vv in m.items() if kk != "anims"} for k, m in manifest.items()}))
