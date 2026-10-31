from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path('docs/design'); im=Image.new('RGB',(1600,1120),'#eee7d9'); d=ImageDraw.Draw(im)
f='C:/Windows/Fonts/msyh.ttc'
def t(x,y,s,n=24,c='#405343'):d.text((x,y),s,font=ImageFont.truetype(f,n),fill=c)
def box(r,c='#dcc29b',o='#92714d',w=3):d.rectangle(r,fill=c,outline=o,width=w)
t(50,24,'第二关 · 船板合壳 — 精确二维结构草图',36)
t(50,80,'教学尺度：船长 X = 8.00；板列宽 0.78；厚 0.18；企口深 0.09、厚 0.06。并非施工尺寸。',22)
t(50,128,'A 侧板展开图｜由底向舷，6 件船板 / 3 列；红色只标板端接缝',27)
x0,y0,scale=80,215,125
seams=[-1.4,1.4,-1.4]
for row,seam in enumerate(seams):
 y=y0+(2-row)*110
 for a,b in [(-4,seam),(seam,4)]:box((x0+(a+4)*scale,y,x0+(b+4)*scale,y+97),'#dcc29b' if row%2==0 else '#b89569')
 x=x0+(seam+4)*scale;d.line((x,y,x,y+97),fill='#b44732',width=7)
 t(1100,y+30,f'{row+1} 列   端缝 X={seam:+.2f}',22)
 if row<2:
  yy=y-7;d.line((80,yy,1080,yy),fill='#2d8086',width=3)
t(90,560,'局部后侧·截断 X=-4.00',20);t(855,560,'局部前侧·截断 X=+4.00',20)
t(80,605,'✓ 相邻板列端缝相差 2.80；长水平接边是企口拼边，不是“错缝”。',24)
t(80,645,'✕ 对齐候选：三列端缝均 X=-1.40 → 可试装；验收显示红缝/漏水并可撤回修正。',23,'#a1432e')
box((50,705,515,1010),'#fff8e8');box((550,705,1040,1010),'#fff8e8');box((1075,705,1550,1010),'#fff8e8')
t(70,720,'B 企口 · 船板连续长边',24)
# exact local scaled cross section tongue at left .09 x .06 and matching slot
box((95,805,245,895));box((245,835,290,865));box((294,805,435,833));box((294,867,435,895));box((338,833,435,867));
t(70,930,'侧向合入：舌 0.09×0.06',20);t(70,966,'槽 0.10×0.07；非独立教学旧模型',18)
t(570,720,'C 搭扣 · 隔舱边框十字',24)
box((610,825,970,875));box((765,770,815,930),'#b89569');d.rectangle((765,825,815,875),fill='#a78561',outline='#405343',width=3)
t(570,946,'两材各刻半：0.12 / 总厚 0.24',20);t(570,978,'固定下材；上材由上落入（第 7 件）',18)
t(1095,720,'D 扣合 · 隔舱三向横撑',24)
for a,b in [((1120,850),(1500,850)),((1230,785),(1390,925)),((1230,925),(1390,785))]:d.line((a,b),fill='#b89569',width=32)
d.ellipse((1291,831,1329,869),fill='#405343')
t(1095,946,'三横 0°/+60°/-60°；交点各留 1/3',18);t(1095,978,'中、上依次落入（第 8、9 件）',18)
t(50,1040,'第 10 件：隔舱板。完成展示局部船壳与隔舱；需填缝/密封并试水，木榫本身不保证水密。',23)
im.save(p/'level02-structure.png')

