# 第二关：参考第一关的选材 UI

> 历史记录：完整参数及切换榫型仍固定同一参照的做法，已由[关键尺寸与实际接头参照](LEVEL02_KEY_COMPARISON_VERIFICATION.md)修订。

2026-11-08。用户确认上一版叠合剖面仍难理解，要求充分参考第一关的做法与 UI，并让比较更清楚。本轮以实际启用的 `level01/length_measure_panel.gd`、`length_candidate_gallery.gd` 和游戏页面为参照。

## 最终展示

上方采用第一关的固定目标标尺、单一目标示意及两行说明。下方三张卡按照“真实模型—编号与对应尺寸—放大”排列，A/B/C 的数值始终同时可见。取消虚线接合件与实色候选相叠的小剖面图。

| 部位 | 上方目标 | 下方候选比较 |
|---|---|---|
| 企口 | 同一板面到榫心 9 格，舌厚 6 格、伸出 9 格 | 位置 4.5 / 9 / 13.5 格；三件都显示槽宽 7、深 10 |
| 搭扣与隔舱 | 下梁宽 28 格、需让出 12 格深度 | A：宽 28.4、深 6；B：宽 46、深 12；C：宽 28.4、深 12 |
| 扣合中件 | 后续真实顶件宽 28 格、交叉位置在中心 | A：上口 13、偏 0；B：上口 28.4、偏 30；C：上口 28.4、偏 0 |
| 扣合顶件 | 上下两层接合宽度、深度分别列出；保留实际已装中件上口及偏移 | 口宽、上下槽深、偏移分行显示 |

标尺水平尺寸使用模型单位换算；目标示意的纵向厚度为说明性绘制，与第一关参考框一致。三张三维候选之间保持相同相机尺度；不把二维标尺与三维透视图宣称为同一像素尺度。

参考框沿用第一关 156 的基础高度及 18/13/10 的标题、说明、刻度字号。候选沿用 72 基础行高及 15 号文字；扣合顶件需要三行，行高按字体实际需求扩展到 84，保持字号和完整显示。三张尺寸栏统一取最大宽度，避免某张数字较长而挤小其模型。

目标参照来自当前安装部位的真实接收结构，与第一关一样不会因候选切换或错误榫型变成新的目标。第一处错误搭扣、扣合仍使用各自真实适配木料；完成局部接头后报错的既定玩法不变。`opening_reference.gd` 只读目标；`opening_dimensions.gd` 只格式化候选；显示模块不查询答案、不改变实体和装配。旧 `opening_comparison.gd` 及其 UID 路径已由新模块替代。

## 验证

测试工程为 `/private/tmp/guchuan-first-style-review`，基线为 `/private/tmp/first-style-baseline`。没有重启用户正在运行的游戏。

- 实际进入第一关并记录固定目标框高度、候选行高与字号，同时保存第一关截图，随后在同一战役实例进入第二关比较。
- `opening_dimensions_tests`：最终 headless 与 Mac GPU 均通过。七个部位、1440×900 与 960×600；三张尺寸同时可见、相机尺度一致、文字/模型/放大按钮完整落在卡片内，页面不挤出底栏。
- 实际指针切换 A/B/C，核对固定目标不随选择变化；确认错选类型也不改写固定目标。尺寸与真实槽壁、前件数据对应；放大另一张卡不改变选材。
- 扣合保留错误中件 13 格窄口或 30 格偏移，未用正确模板替换前件。
- `three_group_tests`、`boat_joint_interaction_tests`、`starter_lock_tests` 通过：完整组装、自动件继承原选材、错选可继续、九种扣合组合、不可继续自动失败，以及首处配套扣合两次动作与失败时机。
- 最后对扣合文字做分行与行高调整后，重新通过尺寸/UI 的 headless 与 GPU 检查；装配代码、几何、状态及输入文件与本轮基线完全相同。
- 测试运行器 6 项检查、`git diff --check` 通过。240 个生产/测试 GDScript 与最终隔离副本一致。第一、三关代码与实体模型本轮未改。

GPU 使用 Godot 4.7.2、OpenGL Compatibility，测试窗口最小化且无焦点。验证包含软件渲染与模拟鼠标输入，是否足够直观仍需用户在游戏中确认。证据见[验证汇总](evidence/first-style-comparison-20261108/verification-summary.json)。

## 实际画面

- [第一关实际页面](evidence/first-style-comparison-20261108/scene/chapter-1-reference.png)
- [第二关企口：三种位置同时比较](evidence/first-style-comparison-20261108/scene/plank_0a-1440.png)
- [第二关搭扣：同时比较宽度与深度](evidence/first-style-comparison-20261108/scene/cross_upper-1440.png)
- [第二关扣合中件：上口与偏移](evidence/first-style-comparison-20261108/scene/three_middle-1440.png)
- [960×600 扣合顶件：上下槽深与偏移分行](evidence/first-style-comparison-20261108/scene/three_upper-960.png)
- [原截图所处的首处错误搭扣选择](evidence/first-style-comparison-20261108/scene/first-cross_lap.png)
