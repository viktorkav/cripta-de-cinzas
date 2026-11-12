# Blender: converte os props estáticos da Tripo em GLB, endireita o que veio torto e grava medidas.
# Uso: blender -b --factory-startup --python props.py -- <saida_dir> <arquivo>...
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = argv[0]; files = argv[1:]
man_path = os.path.join(out_dir, "manifest_props.json")
manifest = json.load(open(man_path)) if os.path.exists(man_path) else {}

for f in files:
    name = os.path.basename(f).split(".")[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if f.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=f)
    else:
        bpy.ops.import_scene.gltf(filepath=f)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1 and name not in ("bau_novo_segmentado",):
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = np.array([list(v.co) for o in meshes for v in o.data.vertices])
    if name == "barril":
        # endireita: eixo principal (o mais longo) vira o Z
        c = pts.mean(axis=0)
        cov = np.cov((pts - c).T)
        w, vecs = np.linalg.eigh(cov)
        axis = Vector(vecs[:, int(np.argmax(w))])
        if axis.z < 0:
            axis = -axis
        q = axis.rotation_difference(Vector((0, 0, 1)))
        R = q.to_matrix().to_4x4()
        for o in meshes:
            o.data.transform(R)
        pts = np.array([list(v.co) for o in meshes for v in o.data.vertices])
        print("BARRIL eixo", tuple(round(x, 3) for x in axis), "angulo", round(math.degrees(axis.angle(Vector((0, 0, 1)))), 1))
    mn = pts.min(axis=0); mx = pts.max(axis=0)
    # pés no zero e centro no XY
    off = Vector((-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]))
    for o in meshes:
        o.data.transform(Matrix.Translation(off))
    pts = np.array([list(v.co) for o in meshes for v in o.data.vertices])
    mn = pts.min(axis=0); mx = pts.max(axis=0)
    if name == "bau_novo":
        import bmesh
        frac = float(os.environ.get("BAU_SEAM", "0.47"))
        zc = mn[2] + (mx[2] - mn[2]) * frac
        src = meshes[0]
        src.name = "corpo"
        tampa = src.copy(); tampa.data = src.data.copy(); tampa.name = "tampa"
        bpy.context.scene.collection.objects.link(tampa)
        for ob, manter_cima in ((src, False), (tampa, True)):
            bm = bmesh.new(); bm.from_mesh(ob.data)
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zc), plane_no=(0, 0, 1),
                                   clear_inner=manter_cima, clear_outer=not manter_cima)
            bm.to_mesh(ob.data); bm.free()
        # dobradiça: aresta de trás (-X) no topo do corpo; origem da tampa ali
        hx = mn[0]
        tampa.data.transform(Matrix.Translation(Vector((-hx, 0, -zc))))
        tampa.location = (hx, 0, zc)
        meshes = [src, tampa]
        if os.environ.get("BAU_ABRIR"):
            tampa.rotation_euler = (0, math.radians(-float(os.environ["BAU_ABRIR"])), 0)
        print("BAU seam", zc)
    manifest[name] = {"min": mn.tolist(), "max": mx.tolist(), "parts": [o.name for o in meshes] if len(meshes) > 1 else []}
    out = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                              export_image_format="AUTO")
    print("EXPORT", out, manifest[name]["min"], manifest[name]["max"])

json.dump(manifest, open(man_path, "w"), indent=1)
