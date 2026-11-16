# 第二关：正面缺口与同尺度参照

## 2026-11-09 交互复查

独立复查发现并修复了初始截图没有暴露的三处问题：单张候选滚轮缩放会破坏同比例比较；现有“重置视角”不复位候选；放大窗沿用缺口局部取景，整根木料被裁出画面。

现在 A/B/C 同步缩放，上方参照跟随实际比例；现有重置入口同时恢复三张卡的正面与原比例；放大窗自动容纳完整木料，默认略倾斜以看清厚度，已转动的观察方向保留。尺寸图和标线限制在各自图形区域内，近距离缩放不会盖住文字或邻卡。完整木料取景只对第二关开口候选启用。

新增 `opening_navigation_tests` 用真实视口事件复现旧版的上述三类问题，并验证修复后滚轮、鼠标／模拟触摸旋转、复位、放大与返回。覆盖四个手动位置、首处两种异型接法和两种窗口尺寸；检查过程保留原选材与已装状态。尺寸检查、交互复查和已有完整装配检查通过，实际 GPU 截图已查看。

- [缩放后的同比例面板](evidence/comparison-selfcheck-20261109/scene/cross_upper-1440-scaled.png)
- [完整企口木料放大](evidence/comparison-selfcheck-20261109/scene/plank_0a-1440-magnified.png)
- [小窗口近距离对照](evidence/comparison-selfcheck-20261109/scene/cross_upper-960-closeup.png)
- [本次复查与源文件汇总](evidence/comparison-selfcheck-20261109/verification-summary.json)

## 2026-11-08 初始改版

2026-11-08。此前只精简文字和参数，候选缺口仍斜向、偏小，参照也没有与实体卡共用比例。此次对照第一关的实际画面和实现，改为能直接比较轮廓的选材面板。

## 显示改动

- 保留第一关式三行实体模型、编号、放大入口和字号。候选默认正对接合面，缩短文字栏，扩大实际缺口；仍可旋转并放大完整木料。
- 参照与三张候选使用相同的默认相机比例和测量基准。企口从木料下边量到凸条／槽口中心；搭扣在实际缺口处标出宽和深；扣合保留宽度与居中／偏旁差异。共同尺寸不重复列出。
- 企口缩略图正视时裁去远处遮挡槽口的一体定位键，转动后恢复完整深度，放大窗始终显示完整模型。每次换接法恢复远裁面，避免后续候选变为空白。
- 首处搭扣仍量取真实座木，不把候选答案当作参照；首处配套扣合没有统一目标尺寸，保留两件关系说明。后段异型接法仍省去无法对应的数字。
- 后段顶撑的参照来自两根已装木料的实际截面。已装中件 A/B/C 的错误宽度或偏位都会保留；从能看到这些区别的一侧取截面，不使用正确模板替代。

`opening_gallery.gd` 负责取景，`opening_measure_marks.gd` 将真实尺寸投影到模型上；`opening_measure_panel.gd` 共用候选的默认比例；`opening_section.gd` 只读取凸体截面。模型构造、装配规则、状态和拖动逻辑相对本轮基线未改。

## 验证

在 `/private/tmp/guchuan-direct-comparison-review` 隔离工程完成，已验证的脚本逐文件原样合回工程。未重启用户正在运行的游戏。

- `opening_dimensions_tests` 无图形及 Mac GPU 检查通过：实际第一关参照、七个部位、1440×900 与 960×600、A/B/C 点击和放大、相同像素比例、尺寸标线与模型一致、换榫型后实体仍可见、已装错件截面保留。
- `boat_joint_interaction_tests` 通过；`inspection_workspace_tests` 覆盖完整装配、失败、缩放、鼠标和模拟触摸，通过。
- 广泛交互夹具最初有 13 项旧预期失败，在本轮修改前的副本也同样失败。修正了三组自动补齐后的错误件／漏水数量，以及末件已改为顶撑后的撤回测试对象；未为通过测试改动玩法。
- 实际 GPU 截图已查看，小窗口缺口、文字和按钮可见。GPU 窗口保持最小化、无焦点。无图形运行出现 macOS 证书环境警告，无脚本或渲染错误；不代替真人设备体验验收。

## 实际画面

- [首处搭扣](evidence/direct-comparison-20261108/scene/first-cross_lap.png) · [960×600](evidence/direct-comparison-20261108/scene/first-cross_lap-960.png)
- [企口高度](evidence/direct-comparison-20261108/scene/plank_0a-1440.png)
- [扣合中件](evidence/direct-comparison-20261108/scene/three_middle-1440.png) · [扣合顶件](evidence/direct-comparison-20261108/scene/three_upper-1440.png)
- [第一关实际参照](evidence/direct-comparison-20261108/scene/chapter-1-reference.png)
- [验证与源文件汇总](evidence/direct-comparison-20261108/verification-summary.json)

本记录替代上一版关键参数显示的交接结论；较早证据保留作历史。
