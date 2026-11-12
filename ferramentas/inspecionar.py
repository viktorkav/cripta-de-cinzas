import bpy, sys, os, mathutils
args = sys.argv[sys.argv.index("--")+1:]
for f in args:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if f.endswith('.fbx'): bpy.ops.import_scene.fbx(filepath=f)
    else: bpy.ops.import_scene.gltf(filepath=f)
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    tris=0; mn=mathutils.Vector((1e9,)*3); mx=mathutils.Vector((-1e9,)*3)
    for o in meshes:
        dg=bpy.context.evaluated_depsgraph_get(); m=o.evaluated_get(dg).to_mesh()
        m.calc_loop_triangles(); tris+=len(m.loop_triangles)
        for v in m.vertices:
            w=o.matrix_world@v.co; mn=mathutils.Vector(map(min,mn,w)); mx=mathutils.Vector(map(max,mx,w))
    objs=[(o.name,o.type) for o in bpy.data.objects]
    imgs=[(i.name,i.size[:]) for i in bpy.data.images]
    mats=[]
    for m in bpy.data.materials:
        if m.use_nodes:
            mats.append((m.name,[n.type for n in m.node_tree.nodes]))
    print("##",os.path.basename(f),"tris",tris,"min",tuple(round(x,3) for x in mn),"max",tuple(round(x,3) for x in mx))
    print("   objs",objs[:8]); print("   imgs",imgs); print("   mats",mats[:4])
