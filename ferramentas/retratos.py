import bpy, sys, os, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]; files = argv[1:]
for f in files:
    nome = os.path.basename(f).split(".")[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if arm and bpy.data.actions.get("idle"):
        a = arm[0]
        if a.animation_data is None: a.animation_data_create()
        a.animation_data.action = bpy.data.actions["idle"]
    sc = bpy.context.scene
    sc.frame_set(10)
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    dg = bpy.context.evaluated_depsgraph_get()
    zs = []
    for o in meshes:
        m = o.evaluated_get(dg).to_mesh()
        zs += [(o.matrix_world @ v.co).z for v in m.vertices]
    zmin, zmax = min(zs), max(zs); h = zmax - zmin
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else engines[0]
    sc.render.resolution_x = 256; sc.render.resolution_y = 256
    sc.render.film_transparent = True
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.03, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    alvo_z = zmin + h * {"chefe": 0.885, "diabrete": 0.83, "bruto": 0.85, "cultista": 0.87}.get(nome, 0.9)
    escala = h * {"chefe": 0.3, "diabrete": 0.34, "bruto": 0.3, "cultista": 0.27}.get(nome, 0.24)
    cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = escala
    co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    ang = math.radians(-28)
    d = Vector((math.cos(ang), math.sin(ang), 0.12)).normalized()
    co.location = Vector((0, 0, alvo_z)) + d * 4
    co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    def luz(nm, tipo, cor, energia, pos):
        ld = bpy.data.lights.new(nm, tipo); ld.color = cor; ld.energy = energia
        lo = bpy.data.objects.new(nm, ld); sc.collection.objects.link(lo); lo.location = pos
        lo.rotation_euler = (Vector((0, 0, alvo_z)) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    luz("chave", "SPOT", (1.0, 0.72, 0.45), 260, (2.2, -1.6, alvo_z + 1.4))
    luz("recorte", "SPOT", (0.55, 0.65, 1.0), 320, (-2.0, 1.8, alvo_z + 1.0))
    luz("baixo", "POINT", (1.0, 0.35, 0.15), 30, (1.0, -0.4, zmin + h * 0.3))
    sc.render.filepath = os.path.join(out, f"retrato_{nome}.png")
    bpy.ops.render.render(write_still=True)
    print("RETRATO", nome)
