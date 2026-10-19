import bpy, bmesh, math, json, os
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.abspath(__file__)); os.makedirs(ROOT+'/assets',exist_ok=True); os.makedirs(ROOT+'/previews',exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
CAT=[]; CHECK=[]

def box(name,lo,hi):
 bpy.ops.mesh.primitive_cube_add(size=1,location=[(a+b)/2 for a,b in zip(lo,hi)]); o=bpy.context.object; o.name=name; o.dimensions=[b-a for a,b in zip(lo,hi)]; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return o

def boolop(a,b,op='DIFFERENCE'):
 bpy.context.view_layer.objects.active=a; m=a.modifiers.new(op,'BOOLEAN'); m.operation=op; m.solver='EXACT'; m.object=b; bpy.ops.object.modifier_apply(modifier=m.name); bpy.data.objects.remove(b,do_unlink=True); return a

def add(a,lo,hi): return boolop(a,box('addition',lo,hi),'UNION')
def cut(a,lo,hi): return boolop(a,box('cutter',lo,hi))
def prism(name,poly,low,high,axis=1):
 # polygon in remaining coordinate axes, extruded along axis
 axes=[i for i in range(3) if i!=axis]; vs=[]
 for v in [low,high]:
  for p in poly:
   q=[0,0,0];q[axis]=v;q[axes[0]]=p[0];q[axes[1]]=p[1];vs.append(q)
 n=len(poly); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();return o

def export_obj(o,path):
 # Godot OBJ n-gon fan triangulation can cap real holes. Triangulate in Blender.
 bpy.context.view_layer.objects.active=o
 tri=o.modifiers.new('Reliable concave triangulation','TRIANGULATE');tri.quad_method='BEAUTY';tri.ngon_method='BEAUTY';bpy.ops.object.modifier_apply(modifier=tri.name)
 assert all(len(p.vertices)==3 for p in o.data.polygons)
 with open(path+'.tmp','w') as f:
  f.write('# Real solid joinery geometry; coordinates: Godot Y up\n')
  for v in o.data.vertices:
   q=o.matrix_world@v.co;f.write('v %.7f %.7f %.7f\n'%tuple(q))
  for p in o.data.polygons:f.write('f '+' '.join(str(i+1) for i in p.vertices)+'\n')
 os.replace(path+'.tmp',path)

def part(o,pid,name,start=(0,0,0),deps=None,fixed=False):
 return {'o':o,'id':pid,'name':name,'start':list(start),'deps':deps or [],'fixed':fixed}

def finish(jid,name,variant,parts,source):
 entry={'id':jid,'name':name,'variant':variant,'source':source,'parts':[]}; objs=[]
 for i,p in enumerate(parts):
  o=p['o'];bpy.context.view_layer.objects.active=o
  # Apply all transforms: exported coordinates are model-local, common origin
  o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.select_set(False)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data)
  volume=abs(bm.calc_volume(signed=True));nonman=sum(not e.is_manifold for e in bm.edges);bm.free()
  CHECK.append({'joint':jid,'part':p['id'],'volume':volume,'nonmanifold_edges':nonman})
  bevel=o.modifiers.new('Small real edge chamfer','BEVEL');bevel.width=.009;bevel.segments=2;bevel.affect='EDGES';bpy.ops.object.modifier_apply(modifier=bevel.name)
  export_obj(o,ROOT+'/assets/'+jid+'_'+p['id']+'.obj')
  mat=bpy.data.materials.new(jid+p['id']);mat.diffuse_color=[(.46,.25,.105,1),(.69,.43,.21,1),(.83,.61,.34,1)][i%3];mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=mat.diffuse_color;bs.inputs['Roughness'].default_value=.7;o.data.materials.append(mat);objs.append(o)
  start=p['start'];entry['parts'].append({'id':p['id'],'name':p['name'],'mesh':'res://models/assets/'+jid+'_'+p['id']+'.obj','assembled_position':[0,0,0],'assembled_rotation':[0,0,0],'start_position':start,'start_rotation':[0,0,0],'fixed':p['fixed'],'insertion_path':[[v*.7 for v in start],[0,0,0]] if not p['fixed'] else [[0,0,0]],'dependencies':p['deps']})
 CAT.append(entry)
 # save visible exploded preview later in one render batch
 for p in parts:p['o'].location+=Vector([v*.42 for v in p['start']])
 render_preview(jid,objs)
 for o in objs:bpy.data.objects.remove(o,do_unlink=True)

def render_preview(jid,objs):
 if os.environ.get("SKIP_PREVIEWS"):return
 for o in objs:
  o.location=Matrix.Rotation(math.pi/2,4,'X')@o.location; o.rotation_euler[0]=math.pi/2
 bpy.context.view_layer.update()
 scene=bpy.context.scene; scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False;scene.render.resolution_x=800;scene.render.resolution_y=650;scene.render.resolution_percentage=100
 coords=[o.matrix_world@Vector(c) for o in objs for c in o.bound_box]; center=sum(coords,Vector())/len(coords); span=max((c-center).length for c in coords)
 bpy.ops.object.camera_add(location=center+Vector((1.4,-1.7,1.15))*span);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*2.55;scene.camera=cam
 lights=[]
 for loc,power,size in [((2,-3,5),400,5),((-3,-1,3),250,4)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(loc));l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler();lights.append(l)
 scene.world.color=(.18,.18,.18);scene.view_settings.view_transform='Standard';scene.render.filepath=ROOT+'/previews/'+jid+'.png';bpy.ops.render.render(write_still=True)
 for o in lights+[cam]:bpy.data.objects.remove(o,do_unlink=True)

STD='https://qxb-img-osscache.qixin.com/standards/1e366d3f4f33deb45fe71e33149cde95.pdf'
# Sliding dovetail: open-ended constant trapezoidal groove, motion along Z
base=box('base',(-1.25,-.6,-1.3),(1.25,0,1.3)); groove=prism('groove',[(-.43,-.32),(.43,-.32),(.27,.03),(-.27,.03)],-1.4,1.4,2);boolop(base,groove)
rail=box('rail',(-.52,.018,-1.0),(.52,.62,1.0));tail=prism('tail',[(-.40,-.30),(.40,-.30),(.25,.04),(-.25,.04)],-1,1,2);boolop(rail,tail,'UNION')
finish('dovetail','燕尾榫','开放端滑动燕尾',[part(base,'groove','燕尾槽座',fixed=True),part(rail,'tail','燕尾滑条',(0,0,3.3),['groove'])],'https://ms-kb.msd.unimelb.edu.au/machine-workshop/making/step-by-step/joining/dovetail-joint')
# blind and through: horizontal beam inserts along -X into post
for jid,name,end in [('blind_tenon','半榫',.25),('through_tenon','透榫',-.77)]:
 post=box('post',(-.65,-1.4,-.62),(.65,1.4,.62));cut(post,(end-.025,-.29,-.25),(.7,.29,.25))
 beam=box('beam',(.668,-.5,-.47),(2.5,.5,.47));add(beam,(end,-.27,-.23),(.69,.27,.23))
 finish(jid,name,'盲直榫（半榫）' if jid=='blind_tenon' else '有肩单直贯通榫',[part(post,'post','卯眼立柱',fixed=True),part(beam,'beam','有肩榫梁',(2.6,0,0),['post'])],STD+'#page=15')
# cross half lap
low=box('lower',(-1.7,-.4,-.42),(1.7,.4,.42));cut(low,(-.44,0,-.5),(.44,.5,.5))
up=box('upper',(-.42,-.4,-1.7),(.42,.4,1.7));cut(up,(-.5,-.5,-.44),(.5,.018,.44))
finish('cross_lap','搭扣榫','两件十字刻半搭接',[part(low,'lower','下层刻半横材',fixed=True),part(up,'upper','上层刻半横材',(0,1.8,0),['lower'])],STD+'#page=21')
# tongue and groove continuous edge
left=box('grooved',(-1.5,-.28,-1.4),(0,.28,1.4));cut(left,(-.34,-.11,-1.5),(.05,.11,1.5))
right=box('tongued',(.018,-.28,-1.4),(1.5,.28,1.4));add(right,(-.31,-.09,-1.4),(.04,.09,1.4))
finish('tongue_groove','企口榫','连续直舌槽拼板',[part(left,'groove','槽边板',fixed=True),part(right,'tongue','舌边板',(1.7,0,0),['groove'])],STD+'#page=16')
# three bars crossing at 60 degrees; layered 1/3 allocation only where crossing
bars=[]
for i,ang in enumerate([0,math.pi/3,-math.pi/3]):
 o=box('bar'+str(i),(-1.9,-.45,-.23),(1.9,.45,.23));o.rotation_euler[1]=ang;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);bars.append(o)
# keep lower/mid/upper thirds at each pair overlap, arms stay full thickness
for i,o in enumerate(bars):
 for j,other in enumerate(bars):
  if i==j:continue
  cutter=box('crosscut',(-2,-.46 if i>j else -.15+i*.3,-.245),(2,-.45+i*.3 if i>j else .46,.245));cutter.rotation_euler[1]=[0,math.pi/3,-math.pi/3][j];boolop(o,cutter)
finish('three_way_lap','扣合榫','三横交叉扣合：三层分配让位',[part(bars[0],'lower','底层横材',fixed=True),part(bars[1],'middle','中层横材',(0,1.6,0),['lower']),part(bars[2],'upper','顶层横材',(0,2.7,0),['lower','middle'])],STD+'#page=21 (A.14)')
# three-way mitered corner; two independent vertical tongues on leg
leg=box('leg',(-.5,-2,-.5),(.5,0,.5));add(leg,(.20,-.02,-.32),(.38,.62,.04));add(leg,(-.32,-.02,.20),(.04,.62,.38))
x=prism('xrail',[(-.5,-.5),(2.3,-.5),(2.3,.5),(.52,.5)],.018,.8);cut(x,(.18,-.03,-.34),(.40,.65,.06))
z=prism('zrail',[(-.5,-.48),(.5,.52),(.5,2.3),(-.5,2.3)],.018,.8);cut(z,(-.34,-.03,.18),(.06,.65,.40))
finish('zong_corner','粽角榫','三方角、斜接双直榫教学变体',[part(leg,'leg','双榫角腿',fixed=True),part(x,'xrail','第一斜接横材',(0,1.5,0),['leg']),part(z,'zrail','第二斜接横材',(0,2.7,0),['leg','xrail'])],STD+'#page=23 (A.17)')
# clamp-head: split top leg straddles apron; cheeks tenon into top panel
leg=box('leg',(-.40,-2,-.40),(.40,.55,.40));cut(leg,(-.45,-.20,-.19),(.45,.7,.19));cut(leg,(-.45,.38,-.45),(-.25,.7,.45));cut(leg,(.25,.38,-.45),(.45,.7,.45))
apron=box('apron',(-1.7,-.18,-.17),(1.7,.35,.17))
top=box('top',(-1.85,.40,-.85),(1.85,.72,.85));cut(top,(-.27,.36,-.42),(.27,.58,-.17));cut(top,(-.27,.36,.17),(.27,.58,.42))
finish('clamp_head','夹头榫','开叉腿夹牙条、双榫入局部案面',[part(leg,'leg','开叉夹头腿',fixed=True),part(apron,'apron','牙条',(0,1.3,0),['leg']),part(top,'top','局部案面',(0,2.3,0),['leg','apron'])],STD+'#page=28 (A.27)')
# L-shaped penetrating stepped beam, deep broad rear seat + smaller front outlet
post=box('post',(-.65,-1.4,-.62),(.65,1.4,.62));cut(post,(-.16,-.31,-.26),(.7,.31,.26));cut(post,(-.7,-.31,-.26),(.0,-.06,.26))
beam=box('beam',(.668,-.5,-.47),(2.45,.5,.47));add(beam,(-.14,-.29,-.24),(.69,.29,.24));add(beam,(-.80,-.29,-.24),(-.12,-.08,.24))
finish('l_through','穿榫','L型阶梯小出榫（未加木楔）',[part(post,'post','阶梯卯眼柱',fixed=True),part(beam,'beam','L型阶梯穿材',(2.7,0,0),['post'])],'https://themefile.culture.tw/file/2021-10-29/3290c275-f65e-4350-9c0a-12be949b2c4d/5-1_%E5%82%B3%E7%B5%B1%E5%A4%A7%E6%9C%A8%E6%A7%8B%E9%80%A0%E8%88%87%E4%BF%AE%E5%BE%A9.pdf#page=18')
with open(ROOT+'/catalog.json.tmp','w') as f:json.dump(CAT,f,ensure_ascii=False,indent=2)
os.replace(ROOT+'/catalog.json.tmp',ROOT+'/catalog.json')
with open(ROOT+'/geometry_checks.json','w') as f:json.dump(CHECK,f,indent=2)
print('GENERATED',len(CAT),'JOINTS',len(CHECK),'PARTS')
