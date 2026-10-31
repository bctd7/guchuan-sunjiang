> 2026-10-31 Mac 接手基线：先读 [Mac 接手指南](docs/MAC_HANDOFF.md) 与 [迁移验证](docs/MIGRATION_VALIDATION.md)。当前仍为手动检查后晃动；自动失败弹窗和移除“沿槽口推入”悬浮文字尚未完成。下方保留多轮历史记录，旧规则以接手指南和 r6 为准。

> 当前版本已恢复三类接头的可测长度选择：长短均可试装，长度不合在检查时松动，榫型错配仍拒绝。教学页、观察页与任务栏已统一暖色，增加可选故事。详见 [当前操作](docs/ACCEPTANCE.md) 和 [本轮验证](tests/RESUMED_UI_VERIFICATION.md)。下面旧版说明仅作历史记录。

> 当前验收入口：每关先看本关三种榫卯，再开始局部造船。第一关船坊背景与紧凑布局已接入，三次手动示范后七件逐一自动装配；全部动画结束后才可检查。详见 [操作说明](docs/ACCEPTANCE.md) 与 [本轮验证](tests/LAYOUT_CURRENT_VERIFICATION.md)。历史记录保留如下。

# 古船榫匠 · 三关造船与榫卯教学

[当前首关调整与验证](tests/LEVEL01_CURRENT_VERIFICATION.md) · [三关验收操作](docs/ACCEPTANCE.md) · [代码分层](docs/CODE_STRUCTURE.md) · [重构验证记录](tests/REFACTOR_VERIFICATION.md)

使用 **Godot 4.7.2** 打开本目录 `project.godot`，按 **F5** 进入关卡目录，体验“龙骨立架”“船板合壳”“帆樯舾装”。默认入口为 `res://campaign/campaign.tscn`；[导航说明](campaign/README.md)。原有九种榫卯教学仍可通过第一关右上角“九种榫卯课堂”进入，独立教学场景仍为 `res://demo/workshop.tscn`。

本包包含三个关卡的船体局部、九种教学榫卯、可复用交互核心、自动测试和人工审核场。不含整船或联网系统。复杂结构明确标为教学简化，不能据此认定古船使用这些节点。选型、几何源及参考出处见 [models/README.md](models/README.md)。以下操作说明适用于原有教学场。

第一关现为固定龙骨、三次不同榫卯示范和七件同构木件自动补齐。榫型选择集中在局部观察页；三种榫型统一暂缓长度选择，主页面不重复选型。

## 操作

- 菜单切换九模型，列表或场景中点选木件。启动时默认选中第一块可装木件。
- 左键拖木件；空白处拖动环绕镜头；滚轮缩放。拖件期间滚轮暂停，避免争抢输入。
- `X/Y/Z ±` 按钮每次旋转 15°。蓝色虚影为入口，绿色表示满足配对容差。
- 拖近蓝色入口，看到绿色捕获预览和“松手装入”后释放，即会平滑对齐并沿合法路径装入，无需再按 Enter。“移至入口”及装入按钮仍可用于辅助审核。移动、旋转、对齐和插入都检查沿途实体，受阻时保留安全姿态。
- “沿路径装入”或 Enter 沿配置路径装配并锁定。拆卸或 Delete 逆路径退出后停到初始停车位；有依赖的木件须逆序拆卸。
- “透视内孔”检查真实槽口。“重置全部”明确重新摆场，不代表连续物理运动。
- Esc / 失焦取消；装配运动沿已经走过的路径逆退。回退期间不能编辑。UI 上松开取消拖件，不吸附到世界目标。

## 自动验证

先导入资源，再运行与人工场共用正式资源的测试：

```text
godot --headless --editor --path . --import --quit
godot --headless --path . --script models/verify_import_holes.gd
godot --headless --path . --script tests/collision_tests.gd
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_tests.gd
godot --headless --path . --script tests/drag_input_tests.gd
```

本机验证与限制见 [tests/VERIFICATION.md](tests/VERIFICATION.md)。

## 供未来关卡引用

`core/assembly.gd` (`JoineryAssembly`) 独立于 UI、相机和 demo。创建实例、`add_child` 后调用 `load_definition(catalog_entry)`。定义来自 `models/catalog.json`；每实例拥有独立零件、状态、占用和碰撞防护。

- 语义操作：`select_part(id)`、`set_part_pose(id, Transform3D)`、`rotate_part(id, axis, radians)`、`candidate(id, socket_id)`、`snap(id)`、`insert_part(id)`、`capture_candidate(id)`、`insert_assisted(id)`、`remove_part(id)`、`cancel_motion()`、`reset()`。
- 信号：`changed`、`feedback(message)`、`connection_succeeded(part_id)`、`disassembled(part_id)`、`reset_completed`。
- 可配置：`distance_tolerance`、`angle_tolerance_degrees`、`insertion_speed`；连接点位置/角度、路径和前置依赖由模型配置提供。
- 每个非固定木件的 `capture_radius_pixels`（默认64，900高逻辑视口）、`capture_distance`（1.25）、`capture_angle_degrees`（35）控制入口意图辅助。适配器使用1.30倍退出带避免边缘闪烁；按下移动不足5像素只选中。该捕获范围不放宽精确配对接口或碰撞边界。
- 零件局部 connector 与实例局部 socket 配对，不是以鼠标位置判定。`core/interaction.gd` 是可替换的鼠标适配器，用 `configure(assembly, camera)` 绑定。
- 位置路径要求插入前完成角度对齐。入口 connector 计算结果必须与配置路径首姿态一致，否则拒绝装配。
- 外部系统必须通过语义 API 操作，不能直接改木件 `transform` 绕过碰撞。新模型须提供闭合三角网格并验证自身路径。

`core/mesh_collision_guard.gd` 检查同实例全部真实木件，包括未装木件；平移使用连续扫掠，旋转使用保守包络。超预算及非刚体变换拒绝放行。不同实例之间不做实体碰撞，也不模拟摩擦或受力。近接触旋转可能保守拒绝，应先移开再旋转。

## 模型编辑

`models/generate_models.py` 保留可重复生成的参数化源；OBJ 已可靠三角化，勿恢复为凹多边形导出。重新生成需要已有 Blender 环境；运行本工程不需要 Blender，本轮未安装任何软件。不要把 `.godot/` 缓存纳入版本或交付 ZIP。
