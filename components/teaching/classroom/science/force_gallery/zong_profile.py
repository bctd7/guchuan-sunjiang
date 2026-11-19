"""Build ONLY zong_corner from current OBJ; never regenerate other lessons.
No execution of the shared generator's top-level output loop.
"""
from pathlib import Path
import ast, hashlib, json, argparse

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent

def build():
    source = ROOT / 'components/teaching/classroom/science/force_gallery/generate_profiles.py'
    tree = ast.parse(source.read_text(encoding='utf-8'))
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)]
    helpers = {}
    exec(compile(ast.Module(body=functions,type_ignores=[]),str(source),'exec'), helpers)
    catalog = json.loads((ROOT/'models/joinery/catalog.json').read_text(encoding='utf-8'))
    item = next(x for x in catalog if x['id']=='zong_corner')
    p = dict(id='zong_corner', diagram_kind='zong_reference_v1',
             force_kind='blocked_pull', axis=2, at=.2, iso=True,
             cutaway=dict(at=.2, keep='x<=at OR z<=at'),
             camera_right=[.8660254,0,-.8660254], camera_down=[.35,-1,.35],
             camera_toward=[1,.7,1], supports=[[.2,-2,.95],[.95,-2,.2]], parts=[])
    for spec in item['parts']:
        path = ROOT/spec['mesh'].removeprefix('res://')
        vs,fs = helpers['mesh'](path)
        part=dict(id=spec['id'],source=spec['mesh'],sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                  vertices=vs,faces=fs,polygons=[])
        helpers['add_cutaway'](part,.2)
        p['parts'].append(part)
    p['modes']=[]
    for moving,direction,contact,anchor in [
        ('xrail',[1,0,0],[.40,.76,.20],[2.99,.76,.20]),
        ('zrail',[0,0,1],[.20,.70,.40],[.20,.76,2.99])]:
        p['modes'].append(dict(moving=[moving],direction=direction,initial=[0,0,0],
            distance=.02,contacts=[contact],reaction=[-x for x in direction],
            pull_anchor=anchor,paths=[],removable=False,contact_edges=[]))
    return p

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--merge',action='store_true')
    args=parser.parse_args()
    p=build()
    (OUT/'zong_profile.json').write_text(json.dumps(p,separators=(',',':')),encoding='utf-8')
    if args.merge:
        target=ROOT/'components/teaching/classroom/science/force_gallery/profiles.json'
        profiles=json.loads(target.read_text(encoding='utf-8'))
        before={x['id']:x for x in profiles if x['id']!='zong_corner'}
        profiles=[p if x['id']=='zong_corner' else x for x in profiles]
        assert before=={x['id']:x for x in profiles if x['id']!='zong_corner'}
        target.write_text(json.dumps(profiles,separators=(',',':')),encoding='utf-8')
    print('Built zong only; 2 sequential pulls; source hashes recorded; merged='+str(args.merge))
