> 历史归档（2026-10-31 整理）。原路径：`levels/level03/README.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 第三关 · 帆樯舾装

入口：`res://levels/level03/level03.tscn`。根节点 Node3D，公开 `state`、`view`、`panel`；信号 `level_completed`、`return_requested`。返回按钮占用 `(1230,20,190,52)`。

三台场依次完成桅座抹头、下装角腿、桅杆方脚、桅顶牙条、帆桁承托板、L 型穿榫舵架横撑、无叶圆舵轴、侧装舵叶，最后左/右 ±30° 实测。所有布置与角度均为教学假设。

粽角按已核验凸体/切槽参数配方重新造船框木料，在布尔运算前设定本关 4.4 框臂和 −2.225 角腿底高，由 `generate_ship_zong.gd` 独立烘焙至本关 `assets/ship_mastframe_*.obj`；不读取或修改独立教学 OBJ。角腿下方无甲板阻挡。夹头是桅顶本体叉口先夹牙条，双榫再入承托板双槽。L 穿榫是较小前端与较大后段的实际阶梯几何，不能以普通直透榫替代。

圆轴径 0.34 / 轴承孔径 0.40，径向间隙 0.03。先放无叶圆轴，顶肩停在轴承上；舵叶开口半夹套从 -Z 侧入，另一半始终停在 +Z 外侧，再从 +Z 合抱并固定可拆销。夹套/销不是本关三种榫卯。只有圆轴/舵叶共同父节点转动，L 榫横撑和舵架不动。

规则、状态、几何、视图、候选展示和界面独立；指针层复用第一关已验证 Touch helper。主局部视图使用 1075×400 SubViewport，根屏幕偏移 `(345,190)`；所有槽口坐标统一返回根 Viewport 坐标。候选为真实船件网格端部裁切，接合端完整、切面封闭，含上下补光，并按投影边界自动留边。

验证：`tests/level03_input_tests.gd` 155 项通过（真实 Viewport 鼠标/触屏；错误、正确、重复、撤回重试、全关完成、左右操舵）；`tests/level03_geometry_tests.gd` 24 项通过（实际三角网格空腔/实心点与每条路径 17 个姿态的内部表面采样）。它们是教学尺度验证，不是制造公差或连续碰撞数学证明。`tests/level03_preview_tests.gd` 是最终裁切/补光与侧装动画的针对性视觉夹具，不是玩家输入测试。

二维结构图：`docs/design/level03_structure.png`；设计方案：`docs/design/level03_design.md`。输入/几何报告：`tests/level03_input_report.json`、`tests/level03_geometry_report.json`。PNG 截图位于 `tests/level03_evidence/`，最终候选修订以 `gallery-*-final.png` 为准。工作区日志：`evidence/level03-*.log`。
