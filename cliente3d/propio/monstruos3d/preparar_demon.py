"""Rig the user's 3DTIBIA Demon and bake textured morph poses for Godot.
Run with Blender --background --python preparar_demon.py.
The original GLB and JPEG are copied byte-for-byte, never edited in place.
"""
from pathlib import Path
import hashlib, json, math, shutil, struct
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

HERE=Path(__file__).resolve().parent
OUT=HERE/'demon_3dtibia'
SOURCE=Path('C:/Users/dell/3DTIBIA/motor3d/assets/modelos/monstruos/35_demon/modelo.glb')
OUT.mkdir(exist_ok=True)
EDITABLE=OUT/'editable'
EDITABLE.mkdir(exist_ok=True)
(EDITABLE/'.gdignore').write_text('# Editable art sources, excluded from Godot import.\n')
if not (EDITABLE/'original.glb').exists():
    shutil.copy2(SOURCE,EDITABLE/'original.glb')
SOURCE=EDITABLE/'original.glb'
blob=SOURCE.read_bytes(); n=struct.unpack_from('<I',blob,12)[0]
gltf=json.loads(blob[20:20+n]); binary=blob[28+n:]
view=gltf['bufferViews'][gltf['images'][0]['bufferView']]
texture=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
(OUT/'color.jpg').write_bytes(texture)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
obj.name='Demon_original'
verts=np.array([v.co[:] for v in obj.data.vertices])
# Join only coincident positions for classification; preserve all UV seams.
_,inverse=np.unique(np.round(verts,5),axis=0,return_inverse=True)
parent=np.arange(inverse.max()+1)
def find(i):
    while parent[i]!=i:
        parent[i]=parent[parent[i]];i=parent[i]
    return i
for poly in obj.data.polygons:
    a=find(inverse[poly.vertices[0]])
    for vi in poly.vertices[1:]: parent[find(inverse[vi])]=a
labels=np.array([find(i) for i in inverse])
components,counts=np.unique(labels,return_counts=True)
main=components[counts.argmax()]
remove=set(np.nonzero(labels!=main)[0].tolist())
# All five disconnected components were visually verified as low rock scraps.
assert all(verts[list(remove),2]<-.20), 'Unexpected disconnected anatomy; inspect before deleting'
bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[bm.verts[i] for i in sorted(remove)],context='VERTS')
bm.to_mesh(obj.data);bm.free();obj.data.update()
print('CLEANUP removed_vertices=',len(remove),'remaining_faces=',len(obj.data.polygons),flush=True)

# Blender coordinates: Z up, -Y forward; source bind shape stays unchanged.
bpy.ops.object.select_all(action='DESELECT')
arm_data=bpy.data.armatures.new('Demon_esqueleto')
arm=bpy.data.objects.new('Demon_Rig',arm_data);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones={}
def bone(name,head,tail,parent=None,deform=True):
    b=arm_data.edit_bones.new(name);b.head=head;b.tail=tail;b.use_deform=deform
    if parent:b.parent=arm_data.edit_bones[parent]
    bones[name]=(np.array(head,float),np.array(tail,float))
    return b
bone('root',(0,0,-.29),(0,0,-.09),deform=False)
bone('pelvis',(0,.22,.22),(0,.12,.43),'root')
bone('spine',(0,.12,.43),(0,-.04,.66),'pelvis')
bone('chest',(0,-.04,.66),(0,-.24,.73),'spine')
bone('head',(0,-.24,.73),(0,-.60,.40),'chest')
bone('tail_01',(0,.27,.28),(0,.53,.20),'pelvis')
bone('tail_02',(0,.53,.20),(0,.75,.31),'tail_01')
bone('tail_03',(0,.75,.31),(0,.95,.48),'tail_02')
for side,suffix in [(-1,'L'),(1,'R')]:
    bone('upper_arm.'+suffix,(side*.31,-.09,.65),(side*.59,-.17,.57),'chest')
    bone('forearm.'+suffix,(side*.59,-.17,.57),(side*.77,-.34,.44),'upper_arm.'+suffix)
    bone('hand.'+suffix,(side*.77,-.34,.44),(side*.83,-.49,.30),'forearm.'+suffix)
    bone('thigh.'+suffix,(side*.23,.15,.25),(side*.33,-.13,.06),'pelvis')
    bone('shin.'+suffix,(side*.33,-.13,.06),(side*.34,-.02,-.20),'thigh.'+suffix)
    bone('foot.'+suffix,(side*.34,-.02,-.20),(side*.34,-.31,-.25),'shin.'+suffix)
    bone('foot_ik.'+suffix,(side*.34,-.02,-.20),(side*.34,-.31,-.25),'root',False)
bpy.ops.object.mode_set(mode='OBJECT')
# Smooth nearest-segment weights within anatomical regions, avoiding cross-limb
# influences in the crouched bind pose. Shared seam positions get equal weights.
v=np.array([a.co[:] for a in obj.data.vertices])
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def distance_segment(p,a,b):
    t=np.clip(((p-a)@(b-a))/np.dot(b-a,b-a),0,1)
    return np.linalg.norm(p-a-t[:,None]*(b-a),axis=1)
weights={name:np.zeros(len(v)) for name in bones if arm_data.bones[name].use_deform}
x,y,z=v.T
# Keep the raised tip in the tail chain instead of assigning it to the torso.
w_tail=smooth(.27,.46,y)*(1-smooth(.40,.62,z)*(1-smooth(.42,.60,y)))
w_arm=smooth(.34,.53,abs(x))*smooth(.13,.35,z)*(1-w_tail)
w_leg=(1-smooth(.16,.36,z))*(1-w_tail)*(1-w_arm)
w_body=np.maximum(0,1-w_tail-w_arm-w_leg)
def distribute(names,mask):
    distances=np.stack([distance_segment(v,*bones[name]) for name in names],axis=1)
    influence=np.exp(-distances**2/.022)
    influence/=np.maximum(influence.sum(axis=1,keepdims=True),1e-30)
    for i,name in enumerate(names):weights[name]+=mask*influence[:,i]
distribute(['tail_01','tail_02','tail_03'],w_tail)
for side,suffix in [(-1,'L'),(1,'R')]:
    mask=(x*side>=0).astype(float)
    distribute(['upper_arm.'+suffix,'forearm.'+suffix,'hand.'+suffix],w_arm*mask)
    distribute(['thigh.'+suffix,'shin.'+suffix,'foot.'+suffix],w_leg*mask)
distribute(['pelvis','spine','chest','head'],w_body)
# Four largest influences, matching glTF's portable skinning limit.
wnames=list(weights);matrix=np.stack([weights[n] for n in wnames],axis=1)
rank=np.argsort(matrix,axis=1);np.put_along_axis(matrix,rank[:,:-4],0,axis=1)
matrix/=np.maximum(matrix.sum(axis=1,keepdims=True),1e-30)
assert np.allclose(matrix.sum(1),1)
for col,name in enumerate(wnames):
    group=obj.vertex_groups.new(name=name)
    for idx in np.nonzero(matrix[:,col]>1e-6)[0]:group.add([int(idx)],float(matrix[idx,col]),'REPLACE')
# Solve skin weights along the mesh surface instead of spatial bands.
proxy=obj.copy();proxy.data=obj.data.copy();bpy.context.collection.objects.link(proxy)
proxy.vertex_groups.clear()
bm=bmesh.new();bm.from_mesh(proxy.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00002)
bm.to_mesh(proxy.data);bm.free()
bpy.ops.object.select_all(action='DESELECT')
proxy.select_set(True);arm.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
from mathutils.kdtree import KDTree
tree=KDTree(len(proxy.data.vertices))
for vertex in proxy.data.vertices:tree.insert(vertex.co,vertex.index)
tree.balance()
obj.vertex_groups.clear()
for group in proxy.vertex_groups:obj.vertex_groups.new(name=group.name)
for vertex in obj.data.vertices:
    _,j,_=tree.find(vertex.co)
    for group in proxy.data.vertices[j].groups:
        obj.vertex_groups[group.group].add([vertex.index],group.weight,'REPLACE')
bpy.data.objects.remove(proxy,do_unlink=True)
# Preserve the separately classified tail all the way to its raised tip.
for vertex in obj.data.vertices:
    i=vertex.index
    if w_tail[i]>.001:
        for group in list(vertex.groups):
            obj.vertex_groups[group.group].add([i],group.weight*(1-w_tail[i]),'REPLACE')
        for name in ['tail_01','tail_02','tail_03']:
            obj.vertex_groups[name].add([i],float(weights[name][i]),'REPLACE')
# Keep the editable glTF and baked runtime on the same normalized four weights.
for vertex in obj.data.vertices:
    entries=sorted([(g.group,g.weight) for g in vertex.groups],key=lambda item:item[1],reverse=True)
    total=sum(value for _,value in entries[:4])
    assert total>1e-6, 'Bone heat solve left an unweighted vertex'
    for index,value in entries:
        obj.vertex_groups[index].remove([vertex.index])
    for index,value in entries[:4]:
        obj.vertex_groups[index].add([vertex.index],value/total,'REPLACE')
mod=obj.modifiers.new('Demon_skin','ARMATURE');mod.object=arm
obj.parent=arm
# Rebind the requested posture before creating either animation.
def rotate_world(name, axis, degrees):
    basis=arm_data.bones[name].matrix_local.to_3x3()
    delta=basis.inverted() @ Matrix.Rotation(math.radians(degrees),3,axis) @ basis
    arm.pose.bones[name].rotation_mode='QUATERNION'
    arm.pose.bones[name].rotation_quaternion=delta.to_quaternion()
rotate_world('spine','X',-25)
rotate_world('chest','X',-10)
for side,suffix in [(-1,'L'),(1,'R')]:
    rotate_world('upper_arm.'+suffix,'Y',side*60)
    rotate_world('forearm.'+suffix,'X',-12)
bpy.context.view_layer.update()
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
mod=obj.modifiers.new('Demon_skin','ARMATURE');mod.object=arm
for suffix in ['L','R']:
    # Keep the knee in its natural hinge plane; unconstrained IK can twist
    # one thigh around its long axis even with symmetric foot targets.
    arm.pose.bones['thigh.'+suffix].lock_ik_y=True
    arm.pose.bones['shin.'+suffix].lock_ik_y=True
    arm.pose.bones['shin.'+suffix].lock_ik_z=True
    ik=arm.pose.bones['shin.'+suffix].constraints.new('IK');ik.target=arm;ik.subtarget='foot_ik.'+suffix;ik.chain_count=2;ik.use_stretch=False
    # Foot keeps its original orientation while the leg bends toward the target.
    rot=arm.pose.bones['foot.'+suffix].constraints.new('COPY_ROTATION');rot.target=arm;rot.subtarget='foot_ik.'+suffix;rot.target_space='WORLD';rot.owner_space='WORLD'
for p in arm.pose.bones:p.rotation_mode='XYZ'
scene=bpy.context.scene;scene.render.fps=24
clips={'Reposo':dict(frames=48,duration=2.0),'Caminar':dict(frames=24,duration=1.0)}
arm.animation_data_create()
actions={}
for name,config in clips.items():
    action=bpy.data.actions.new(name);arm.animation_data.action=action
    for frame in range(config['frames']+1):
        t=frame/config['frames']*math.tau
        for p in arm.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
        if name=='Reposo':
            arm.pose.bones['chest'].rotation_euler.x=math.sin(t)*.012
            arm.pose.bones['head'].rotation_euler.x=-math.sin(t)*.016
            for suffix in ['L','R']:
                arm.pose.bones['upper_arm.'+suffix].rotation_euler.y=math.sin(t)*.016
            arm.pose.bones['spine'].scale=(1+math.sin(t)*.008,1+math.sin(t)*.012,1+math.sin(t)*.008)
        else:
            arm.pose.bones['pelvis'].rotation_euler.y=math.sin(t)*.028
            arm.pose.bones['spine'].rotation_euler.y=-math.sin(t)*.020
            arm.pose.bones['chest'].rotation_euler.z=math.sin(t)*.027
            for side,suffix in [(-1,'L'),(1,'R')]:
                swing=math.sin(t)*side
                target=arm.pose.bones['foot_ik.'+suffix]
                # Location is in target-bone local space; convert desired world displacement.
                desired=Vector((0,swing*.09,max(0,swing)*.060))
                target.location=arm_data.bones[target.name].matrix_local.to_3x3().inverted()@desired
                arm.pose.bones['upper_arm.'+suffix].rotation_euler.x=-swing*.075
                arm.pose.bones['forearm.'+suffix].rotation_euler.z=swing*.060
        # Move the chain as one piece, preserving the thin tip cross-section.
        arm.pose.bones['tail_01'].rotation_euler.y=math.sin(t-.45)*(.012 if name=='Reposo' else .022)
        for p in arm.pose.bones:
            p.keyframe_insert(data_path='location',frame=frame+1)
            p.keyframe_insert(data_path='rotation_euler',frame=frame+1)
            p.keyframe_insert(data_path='scale',frame=frame+1)
    action.use_fake_user=True;actions[name]=action
    arm.animation_data.action=None
    track=arm.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action);track.mute=True
# Save editable rig with packed texture and two named actions.
for image in bpy.data.images:
    if image.type=='IMAGE':image.pack()
arm.animation_data.action=actions['Reposo'];scene.frame_set(1)
scene.frame_start=1;scene.frame_end=49
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(EDITABLE/'demon_animado.blend'))
# Export actions as independent glTF animations with sampled IK transforms.
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(EDITABLE/'demon_animado.glb'),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
                         export_frame_range=False,export_skins=True)

# Bake base and twelve samples per clip. UV and index streams remain static.
for p in arm.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0);p.scale=(1,1,1)
arm.animation_data.action=None
for p in arm.pose.bones:
    for c in p.constraints:c.mute=True
bpy.context.view_layer.update()
def evaluated():
    deps=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(deps);mesh=ev.to_mesh(preserve_all_data_layers=True,depsgraph=deps)
    mesh.calc_loop_triangles()
    pos=np.empty(len(mesh.vertices)*3,dtype='f4');mesh.vertices.foreach_get('co',pos);pos=pos.reshape(-1,3)
    norms=np.empty(len(mesh.loops)*3,dtype='f4');mesh.corner_normals.foreach_get('vector',norms);norms=norms.reshape(-1,3)
    uv=np.array([d.uv[:] for d in mesh.uv_layers.active.data],dtype='f4')
    lv=np.array([l.vertex_index for l in mesh.loops],dtype='i4')
    tri=np.array([t.loops[:] for t in mesh.loop_triangles],dtype='i4')
    ev.to_mesh_clear();return pos,norms,uv,lv,tri
pos,norms,uv,lv,tri=evaluated()
keys=np.column_stack([lv,uv,norms]);_,unique,inverse=np.unique(keys,axis=0,return_index=True,return_inverse=True)
vertex_map=lv[unique];indices=inverse[tri[:,[0,2,1]]].astype('<u4').ravel()
uvs=uv[unique].copy();uvs[:,1]=1-uvs[:,1]
def convert(p,n):
    # Blender Z-up -> Godot Y-up, determinant +1; clockwise indices above.
    return p[:,[0,2,1]]*np.array([1,1,-1]),n[:,[0,2,1]]*np.array([1,1,-1])
base=convert(pos[vertex_map],norms[unique]);frames=[base];clip_data={}
for p in arm.pose.bones:
    for c in p.constraints:c.mute=False
for name,config in clips.items():
    arm.animation_data.action=actions[name];clip_data[name.lower()]={'inicio':len(frames),'fases':12,'duracion':config['duration']}
    for sample in range(12):
        scene.frame_set(1+sample*config['frames']//12)
        bpy.context.view_layer.update();p,n,_,_,_=evaluated();frames.append(convert(p[vertex_map],n[unique]))
all_pos=np.concatenate([p for p,n in frames]);bottom=all_pos[:,1].min()
span=np.ptp(all_pos,axis=0)[[0,2]].max();factor=2.0/float(span)
for p,n in frames:p[:,1]-=bottom;p*=factor
all_pos=np.concatenate([p for p,n in frames]);dest=HERE/'mallas/outfit_0035_texturado.tvol'
with dest.open('wb') as f:
    f.write(b'TVPVOL02');f.write(struct.pack('<III',len(frames),len(unique),len(indices)))
    f.write(uvs.astype('<f4').tobytes());f.write(indices.tobytes())
    for p,n in frames:f.write(p.astype('<f4').tobytes());f.write(n.astype('<f4').tobytes())
manifest_path=HERE/'mallas/catalogo.json';manifest=json.loads(manifest_path.read_text())
entry=manifest['monstruos']['35'];entry.update(archivo=dest.name,formato='TVPVOL02',textura='../demon_3dtibia/color.jpg',
    anatomia=True,fases=12,clips=clip_data,vertices=[len(unique)]*len(frames),
    min=all_pos.min(0).tolist(),max=all_pos.max(0).tolist(),
    escala={'longitud_casillas':2.0,'factor':factor},sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
manifest_path.write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
scales_path=HERE/'escalas.json';scales=json.loads(scales_path.read_text());scales['monstruos']['35']['longitud_casillas']=2.0;scales_path.write_text(json.dumps(scales,indent=2)+'\n')
report=dict(source_sha256=hashlib.sha256(blob).hexdigest(),texture_sha256=hashlib.sha256(texture).hexdigest(),
            removed_vertices=len(remove),components_before=len(components),triangles=len(indices)//3,
            vertices=len(unique),bones=len(arm_data.bones),clips=clip_data,bounds=[entry['min'],entry['max']],
            pose_bytes=dest.stat().st_size,scale=factor,
            posture=dict(spine_degrees=-25,chest_degrees=-10,arms_down_degrees=60,
                         thigh_radial_reduction=0,tail_sway_degrees=math.degrees(.022)))
(OUT/'informe.json').write_text(json.dumps(report,indent=2)+'\n')
print('DEMON_BAKE',json.dumps(report),flush=True)
