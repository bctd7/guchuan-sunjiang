# 第二关：让尺寸参照能指导 A/B/C 选材

> 后续用户确认本版仍难理解，已由[第一关式尺寸选材](LEVEL02_FIRST_STYLE_COMPARISON_VERIFICATION.md)替代。以下保留当时实现与证据。

2026-11-08。针对用户指出“模型有变化，但无法从上方方框判断尺寸”的修正。此次仅改第二关显示与相应验证，实体模型、装配规则、第一关和第三关保持本轮开始时的版本。

## 原因与改动

第一关有效的尺寸参照比较的是目标槽与候选榫头的对应段。第二关初版只有静态接收口与各自的数字；扣合中件还把下导槽作为参考，但 A/B/C 的实际区别在上口。这种参照无法帮助选材。

上方框现在以同一坐标和比例叠合接合件的蓝色虚线剖面与所选木料的实色剖面。点选 A/B/C 同步更换真实缺口和尺寸；未选择时只显示参照。通过轮廓本身看偏位、过浅和间隙，不引入对错颜色、自动选材或额外操作模式。

- 企口：沿共同板面对齐，对照舌与槽的厚度、深度及槽心位置。后排错缝的剖切位置取两块真实船板的重叠区，避免切到前板以外。
- 搭扣及隔舱：按同一槽肩对齐，直接看到 A 的浅口、B 的宽口、C 的装配间隙。
- 扣合中件：上口对照下一根实际顶件。三种相同下导槽不再充当选择不同上口的依据。
- 扣合顶件：分上下两层对照真实前件；之前装错的中件继续保留自身窄口或偏移。
- 首处适配的扣合：下层对照实际接收边，上层对照本组选材配套的真实顶件。候选的下口相同，上口差异仍呈现；配套顶件本来就各自能装合，不冒充存在一个能让这种榫型铺成连续船板的尺寸答案。

`opening_comparison.gd` 从实际网格的凸实体单元剖切、合并轮廓，保留真实凹口；既不读取答案编号，也不改变网格、选择或状态。尺寸仍从实体构造参数读取。`opening_measure_panel.gd` 负责绘图，`opening_gallery.gd` 以等宽标签维持 A/B/C 相同相机尺度。选中尺寸集中在对照框，下方保留三张实体候选和原放大入口。

## 验证

在 `/private/tmp/guchuan-opening-comparison-review` 隔离副本中用 Godot 4.7.2 验证；未重启用户正在运行的游戏。证据与源码指纹见 [汇总](evidence/reference-comparison-20261108/verification-summary.json)。

- `opening_dimensions_tests`：七个部位，实际指针切换四个手动节点的 A/B/C；自动件用状态夹具检查显示，不解除其选择门禁。检查真实槽壁尺寸、固定参照与统一比例、三种剖面均不同、未选材状态，以及首处适配模型和错误中件的参照。
- 以图形交集检查真实槽肩干涉与偏移是否确实呈现；该检查仅用于验证，不参与游戏判错。显示计算前后网格、选材和安装记录一致。
- Mac OpenGL 实际渲染并检查 1440×900、960×600 的对照框、三张候选、放大按钮和底部操作；测试窗口最小化且无焦点。
- `three_group_tests`：完整四次拖动、十件安装、自动件保持错误选材、整组撤回、重开取消、自动件真实路径障碍、试浪及首处错误类型完成后失败。
- `starter_lock_tests`：首处配套中件与顶件两次动作、几何保留及失败时机。
- 测试运行器自身 6 项检查和 `git diff --check` 通过。第一关仅作为显示参照阅读，未作改动。

这些检查覆盖实际软件渲染和模拟输入，不替代用户对辨识效果的确认。重新运行当前游戏后加载本轮脚本。

## 实际画面

- [企口 A：槽心与舌错位](evidence/reference-comparison-20261108/scene/compare-plank_0a-A.png)
- [搭扣 B：槽宽于下梁](evidence/reference-comparison-20261108/scene/compare-cross_upper-B.png)
- [扣合中件 B：上口偏离后续顶件](evidence/reference-comparison-20261108/scene/compare-three_middle-B.png)
- [扣合中件 C：对应同一顶件](evidence/reference-comparison-20261108/scene/compare-three_middle-C.png)
- [首处配套扣合的上下层](evidence/reference-comparison-20261108/scene/first-three_way_lap.png)
- [960×600 顶件双层对照](evidence/reference-comparison-20261108/scene/dimensions-three_upper-960.png)
