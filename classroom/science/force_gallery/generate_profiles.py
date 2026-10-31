"""Extract planar sections / orthographic triangles from the current local OBJ.
No source model is modified. Run from any directory; output is this module only.
"""
from pathlib import Path
import json, math, hashlib
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
catalog = json.loads((ROOT/'models/joinery/catalog.json').read_text(encoding='utf-8'))

def mesh(path):
    vertices, faces = [], []
    for line in path.read_text().splitlines():
        bits = line.split()
        if not bits: continue
        if bits[0] == 'v': vertices.append(list(map(float,bits[1:4])))
        if bits[0] == 'f': faces.append([int(x.split('/')[0])-1 for x in bits[1:]])
    return vertices, faces

def section(vertices, faces, axis, at):
    axes = [i for i in range(3) if i != axis]
    edges = set()
    for face in faces:
        hits = []
        for a,b in zip(face,face[1:]+face[:1]):
            p,q = vertices[a],vertices[b]
            da,db = p[axis]-at,q[axis]-at
            if da*db < 0:
                t=da/(da-db)
                hits.append(tuple(round(p[k]+t*(q[k]-p[k]),6) for k in axes))
            elif abs(da)<1e-8:
                hits.append(tuple(round(p[k],6) for k in axes))
        hits=list(dict.fromkeys(hits))
        if len(hits)==2 and hits[0]!=hits[1]: edges.add(tuple(sorted(hits)))
    rings=[]
    while edges:
        a,b=edges.pop(); ring=[a,b]
        while ring[-1]!=ring[0]:
            candidates=[e for e in edges if ring[-1] in e]
            if not candidates: raise ValueError('Unclosed section')
            edge=candidates[0];edges.remove(edge)
            ring.append(edge[1] if edge[0]==ring[-1] else edge[0])
        if len(ring)>3: rings.append([list(p) for p in ring[:-1]])
    return rings

def clip(poly, axis, at, low=True):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=(a[axis]-at)*(1 if low else -1);db=(b[axis]-at)*(1 if low else -1)
        if da<=1e-9:out.append(a)
        if (da < -1e-9 and db > 1e-9) or (da > 1e-9 and db < -1e-9):
            t=da/(da-db);out.append([a[i]+t*(b[i]-a[i]) for i in range(3)])
    clean=[]
    for point in out:
        if not clean or sum((point[i]-clean[-1][i])**2 for i in range(3))>1e-16:clean.append(point)
    if len(clean)>1 and sum((clean[0][i]-clean[-1][i])**2 for i in range(3))<1e-16:clean.pop()
    return clean

def cross2(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])

def inside2(p,ring):
    result=False
    for a,b in zip(ring,ring[1:]+ring[:1]):
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:result=not result
    return result

def ears(ring):
    ring=ring[:]
    changed=True
    while changed and len(ring)>3:
        changed=False
        for i in range(len(ring)):
            if abs(cross2(ring[i-1],ring[i],ring[(i+1)%len(ring)]))<1e-10:
                ring.pop(i);changed=True;break
    sign=1 if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1]))>0 else -1
    result=[]
    while len(ring)>3:
        for i,b in enumerate(ring):
            a,c=ring[i-1],ring[(i+1)%len(ring)]
            if cross2(a,b,c)*sign<=1e-10:continue
            if any(all(cross2(u,v,p)*sign>=-1e-10 for u,v in [(a,b),(b,c),(c,a)]) for j,p in enumerate(ring) if j not in [(i-1)%len(ring),i,(i+1)%len(ring)]):continue
            result.append([a,b,c]);ring.pop(i);break
        else:raise ValueError('Cannot triangulate exact section')
    if len(ring)==3:result.append(ring)
    return result

def add_cutaway(part, at=.2):
    vertices,faces=part['vertices'],part['faces']
    output=[];caps=[]
    def append(poly,cap=False,axis=None):
        for i in range(1,len(poly)-1):
            a,b,c=poly[0],poly[i],poly[i+1]
            ab=[b[k]-a[k] for k in range(3)];ac=[c[k]-a[k] for k in range(3)]
            n=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            if sum(x*x for x in n)<1e-16:continue
            # Exported OBJ has outward normals / positive signed volume.
            # Cut faces point into the removed +X/+Z quadrant.
            if cap and n[axis]<0:b,c=c,b
            output.append([a,b,c]);caps.append(cap)
    for face in faces:
        triangle=[vertices[i] for i in face]
        # Keep x<=at OR z<=at. The discarded front quadrant exposes both tenons.
        append(clip(triangle,0,at))
        append(clip(clip(triangle,0,at,False),2,at))
    for axis in [0,2]:
        axes=[i for i in range(3) if i!=axis]
        rings=section(vertices,faces,axis,at)
        for ring in rings:
            # Current zong sockets open to an edge; refuse to cap an unseen hole.
            assert not any(inside2(ring[0],other) for other in rings if other is not ring),'Nested cap needs hole triangulation'
            for triangle in ears(ring):
                tri=[]
                for point in triangle:
                    p=[0.,0.,0.];p[axis]=at
                    for k,coordinate in zip(axes,point):p[k]=coordinate
                    tri.append(p)
                append(clip(tri,2 if axis==0 else 0,at,False),True,axis)
    edges={}
    for triangle,is_cap in zip(output,caps):
        if not is_cap:continue
        for a,b in zip(triangle,triangle[1:]+triangle[:1]):
            edge=tuple(sorted([tuple(round(x,6) for x in a),tuple(round(x,6) for x in b)]))
            edges[edge]=edges.get(edge,0)+1
    part.update(cut_vertices=[v for tri in output for v in tri],cut_faces=[[3*i,3*i+1,3*i+2] for i in range(len(output))],cut_caps=caps,cut_edges=[edge for edge,count in edges.items() if count==1])

def mode(moving, direction, distance, contacts, paths, initial=None, removable=False):
    return dict(moving=moving,direction=direction,distance=distance,contacts=contacts,
                paths=paths,initial=initial or [0,0,0],removable=removable)

def blocked_pull(p, moving, direction, initial, distance, contact, edge, anchor, supports):
    """Rigid clearance travel; contact normal is opposed to this selected pull.
    No friction, game lock, or resistance along a removable axis is inferred.
    """
    p['force_kind']='blocked_pull'
    p['supports']=supports
    m=mode([moving],direction,distance,[contact],[],initial=initial)
    m.update(reaction=[-x for x in direction],pull_anchor=anchor,contact_edges=[edge])
    p['modes']=[m]

def build(item, axis=2, at=.003, iso=False):
    result=dict(id=item['id'],axis=axis,at=at,iso=iso,parts=[])
    for spec in item['parts']:
        path=ROOT/spec['mesh'].removeprefix('res://')
        vs,fs=mesh(path)
        result['parts'].append(dict(id=spec['id'],source=spec['mesh'],sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            polygons=section(vs,fs,axis,at) if not iso else [],vertices=vs if iso else [],faces=fs if iso else []))
    return result

profiles=[]
for item in catalog[1:]:
    jid=item['id']; p=build(item,axis=0 if jid=='clamp_head' else 2,at=.003 if jid!='zong_corner' else .2,iso=jid in ('cross_lap','three_way_lap','zong_corner'))
    if jid in ('blind_tenon','through_tenon','l_through'):
        contact=[.48 if jid=='blind_tenon' else 0,-.31 if jid=='l_through' else -.29,.003]
        gap=.02
        p['modes']=[mode(['beam'],[0,-1,0],gap,[contact],[[contact,[contact[0],-1.4,.003]]])]
        if jid=='blind_tenon':
            c=[.225,0,.003]
            p['modes'].append(mode(['beam'],[-1,0,0],.025,[c],[[c,[-.2,0,.003],[-.2,-1.4,.003]]]))
    elif jid=='tongue_groove':
        c=[-.15,-.11,.003]
        p['modes']=[mode(['tongue'],[0,-1,0],.02,[c],[[c,[-.6,-.18,.003],[-1.1,-.28,.003]]])]
    elif jid=='cross_lap':
        p['projection']='top_orthographic'
        # Pull the horizontal lower member right. Its left slot shoulder
        # x=-.44 meets the fixed upper side x=-.42 after +.02 translation.
        blocked_pull(p,'lower',[1,0,0],[-.018,0,0],.038,
            [-.42,.2,0],[[-.42,.2,-.38],[-.42,.2,.38]],
            [1.69,.2,0],[[0,.4,-1.6],[0,.4,1.6]])
        # Two DIFFERENT members take turns: lower +X, then upper +Z.
        # +Z is in the screen plane; +Y would instead lift the joint apart.
        # Upper slot z=-.44 meets lower side z=-.42 after +.02 travel.
        p['display_clearance']=.12  # drawing only: .02 physical -> .14 visible
        p.pop('supports')
        p['modes'][0].update(initial=[0,0,0],distance=.02,fixed='upper',
            supports=[[0,.4,-1.6],[0,.4,1.6]],support_direction=[1,0,0])
        upper=mode(['upper'],[0,0,1],.02,[[0,-.2,-.42]],[])
        upper.update(reaction=[0,0,-1],pull_anchor=[0,.4,1.69],fixed='lower',
            contact_edges=[[[-.38,-.2,-.42],[.38,-.2,-.42]]],
            supports=[[-1.6,.4,0],[1.6,.4,0]],support_direction=[0,0,1])
        p['modes'].append(upper)
    elif jid=='three_way_lap':
        p['projection']='top_orthographic'
        # A horizontal pull engages TWO oblique shoulders. Their opposing
        # normal forces combine against +X; neither face alone is a -X wall.
        n=[math.sqrt(3)/2,0,.5]
        def contact(t): return [.5*t-.23*n[0],.2,-math.sqrt(3)/2*t-.23*n[2]]
        # A static 0.0002 Y clearance removes coincident seated faces from the
        # conservative triangle sweep. No Y motion or vertical force is drawn.
        blocked_pull(p,'lower',[1,0,0],[-.017,-.0002,0],.0342,
            contact(-.35),[contact(-.37),contact(-.19)],
            [1.89,.2,0],[[.8,.4,-1.38],[-.8,.4,-1.38]])
        m=p['modes'][0]
        m['contacts'].append([contact(-.35)[0],.2,-contact(-.35)[2]])
        m['contact_edges'].append([[point[0],point[1],-point[2]] for point in m['contact_edges'][0]])
        m['reactions']=[[-n[0],0,-n[2]],[-n[0],0,n[2]]]
    elif jid=='clamp_head':
        c=[.003,-.2,0]
        p['modes']=[mode(['apron'],[0,-1,0],.02,[c],[[c,[.003,-.8,0],[.003,-2,0]]])]
    elif jid=='zong_corner':
        from zong_profile import build as build_zong_reference
        p = build_zong_reference()
    profiles.append(p)
(OUT/'profiles.json').write_text(json.dumps(profiles,separators=(',',':')),encoding='utf-8')
print('Extracted',len(profiles),'profiles from local OBJ files; no model writes.')
