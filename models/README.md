# 9 种教学榫卯几何

`catalog.json` 是 Godot 数据契约。21 个 OBJ 木件均采用共同模型原点、Y 向上，坐标单位为教学尺度，不是可直接加工的施工尺寸。所有凹槽、盲孔、通孔、榫肩、斜口均为实体网格。其余18件保留原有0.009单位倒角；新版粽角3件使用明确配合间隙，未添加倒角。木色由游戏材质提供。

## 变体与核图
- 燕尾：开放端滑动燕尾，梯形榫截面；沿槽轴插入，不从槽上方压入。参考墨尔本大学工作坊燕尾结构说明：https://ms-kb.msd.unimelb.edu.au/machine-workshop/making/step-by-step/joining/dovetail-joint
- 半榫：盲直榫，卯眼保留封闭底壁；并非十字刻半
- 透榫：有肩单直贯通，整截面直榫穿出对侧
- 搭扣：两件十字刻半搭接
- 企口：连续直舌槽拼板
- 三横交叉扣合榫：三根横材在交汇处分配下、中、上三层，非三件同时削半；来源为 T/ZZB 0959—2019 A.14（PDF 第21页）
- 粽角：三向45°斜肩、互相垂直的长短榫、对应深浅卯眼，以及两横材间的横向榫卯。短榫顶端与内侧斜肩让开横材互接榫。先固定大边、水平装入抹头，最后从下方装角腿；不需要移动已锁定的横材。参考 https://chinesejoinery.com/zh/joints/zongjiao-sun/ 的已取得结构文字，尺寸独立设计，不是原图等比例复刻或强度认证
- 夹头：开叉腿夹牙条，腿顶双榫进入局部案面；省略装饰牙板曲线
- L 型穿榫：阶梯小出榫，前端较小、后端较大，以减少柱身切除；本变体未加木楔，不称为自锁结构。交互完成后的固定是游戏规则

核图来源：T/ZZB 0959—2019《深色名贵硬木家具》附录 A，A.14（三横交叉，PDF第21页/纸17）、A.17（粽角，PDF第23页/纸19）、A.27（夹头，PDF第28页/纸24）。原文：https://qxb-img-osscache.qixin.com/standards/1e366d3f4f33deb45fe71e33149cde95.pdf

台湾文化部门《传统大木构造与修复》，PDF第18页表格“穿榫 / L 型穿榫”，已核看图示与结构说明。原文：https://themefile.culture.tw/file/2021-10-29/3290c275-f65e-4350-9c0a-12be949b2c4d/5-1_%E5%82%B3%E7%B5%B1%E5%A4%A7%E6%9C%A8%E6%A7%8B%E9%80%A0%E8%88%87%E4%BF%AE%E5%BE%A9.pdf

这些名称描述教学选型，不构成互斥的传统榫卯分类，也不宣称它们全部为古船原位构造。

## 重新生成与检查

新版粽角使用已安装Godot的CSG实体布尔烘焙为静态OBJ，运行场景只加载网格，不运行CSG：

    godot --headless --path . --script models/generate_zong_corner.gd
    godot --headless --editor --path . --import --quit
    godot --headless --path . --script tests/zong_geometry_tests.gd
    godot --headless --path . --script tests/zong_input_tests.gd

`zong_corner_solids.json` 是版本化凸体/布尔配方；`build_zong_solids.py` 可用现有NumPy/SciPy重新生成配方。`zong_corner_definition.json` 保存装配顺序、入口和路径。以下Blender总生成器保留这份新版定义和网格，不再写回旧版双等长榫。

在 Blender 4.3 上执行：

    blender -b -t 4 --python models/generate_models.py
    blender -b -t 4 --python models/validate_geometry.py
    blender -b -t 4 --python models/render_previews.py

`geometry_checks.json` 的原18件是倒角前检查，新粽角3件为最终静态网格检查；`validation_report.json` 为实际最终网格的正体积、闭合、装配态交体积及路径采样记录，逐项标注验证来源。新版另由未修改的连续扫掠守卫检查完整横材插入和角腿上装，并测试错误横移受阻。采样本身不能替代连续碰撞保证。未完成木件可原路退回，完成后的不可拆卸是游戏规则，不能当作实物自锁或强度结论。

`previews/` 为最终导出几何的爆炸图，真实槽口可见。原18件预览来自CPU Cycles；新版粽角预览来自Godot真实渲染。交付不包含来源整本PDF。三件搭扣参考照片未显示暗槽、第三件止挡和退出约束，故保留双件基础版，未凭照片增造结构。
