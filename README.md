# 古船榫匠 · 模型与拼装交互审核版

使用 **Godot 4.7.2** 打开本目录 `project.godot`，按 **F5**。唯一默认入口和独立人工审核场景均为 `res://demo/workshop.tscn`。

本包包含九种教学榫卯、可复用交互核心、自动测试和人工审核场。不含关卡、剧情、整船或联网系统。复杂结构明确标为教学简化，不能据此认定古船使用这些节点。选型、几何源及参考出处见 [models/README.md](models/README.md)。

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
