"""Independent 3D checks against original OBJ, not the rendered 2D projection."""
from pathlib import Path
import json,hashlib
import numpy as np
root=Path(__file__).resolve().parents[1]
profiles=json.loads((root/'components/teaching/classroom/science/force_gallery/profiles.json').read_text())
passed=0
def check(value,label):
    global passed
    if not value: raise AssertionError(label)
    passed+=1
def load_mesh(part):
    path=root/part['source'].removeprefix('res://')
    check(hashlib.sha256(path.read_bytes()).hexdigest()==part['sha256'],'source hash')
    vs=[];fs=[]
    for line in path.read_text().splitlines():
        b=line.split()
        if b and b[0]=='v':vs.append(list(map(float,b[1:4])))
        if b and b[0]=='f':fs.append([int(x.split('/')[0])-1 for x in b[1:]])
    return np.array(vs)[fs]
def edge_distance(p,a,b):
    v=b-a
    return np.linalg.norm(p-(a+np.clip(np.dot(p-a,v)/np.dot(v,v),0,1)*v))
def distance(p,triangles):
    result=float('inf')
    for a,b,c in triangles:
        n=np.cross(b-a,c-a);length=np.linalg.norm(n)
        if length<1e-12:continue
        n=n/length;q=p-n*np.dot(p-a,n)
        if all(np.dot(np.cross(y-x,q-x),n)>=-1e-8 for x,y in [(a,b),(b,c),(c,a)]):
            result=min(result,abs(np.dot(p-a,n)))
        else:result=min(result,edge_distance(p,a,b),edge_distance(p,b,c),edge_distance(p,c,a))
    return result
def inside(p,triangles):
    if distance(p,triangles)<.001:return True
    d=np.array([.927,.319,.193]);ts=[]
    for a,b,c in triangles:
        e1=b-a;e2=c-a;h=np.cross(d,e2);det=np.dot(e1,h)
        if abs(det)<1e-10:continue
        s=p-a;u=np.dot(s,h)/det
        q=np.cross(s,e1);v=np.dot(d,q)/det;t=np.dot(e2,q)/det
        if u>=-1e-9 and v>=-1e-9 and u+v<=1+1e-9 and t>1e-8:ts.append(round(float(t),6))
    return len(set(ts))%2==1
for p in profiles:
    meshes={part['id']:load_mesh(part) for part in p['parts']}
    for mode in p['modes']:
        moving=[mesh+np.array(mode['initial'])+np.array(mode['direction'])*mode['distance'] for key,mesh in meshes.items() if key in mode['moving']]
        fixed=[mesh for key,mesh in meshes.items() if key not in mode['moving']]
        if mode['removable']:
            check(not mode['contacts'] and not mode['paths'],'no fictional removal reaction')
            continue
        for contact in mode['contacts']:
            point=np.array(contact)
            check(min(distance(point,m) for m in moving)<.001,p['id']+' moving contact')
            check(min(distance(point,m) for m in fixed)<.001,p['id']+' fixed contact')
        for path in mode['paths']:
            for a,b in zip(path,path[1:]):
                for t in np.linspace(0,1,13):
                    point=np.array(a)*(1-t)+np.array(b)*t
                    check(any(inside(point,m) for m in fixed),p['id']+' interior load path '+str(point))
print('FORCE PROFILE 3D GEOMETRY:',passed,'passed, 0 failed')
