from pathlib import Path
import itertools,json
import numpy as np
from scipy.spatial import ConvexHull

stage=Path(__file__).resolve().parent
gap=.008

def convex(bounds,extra=()):
    lo,hi=bounds
    planes=[]
    for i in range(3):
        n=np.eye(3)[i]; planes.extend([(n,float(hi[i])),(-n,float(-lo[i]))])
    planes.extend((np.array(n,dtype=float),float(d)) for n,d in extra)
    vertices=[]
    for group in itertools.combinations(planes,3):
        a=np.array([x[0] for x in group]); b=np.array([x[1] for x in group])
        if abs(np.linalg.det(a))<1e-10:continue
        p=np.linalg.solve(a,b)
        if all(n@p<=d+1e-9 for n,d in planes) and not any(np.linalg.norm(p-q)<1e-8 for q in vertices): vertices.append(p)
    vertices=np.array(vertices); hull=ConvexHull(vertices); faces=[]
    for tri,plane in zip(hull.simplices,hull.equations):
        a,b,c=map(int,tri)
        # Godot front faces are clockwise when viewed from outside.
        if np.dot(np.cross(vertices[b]-vertices[a],vertices[c]-vertices[a]),plane[:3])>0:b,c=c,b
        faces.append([a,b,c])
    return {'vertices':vertices.tolist(),'triangles':faces}

def box(lo,hi):return convex((lo,hi))

parts={
 'leg':[
  ('union',convex(([0,-2,0],[1,1,1]),[([1,1,0],1-gap),([0,1,1],1-gap)])),
  ('union',box([.4,-.05,.12],[.84,.92,.28])),
  ('union',box([.12,-.05,.4],[.28,.76,.84])),
  # Both vertical tenons enter wall-bounded mortises. Keep the short tenon
  # above the front mortise shoulder. No auxiliary horizontal rail tenon.
 ],
 'xrail':[
  ('union',convex(([0,0,0],[3,1,1]),[([-1,-1,0],-1-gap),([-1,0,1],-gap)])),
  ('subtract',box([.38,-.05,.10],[.86,.94,.30])),
 ],
 'zrail':[
  ('union',convex(([0,0,0],[1,1,3]),[([0,-1,-1],-1-gap),([1,0,-1],-gap)])),
  ('subtract',box([.10,-.05,.38],[.30,.78,.86])),
 ]}
(stage/'zong_corner_solids.json').write_text(json.dumps(parts,indent=2),encoding='utf-8')
print('Prepared convex stocks, true long/short tenons, wall-bounded vertical-tenon sockets and three diagonal shoulders; no auxiliary horizontal rail tenon')
