import os
ROOT=os.path.dirname(os.path.abspath(__file__))
exec(open(ROOT+'/generate_models.py').read().split("STD='https:")[0])
# Read final exported geometry, ensuring previews show the actual delivery meshes.
def load_obj(path):
 vs=[];fs=[]
 for l in open(path):
  if l.startswith('v '):vs.append(tuple(map(float,l.split()[1:])))
  if l.startswith('f '):fs.append(tuple(int(n)-1 for n in l.split()[1:]))
 me=bpy.data.meshes.new('part');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('part',me);bpy.context.collection.objects.link(o);return o
for j in json.load(open(ROOT+'/catalog.json')):
 objs=[]
 for i,p in enumerate(j['parts']):
  o=load_obj(ROOT+'/assets/'+os.path.basename(p['mesh']));o.location=Vector(p['start_position'])*.42
  mat=bpy.data.materials.new(p['id']);mat.diffuse_color=[(.46,.25,.105,1),(.69,.43,.21,1),(.83,.61,.34,1)][i%3];mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=mat.diffuse_color;bs.inputs['Roughness'].default_value=.7;o.data.materials.append(mat);objs.append(o)
 render_preview(j['id'],objs)
 for o in objs:bpy.data.objects.remove(o,do_unlink=True)
