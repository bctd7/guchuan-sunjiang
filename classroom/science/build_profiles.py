"""Authoring helper: all coordinates refer to actual generated model geometry."""
import json
from pathlib import Path
root=Path(__file__).parent

def face(normal, point, lo, hi, label):
 return dict(normal=normal, point=point, bounds_min=lo, bounds_max=hi, label=label)
def entry(part, force, free, text, freedom, faces):
 return dict(part=part, proposed_force=force, permissible=free, explanation=text, freedom=freedom, faces=faces)
def floor(y, lo, hi,label='下侧承压候选面'):
 return face([0,-1,0],[0,y,0],lo,hi,label)
p={}
p['dovetail']=[entry('tail',[0,1,0],[0,0,1], '向上提拉时，燕尾两侧斜面在间隙闭合后阻挡上拔；这里只解释形状约束，不计算承载力。','槽沿 Z 贯通，未设端挡；忽略摩擦时可沿 +Z 滑出，沿 −Z 也可滑动。',[
 face([.34,.15,0],[.40,-.30,0],[.24,-.31,-1.01],[.41,.018,1.01],'右侧燕尾斜面'),
 face([-.34,.15,0],[-.40,-.30,0],[-.41,-.31,-1.01],[-.24,.018,1.01],'左侧燕尾斜面')])]
for k in ['blind_tenon','through_tenon']:
 end=.25 if k=='blind_tenon' else -.77
 p[k]=[entry('beam',[0,-1,0],[1,0,0], '梁向下受力时，榫下表面与卯眼下壁在间隙闭合后承压；上/下及侧壁限制横向错位。'+('盲孔有底，但不能据此推断抗拔。' if k=='blind_tenon' else '贯通并不等于自锁；模型没有销或楔。'), '沿 +X 反向拔出在几何上可行；不把摩擦、胶合或未建模的销楔当作约束。', [floor(-.27,[max(end,-.64),-.28,-.24],[.64,-.26,.24])])]
p['cross_lap']=[entry('upper',[0,-1,0],[0,1,0], '刻半搭接的台阶承托向下作用；缺口侧壁限制平面内部分错位。','上方开放，沿 +Y 抬起可以分离；搭接本身不保证抗拔。',[floor(.018,[-.43,.01,-.43],[.43,.025,.43],'刻半缺口底面')])]
p['tongue_groove']=[entry('tongue',[0,-1,0],[1,0,0], '直舌上下表面与槽壁配合，限制板间高低错位；间隙闭合后才形成承压接触。','沿 +X 拉开可分离；槽沿 Z 开放，还允许沿槽方向滑动。',[floor(-.09,[-.32,-.10,-1.39],[-.01,-.08,1.39],'直舌下表面')])]
p['three_way_lap']=[entry('middle',[0,-1,0],[0,1,0], '分层缺口通过局部台阶承托中层件；这里只标出中心重叠区域，不把整根横材当作接触面。','上层未压住时可沿 +Y 抬起；若上层已在位，应先移除上层，不能把局部自由度当成整组自由度。',[floor(-.15,[-.2,-.16,-.2],[.2,-.14,.2],'中心台阶下表面')]),entry('upper',[0,-1,0],[0,1,0], '三层分配让位，顶层件由下方台阶承托；几何不等同于复杂传统榫型的完整复原。','最上层沿 +Y 抬起可分离；整组受力还取决于各杆支承，未在这里求解。',[floor(.15,[-.10,.14,-.10],[.10,.16,.10],'中心台阶下表面')])]
# Current long/short vertical-tenon model: diagonal shoulder planes are
# x+y=1.008 / y+z=1.008, opposed by the leg planes at 0.992.
# Clip away the sockets and the miter edge; keep only real mesh triangles.
p['zong_corner']=[entry('xrail',[0,-1,0],[0,1,0], '当前长短竖榫模型中，大边横材的斜肩与角腿斜肩相对；向下移动使间隙闭合。青色仅标出原网格上的一小块候选接触面，不表示应力大小。','仅就当前刚性几何，横材沿 +Y 可脱离竖榫；游戏中固定大边横材是装配基准，不代表实物不能移动。',[face([-1,-1,0],[.6,.408,.4],[.6,.208,.4],[.8,.408,.5],'大边横材与角腿相对的斜肩')]),entry('zrail',[0,-1,0],[0,1,0], '当前长短竖榫模型中，抹头横材的斜肩与角腿斜肩相对；向下移动使间隙闭合。短竖榫位于有侧壁的卯眼中，不沿用旧模型的水平底面。','仅就当前刚性几何，沿 +Y 提起可脱离短竖榫；这是独立几何观察，不是游戏横向装配路径或历史构造强度结论。',[face([0,-1,-1],[.4,.408,.6],[.4,.208,.6],[.5,.408,.8],'抹头横材与角腿相对的斜肩')])]
for profile in p['zong_corner']:
 profile['required_neighbors'] = ['leg']
p['clamp_head']=[entry('apron',[0,-1,0],[1,0,0], '牙条下表面由开叉腿槽底承托；两侧夹颊限制 Z 向偏移，但本模型牙条没有 X 向端挡。','沿 +X 可从夹槽滑出；案面在位时不能直接向上抬出。',[floor(-.18,[-.39,-.19,-.16],[.39,-.17,.16],'牙条在夹槽内的下表面')]),entry('top',[0,-1,0],[0,1,0], '局部案面下侧由腿肩承托，双卯眼与腿顶双榫配合定位；不能把槽顶间隙当作已有压力。','沿 +Y 可提起退出双直榫；模型无楔、胶或其他抗拔紧固。',[floor(.40,[-.39,.39,-.39],[.39,.41,.39],'案面在腿肩上的下侧面')])]
p['l_through']=[entry('beam',[0,-1,0],[1,0,0], '阶梯榫下表面与柱中卯眼下壁配合承托；本模型是水平插入的 L 形截面，不是钩住柱子的倒扣。','沿 +X 可反向拔出；未加木楔，不能宣称穿出端天然防拔。',[floor(-.29,[-.64,-.30,-.23],[.64,-.28,.23],'阶梯榫下表面')])]
p['three_way_lap'][0]['blocked_by'] = ['upper']
p['clamp_head'][1]['faces'] = [floor(.40,[xl,.39,zl],[xh,.41,zh],'案面对应腿肩的下侧面') for xl,xh in [(-.39,-.28),(.28,.39)] for zl,zh in [(-.39,-.20),(.20,.39)]]
(root/'profiles.json').write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n')
