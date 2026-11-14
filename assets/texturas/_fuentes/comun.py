import bpy, mathutils, math, os
MOD=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../") + r"assets/modelos"
NOMBRES=["hangar_cuadrado","hangar_roundA","torreta_simple","torreta_doble","foco","taladro","anthena_juego"]
def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
def importar(path):
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects]
def caja(objs=None):
    objs=objs or [o for o in bpy.context.scene.objects if o.type=='MESH']
    mn=mathutils.Vector((1e9,)*3); mx=-mn
    dg=bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe=o.evaluated_get(dg); me=oe.to_mesh()
        for v in me.vertices:
            w=o.matrix_world@v.co; mn=mathutils.Vector(map(min,mn,w)); mx=mathutils.Vector(map(max,mx,w))
        oe.to_mesh_clear()
    return mn,mx
def tris(objs=None):
    objs=objs or [o for o in bpy.context.scene.objects if o.type=='MESH']
    dg=bpy.context.evaluated_depsgraph_get(); t=0
    for o in objs:
        oe=o.evaluated_get(dg); me=oe.to_mesh(); me.calc_loop_triangles(); t+=len(me.loop_triangles); oe.to_mesh_clear()
    return t
def render(path, noche=False, res=512, vista=(1,-1.3,0.8)):
    sc=bpy.context.scene
    sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x=sc.render.resolution_y=res; sc.render.film_transparent=False
    try: sc.eevee.use_bloom=True
    except: pass
    mn,mx=caja(); c=(mn+mx)/2; r=(mx-mn).length/2
    w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True
    bg=w.node_tree.nodes['Background']; bg.inputs[0].default_value=(0.02,0.02,0.04,1) if noche else (0.85,0.68,0.52,1); bg.inputs[1].default_value=0.15 if noche else 0.7
    sun=bpy.data.objects.new('sun',bpy.data.lights.new('sun','SUN')); sc.collection.objects.link(sun)
    sun.data.energy=0.05 if noche else 3.5; sun.rotation_euler=(math.radians(50),0,math.radians(35)); sun.data.color=(1,0.9,0.8)
    cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
    d=mathutils.Vector(vista).normalized()
    # Blender: Z arriba. vista=(x,y,z)
    cam.location=c+d*r*2.6; cam.rotation_euler=(c-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.view_settings.view_transform='Standard'
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)
    for o in (sun,cam): bpy.data.objects.remove(o)
