# 9 种教学榫卯几何

`catalog.json` 是 Godot 数据契约。21 个 OBJ 木件均采用共同模型原点、Y 向上，坐标单位为教学尺度，不是可直接加工的施工尺寸。所有凹槽、盲孔、通孔、榫肩、斜口均为实体网格，边缘有 0.009 单位的真实倒角。木色由游戏材质提供。

## 变体与核图
- 燕尾：开放端滑动燕尾，梯形榫截面；沿槽轴插入，不从槽上方压入。参考墨尔本大学工作坊燕尾结构说明：https://ms-kb.msd.unimelb.edu.au/machine-workshop/making/step-by-step/joining/dovetail-joint
- 半榫：盲直榫，卯眼保留封闭底壁；并非十字刻半
- 透榫：有肩单直贯通，整截面直榫穿出对侧
- 搭扣：两件十字刻半搭接
- 企口：连续直舌槽拼板
- 扣合：三横交叉变体，三根横材在交汇处分配下、中、上三层，非三件同时削半
- 粽角：三方角斜接、双直榫教学变体；保留角腿、两根斜接横材、双榫入卯与分步落位；省略图中复杂斜肩细节，不是原图等比例复刻
- 夹头：开叉腿夹牙条，腿顶双榫进入局部案面；省略装饰牙板曲线
- 穿榫：L 型阶梯小出榫，前端较小、后端较大，以减少柱身切除；本变体未加木楔

核图来源：T/ZZB 0959—2019《深色名贵硬木家具》附录 A，A.14（三横交叉，PDF第21页/纸17）、A.17（粽角，PDF第23页/纸19）、A.27（夹头，PDF第28页/纸24）。原文：https://qxb-img-osscache.qixin.com/standards/1e366d3f4f33deb45fe71e33149cde95.pdf

台湾文化部门《传统大木构造与修复》，PDF第18页表格“穿榫 / L 型穿榫”，已核看图示与结构说明。原文：https://themefile.culture.tw/file/2021-10-29/3290c275-f65e-4350-9c0a-12be949b2c4d/5-1_%E5%82%B3%E7%B5%B1%E5%A4%A7%E6%9C%A8%E6%A7%8B%E9%80%A0%E8%88%87%E4%BF%AE%E5%BE%A9.pdf

这些名称描述教学选型，不构成互斥的传统榫卯分类，也不宣称它们全部为古船原位构造。

## 重新生成与检查

在 Blender 4.3 上执行：

    blender -b -t 4 --python models/generate_models.py
    blender -b -t 4 --python models/validate_geometry.py
    blender -b -t 4 --python models/render_previews.py

`geometry_checks.json` 是倒角前检查；`validation_report.json` 独立重读最终 OBJ，检查所有件正体积、流形闭合、装配态每对木件交体积，以及逐段插入路径每段41点的实体布尔相交体积。采样检查不是对任意用户自由拖拽路径的连续碰撞保证。合法装拆应遵守 catalog 的路径与依赖；拆卸为逆依赖、逆路径。

`previews/` 为最终导出几何的爆炸图，真实槽口可见。预览由 CPU Cycles 渲染，无 GPU 依赖。交付不包含来源整本 PDF。
