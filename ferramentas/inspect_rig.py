import bpy, sys, os, mathutils
args = sys.argv[sys.argv.index("--")+1:]
for f in args:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f)
    print("##",os.path.basename(f))
    for o in bpy.data.objects:
        print("  obj",o.name,o.type,"loc",tuple(round(x,3) for x in o.location),"rot",tuple(round(x,3) for x in o.rotation_euler),"scale",tuple(round(x,3) for x in o.scale), "parent", o.parent.name if o.parent else None)
    arm=[o for o in bpy.data.objects if o.type=='ARMATURE']
    if arm:
        a=arm[0]
        bones=a.data.bones
        print("  bones",len(bones))
        for b in bones:
            if b.name.split(':')[-1] in ('Hips','Spine','Head','LeftArm','LeftForeArm','LeftHand','RightArm','RightForeArm','RightHand','LeftUpLeg','LeftLeg','LeftFoot','RightUpLeg'):
                hw=a.matrix_world@b.head_local; tw=a.matrix_world@b.tail_local
                print("   ",b.name,"head",tuple(round(x,3) for x in hw),"tail",tuple(round(x,3) for x in tw),"parent",b.parent.name if b.parent else None)
        print("  allbones",[b.name for b in bones])
    print("  actions",[ (ac.name, ac.frame_range[:]) for ac in bpy.data.actions])
