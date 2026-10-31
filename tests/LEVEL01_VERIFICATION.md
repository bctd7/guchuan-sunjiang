> 历史验收记录。当前已改为固定龙骨、三次手动示范及统一暂缓长度挑战；请以 [当前记录](LEVEL01_CURRENT_VERIFICATION.md) 为准。

# 第一关验收记录 · 2026-10-27

环境：Windows、Godot 4.7.2 stable、OpenGL Compatibility、NVIDIA GeForce RTX 4070 Laptop GPU。

## 实际执行

- 第一关规则：`tests/level01_rules_tests.gd`，146 项通过、0 失败。
- 原有拼装核心回归：`tests/run_tests.gd`，993 项通过、0 失败。
- 原有教学 UI 回归：`tests/ui_tests.gd`，898 项通过、0 失败。
- 新船体几何：`levels/level01/skeleton_geometry_probe.gd`，通过并退出 0。检查实际三角面盲槽、中央实木、槽顶底、左右镜像、根肩、六处半榫尺寸变体、两根贯穿横撑路径与两端燕尾滑入路径。
- 同一船体局部放大：`tests/level01_inspector_tests.gd`，73 项通过、0 失败；结果见同目录 `level01_inspector_report.json`。
- 完整实际输入：`tests/level01_input_tests.gd`，297 项通过、0 失败；结果见同目录 `level01_input_report.json`。在图形 Godot Viewport 中注入鼠标/触屏事件，覆盖错误位置、错误榫型、长短榫实际几何、撤回、重复、UI事件隔离、触屏取消/双触发、动画中撤回、完整11件通关、成功卡片显示时直接重试、九种课堂往返保留精确进度。

所有报告中的 passed/failed 是实际运行结果，不把未执行脚本算作通过。

## 视觉证据

- `evidence/level01/01-start.png`：入口与龙骨定位。
- `evidence/level01/02-incompatible.png`：不兼容榫型拒绝。
- `evidence/level01/03-skewed.png`：长榫歪斜、待纠正提示。
- `evidence/level01/local-blind_tenon-inserting.png`：真实弯肋半榫进入龙骨盲槽。
- `evidence/level01/local-dovetail-inserting.png`：真实龙骨延长段从开放端滑入。
- `evidence/level01/local-through_tenon-inserting.png`：等截面横撑穿过两侧船肋。
- `evidence/level01/ship-cutaway-rib_l1.png`：同源几何的孔内透明观察。
- `evidence/level01/05-complete.png`：成功与科普。
- `evidence/level01/06-complete-frame.png`：完成后的这一段船体俯视；所有零件实际网格包围盒投影在 UI 安全区域内。
- `evidence/level01/lesson-preserved.png`：原有九种榫卯课堂保留。

截图来自实际 Godot 图形 Viewport。局部放大使用新船体零件本身，不是独立教学模型替代品。

## 保全与范围

原工程有大量未提交改动。本次先复制当前有效资源到独立工作副本；新增关卡位于 `levels/level01/`，不改原 `core/`、`demo/`、`education/`、`models/`。合入只新增关卡与本次测试证据，并修改 `project.godot` 的默认入口和 README 的入口说明。入口文件原件备份与合入哈希清单位于任务工作区 `evidence/pre-integration/`、`evidence/deployment-manifest.json`。未提交、未推送 Git。

## 已知边界

- 这是引导点选拼装和几何路径展示，不是任意拖拽、刚体或结构力学仿真；稳定依据是连接规则、长度和左右完整性。
- 本轮验证含模拟触屏事件，未在实体触屏硬件上做真人手感验收，未打包独立安装程序。
- 本关呈现一段船体骨架，不包含铺船板玩法或后续关卡。
- 教学连接布置不作为古船历史复原；半榫、燕尾、透榫的几何和插入方向清楚标注。
- 沙盒图形测试曾出现 shader cache 写入提示；实际图形渲染和输入测试正常完成。
