"""Compare fixed ground/base pixels across actual Godot captures, all nine IDs."""
from pathlib import Path
from PIL import Image
import json,numpy as np
stage=Path(__file__).resolve().parents[1]/'.stable-support-20261023'
metadata=json.loads((stage/'pixel-probes.json').read_text())
passed=0;results={}
for joint,data in metadata.items():
    files=sorted(stage.glob(joint+'-*.png'))
    assert files,joint
    if joint=='dovetail':
        s=data['scale'];ox,oy=data['origin']
        boxes=[(ox+216*s,oy+235*s,ox+225*s,oy+355*s),(ox+260*s,oy+373*s,ox+350*s,oy+379*s)]
    else:boxes=[(x-6,y-.4,x+6,y+.4) for x,y in data['supports']]
    probes=[]
    for box in boxes:
        x0,y0,x1,y1=[round(x) for x in box]
        if y1<=y0:y1=y0+1
        masks=[]
        for file in files:
            a=np.asarray(Image.open(file).convert('RGB'))[y0:y1,x0:x1]
            masks.append((a[:,:,0]<100)&(a[:,:,1]<115)&(a[:,:,2]<125))
        assert masks[0].any(),joint+' probe must contain actual support/base ink'
        for mask in masks:
            assert np.array_equal(mask,masks[0]),joint+' fixed pixels moved'
            passed+=1
        probes.append(dict(box=[x0,y0,x1,y1],ink_pixels=int(masks[0].sum())))
    results[joint]=dict(rendered_frames=len(files),probes=probes)
def upper_top(file):
    a=np.asarray(Image.open(file).convert('RGB'))
    mask=(a[:,:,0]>210)&(a[:,:,1]>170)&(a[:,:,2]>90)&(a[:,:,2]<190)
    return np.where(mask)[0].min()
assert upper_top(stage/'dovetail-t0.00.png')-upper_top(stage/'dovetail-t1.40.png')>8,'actual upper member must still move'
passed+=1
(stage/'pixel-results.json').write_text(json.dumps(results,indent=2),encoding='utf8')
print('NINE-JOINT FIXED SUPPORT PIXELS:',passed,'passed, 0 failed')
