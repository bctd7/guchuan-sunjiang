import bpy,bmesh,json,os
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def load(path):
 v=[];f=[]
 for line in open(path):
  if line.startswith('v '):v.append(tuple(map(float,line.split()[1:])))
  if line.startswith('f '):f.append(tuple(int(x.split('/')[0])-1 for x in line.split()[1:]))
 m=bpy.data.meshes.new('mesh');m.from_pydata(v,[],f);m.update();o=bpy.data.objects.new('part',m);bpy.context.collection.objects.link(o);return o

def vol(o):
 bm=bmesh.new();bm.from_mesh(o.data);v=abs(bm.calc_volume(signed=True));bm.free();return v

def overlap(a,b):
 ac=[a.matrix_world@Vector(c) for c in a.bound_box];bc=[b.matrix_world@Vector(c) for c in b.bound_box]
 if any(max(v[k] for v in ac)<min(v[k] for v in bc) or max(v[k] for v in bc)<min(v[k] for v in ac) for k in range(3)):return 0
 t=a.copy();t.data=a.data.copy();bpy.context.collection.objects.link(t);bpy.context.view_layer.objects.active=t;m=t.modifiers.new('intersection','BOOLEAN');m.operation='INTERSECT';m.solver='EXACT';m.object=b;bpy.ops.object.modifier_apply(modifier=m.name);v=vol(t);bpy.data.objects.remove(t,do_unlink=True);return v
report=[]
for j in json.load(open(ROOT+'/catalog.json')):
 os_={p['id']:load(ROOT+'/assets/'+os.path.basename(p['mesh'])) for p in j['parts']};r={'id':j['id'],'parts':[],'assembly_path_samples':[],'assembled_overlaps':[]}
 for p in j['parts']:
  o=os_[p['id']];bm=bmesh.new();bm.from_mesh(o.data);r['parts'].append({'id':p['id'],'volume':abs(bm.calc_volume()),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges)});bm.free()
 for i,p in enumerate(j['parts']):
  for q in j['parts'][:i]:r['assembled_overlaps'].append({'a':p['id'],'b':q['id'],'volume':overlap(os_[p['id']],os_[q['id']])})
 for i,p in enumerate(j['parts']):
  if p['fixed']:continue
  o=os_[p['id']];way=[p['start_position']]+p['insertion_path'];worst=0;at=None
  for a,b in zip(way,way[1:]):
   for step in range(41):
    pos=Vector(a).lerp(Vector(b),step/40);o.location=pos;bpy.context.view_layer.update()
    for q in j['parts'][:i]:
     v=overlap(o,os_[q['id']])
     if v>worst:worst=v;at=list(pos)
  o.location=(0,0,0);bpy.context.view_layer.update();r['assembly_path_samples'].append({'part':p['id'],'samples_per_segment':41,'max_intersection_volume':worst,'worst_position':at})
 report.append(r)
 for o in os_.values():bpy.data.objects.remove(o,do_unlink=True)
print(json.dumps(report,indent=2));json.dump(report,open(ROOT+'/validation_report.json','w'),indent=2)
assert all(p['volume']>0 and p['nonmanifold_edges']==0 for r in report for p in r['parts'])
assert all(x['volume']<1e-5 for r in report for x in r['assembled_overlaps'])
assert all(x['max_intersection_volume']<1e-5 for r in report for x in r['assembly_path_samples'])
print('ALL SOLID AND PATH TESTS PASSED')
