import bpy, sys, os, math, mathutils
args = sys.argv[sys.argv.index("--")+1:]
out=args[0]; files=args[1:]
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if f.endswith('.fbx'): bpy.ops.import_scene.fbx(filepath=f)
    else: bpy.ops.import_scene.gltf(filepath=f)
    sc=bpy.context.scene
    import mathutils as mu
    zs=[(o.matrix_world@mu.Vector(c)).z for o in bpy.data.objects if o.type=="MESH" for c in o.bound_box]
    ZC=(min(zs)+max(zs))/2
    sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x=400; sc.render.resolution_y=400
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=1.0
    for i,(name,ang) in enumerate([('negY',0),('posX',90),('posY',180),('negX',270)]):
        cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=1.3
        co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co)
        a=math.radians(ang)
        co.location=(3*math.sin(a), -3*math.cos(a), ZC)
        co.rotation_euler=(math.radians(90),0,a)
        sc.camera=co
        sc.render.filepath=os.path.join(out, os.path.basename(f).split('.')[0]+'_'+name+'.png')
        bpy.ops.render.render(write_still=True)
