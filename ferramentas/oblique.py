import bpy, sys, os, math
argv=sys.argv[sys.argv.index("--")+1:]; out=argv[0]; f=argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=f) if f.endswith('.fbx') else bpy.ops.import_scene.gltf(filepath=f)
sc=bpy.context.scene; sc.render.engine="BLENDER_WORKBENCH"; sc.display.shading.color_type="TEXTURE"; sc.display.shading.light="FLAT"
sc.render.resolution_x=400; sc.render.resolution_y=400
cam=bpy.data.cameras.new("c"); cam.type="ORTHO"; cam.ortho_scale=1.6; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
base=os.path.basename(f).split('.')[0]
for i,yaw in enumerate([0,90,180,270]):
    a=math.radians(yaw); el=math.radians(40)
    d=(math.cos(el)*math.cos(a), math.cos(el)*math.sin(a), math.sin(el))
    co.location=(3*d[0],3*d[1],3*d[2])
    import mathutils
    dirv=mathutils.Vector((-d[0],-d[1],-d[2]))
    co.rotation_euler=dirv.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=os.path.join(out,f"{base}_obl{yaw}.png"); bpy.ops.render.render(write_still=True)
