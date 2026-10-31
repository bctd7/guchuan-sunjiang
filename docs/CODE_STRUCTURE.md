# 三关代码分层

依赖方向：输入与 UI 发出操作意图 → 本关协调器调用状态 → 状态调用纯规则 → 状态变化刷新视图和 UI。视图与几何不决定能否通关，公共层不依赖任何具体关卡。

| 职责 | 文件位置 | 边界 |
|---|---|---|
| 关卡目录、实例保留、关间跳转 | `campaign/campaign.gd` | 不承载榫卯规则 |
| 本关流程和信号连接 | `levels/level0N/level0N.gd` | 协调状态、展示、动画；不生成榫卯实体 |
| 配合要求、顺序约束、候选定义 | 各关 `connection_rules.gd` | 纯数据与判定，无节点和 UI |
| 进度、选择、撤回、重置、通关状态 | 各关 `level_state.gd` | 唯一玩法状态来源，不创建模型 |
| 实体几何和材质 | 各关 `ship_geometry.gd` | 不处理鼠标、按钮、关卡流程 |
| 场景、槽口投影、镜头和装入动画 | `skeleton_view.gd` / `hull_view.gd` / `rigging_view.gd` | 读取状态显示结果，不绕过状态接受连接 |
| 面板布局与文字反馈 | 各关 `level_ui.gd` | 按钮发信号，不能直接放置部件 |
| 候选和局部观察 | 各关 gallery、首关 inspector/comparison/orbit | 展示真实部件与同尺度比较，不修改已接受连接 |

## 公共机制

- `levels/shared/socket_interaction.gd`：三关共用的点击/触摸手势适配；视图只需提供 `pick_socket(position)`。保留按钮消费事件、拖动阈值、触摸去重、失焦取消机制。旧 `level01/touch_interaction.gd` 留作兼容入口。
- `levels/shared/chapter_ui.gd`：共用面板、文字、按钮与反馈色；尺寸布局仍由各关拥有，原木质风格来源继续使用 `demo/friendly_theme.gd`。
- `levels/shared/mesh_end_crop.gd`：从实际部件裁出并封闭端部预览，仅供展示，不改源几何；第三关候选 UI 不再负责三角面裁切。

首关的 `ship_geometry.gd` 由原 `skeleton_view.gd` 原样抽出实体构造，视图保留长度变体、姿态和动画等展示接口。第二、三关已有各自几何模块，不强行统一不同的装配规则、场景布局或纹理参数。九种原教学模型及其 `core/`、`demo/`、`education/`、`models/` 保持原状。

## 本次清理范围

抽离上述重复机制；第二关主要信号改为具名处理函数；第三关去除预览对主视图的无用依赖；移除首关视图和候选中确认无读取的私有缓存、从未赋值的镜头 tween。未移动或删除旧草稿、截图、生成器、测试和资产。未修改三关规则/状态、现有几何尺寸、光照、相机参数、动画时序、文案或启动配置。

参见 [验收操作](ACCEPTANCE.md) 和 [本次验证记录](../tests/REFACTOR_VERIFICATION.md)。

## 当前首关流程更新

`connection_rules.gd` 定义三件代表、七件自动件及自动分批顺序；`level_state.gd` 区分手动/自动来源、待补齐组、成组撤回和固定龙骨。`level01.gd` 在局部示范关闭后编排自动动画，可取消；主 UI 只显示当前任务和观察入口，选型在 inspector 内。长度模块源文件留存，但当前关卡不加载长度比较，也不接受短/长规格。龙骨内部重叠木块被拆为无体积重叠的木块，实体并集、盲槽和外形尺寸不变，消除顶面深度冲突。详见 [当前验证记录](../tests/LEVEL01_CURRENT_VERIFICATION.md)。


## 分关教学与首关背景

- `shared/chapter_learning.gd`：每关三课介绍、原课堂过滤、恢复来源视图/相机/输入；不拥有装配规则或进度。
- `demo/workshop.gd`：可选 lesson_filter；未设置时仍完整九课。
- `levels/level01/workshop_backdrop.gd`：仅首关背景图片及运行时视觉处理，随来源视图显隐。skeleton_view 负责真实模型边界的镜头适配，不改变几何。
- 各 levelXX.gd：协调教学入口与实际 Tween 完成门控；UI 只显示可操作状态。首关自动队列严格等上一件 finished，取消时清空队列并停 Tween；状态层仍独立验证组顺序、对称与最终连接。


## 本轮长度试装与展示分层

- `length_geometry.gd` 是第一关物理长度/最终位姿/销孔和木销的唯一尺寸源；`length_measure_panel.gd` 只读绘尺。
- 规则 `connection_attached` 与 `connection_correct` 分离：可装不等于稳定；State保存实际选择，自动组继承，最终验证点名长度问题。
- skeleton_view 负责插入、销显隐、松动动画；joint_inspector 复制真实船体到独立观察页并发出选择意图；level01协调门控，不接管几何算法。
- shared/lesson_model_preview 只读原网格，重算法线仅用于显示副本，无Assembly、输入或课堂状态；shared/chapter_learning 管三课入口与原课堂生命周期。
- shipwright_story 是独立可选模态，保存/恢复来源输入，不拥有关卡、相机或模型。来源在 SHIPWRIGHT_STORY_SOURCES.md。
