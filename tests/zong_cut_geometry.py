"""Check cut caps against original solids, including real mortise voids."""
from pathlib import Path
import json,runpy
import numpy as np
root=Path(__file__).resolve().parents[1]
helpers=runpy.run_path(str(root/'tests/force_profile_geometry.py'))
inside,distance,load_mesh=helpers['inside'],helpers['distance'],helpers['load_mesh']
p=next(x for x in json.loads((root/'classroom/science/force_gallery/profiles.json').read_text()) if x['id']=='zong_corner')
passed=0
def check(value,label):
 global passed
 if not value:raise AssertionError(label)
 passed+=1
for part in p['parts']:
 source=load_mesh(part);vertices=np.array(part['cut_vertices']);faces=np.array(part['cut_faces'])
 check(np.all((vertices[:,0]<=.200001)|(vertices[:,2]<=.200001)),part['id']+' retained L solid')
 caps=[]
 for tri,is_cap in zip(vertices[faces],part['cut_caps']):
  if not is_cap:continue
  caps.append(tri)
  check(np.allclose(tri[:,0],.2) or np.allclose(tri[:,2],.2),'true cut plane')
  check(inside(tri.mean(axis=0),source),part['id']+' cap is actual wood, never mortise void')
  for weights in [[.5,.25,.25],[.25,.5,.25],[.25,.25,.5]]:
   check(inside(np.array(weights)@tri,source),part['id']+' cap interior does not bridge a socket')
  n=np.cross(tri[1]-tri[0],tri[2]-tri[0])
  check(n[0]>=-1e-8 and n[2]>=-1e-8,'outward cap orientation')
 volume=sum(np.dot(a,np.cross(b,c)) for a,b,c in vertices[faces])/6
 original=sum(np.dot(a,np.cross(b,c)) for a,b,c in source)/6
 check(0<volume<original,part['id']+' cut volume is positive and smaller')
 if part['id']=='leg':
  check(distance(np.array([.6,.92,.2]),caps)<1e-5,'actual long-tenon crown retained')
  check(distance(np.array([.2,.58,.6]),caps)<1e-5,'actual short-tenon crown retained')
print('ZONG EXACT CUT CAPS:',passed,'passed, 0 failed')
