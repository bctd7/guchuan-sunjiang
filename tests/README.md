# 测试与证据索引

2026-11-09 触屏补齐：第一、二关观察区、候选模型和放大窗支持双指捏合；单指拖装转双指时保留实际浅推位置，全部抬手后才能重新拖装。详见[手势实现与验证](TOUCH_GESTURES_VERIFICATION.md)。

2026-11-09 独立复查补充：`opening_navigation_tests` 覆盖第二关候选滚轮同比例、旋转复位、完整木料放大和返回选材。修复与实际画面见[交互复查](LEVEL02_DIRECT_COMPARISON_VERIFICATION.md)。

最新选材 UI 见 [LEVEL02_DIRECT_COMPARISON_VERIFICATION.md](LEVEL02_DIRECT_COMPARISON_VERIFICATION.md)：实际缺口正面取景、参照与候选共用比例、标线对应真实木料，保留后段已装错件的截面。此前仅精简参数的版本见[历史验证](LEVEL02_KEY_COMPARISON_VERIFICATION.md)。

> 2026-11-08 当前第二关只采用两种装配结果：能继续则保留实际木件和原选项继续；不能继续则完成可达接触动作后自动弹出失败并提供重开。选错本身不触发提前失败，已能装齐的错口保留到试浪。取消“受阻后手动结束”流程。选材 UI 采用第一关式实体卡直接对照：缺口默认朝正面，参照和 A/B/C 共用同一比例，在实际缺口旁标关键尺寸。企口从下边量槽口高度，搭扣比较宽与深，扣合比较宽和居中／偏旁；仍可旋转、放大完整木料。上方参照对应实际试装接头：首处搭扣量取真实座木截面，配套扣合不套用后段标准尺寸；无对应量的接法只提示实际接合形状。三组、四次正常拖动、十件记录保持；第一处错选搭扣/扣合仍完成局部接头后报“拼装错误”。 见[统一结果与尺寸对照验证](LEVEL02_UNIFIED_FIT_VERIFICATION.md)。

历史第二关验证：[互嵌结构、完整视野与统一木材光照](LEVEL02_INTERFIT_VERIFICATION.md)。类型对照取代当前接口的异型硬试配；旧错型失败测试的适用范围已变化。

历史阶段（2026-11-07）：船用两件搭扣、三件分层扣合使用独立几何；受阻后可以抽回、更换或撤回前件，可信松动保留到试浪。最新验收、几何矩阵、实际界面操作与 GPU 证据见[船用接头与可恢复试装](LEVEL02_BOAT_JOINTS_VERIFICATION.md)。以下“所有错型延后判断”和上一轮“受阻即失败、搭扣倾斜”的记录均为历史阶段。

第二关待装木料的真实槽口对位、搭扣/扣合模型辨识及中间帧/放大检查见[对位验证](LEVEL02_ALIGNMENT_VERIFICATION.md)。

第二关木料不透明呈现、法线修正、局部/候选放大及鼠标/模拟触摸验证见[清晰度与缩放记录](LEVEL02_CLARITY_ZOOM_VERIFICATION.md)。

第二关海边船台背景换图后的三尺寸、局部及课堂往返检查见[背景验证](LEVEL02_SEASIDE_BACKGROUND_VERIFICATION.md)。

标准入口、GPU 判错、加载恢复、试浪快照及错误试装接触的本轮结果见[工程整理验证](ARCHITECTURE_REFINEMENT_VERIFICATION.md)。`python3 tests/test_suite_runner.py` 验证 runner 的失败判定；`--group levels --case trial_contact_tests` 可单独运行混合几何组合，`--group visual` 显式执行八项 Mac GPU 夹具。

第二关黄色圆圈已移除，错榫型改为允许试装、整关试浪后判断；当前入口及错误模型/晃动/漏水/重开回归见[入口与错型试装记录](LEVEL02_MARKER_REMOVAL_VERIFICATION.md)。

最新两关总览/局部布局统一、第一关面板恢复、第二关同型实际开口选配与旋转、模型错缝及试浪验证见 [统一观察页记录](INSPECTION_WORKSPACE_VERIFICATION.md)。配套 [并排画面](evidence/inspection-workspace/compare.html) 为本地 Mac GPU 截图，原始报告区分无界面、GPU 和规则/几何检查。

此前 [精简](LEVEL02_SIMPLIFY_VERIFICATION.md)、[辅助面板](AUXILIARY_UI_VERIFICATION.md)、[第二关 UI](LEVEL02_UI_VERIFICATION.md)保留为阶段记录，不代表最新面板或候选逻辑。

保留历史记录及原证据路径，标题含“当前/最终”也只指执行当时。2026-10-31 文档整理阶段未重跑引擎；随后第二关改造已完成针对性自动输入与 Mac GPU 检查，见[第二关改造验证](LEVEL02_REWORK_VERIFICATION.md)。真人与目标设备验收仍未进行。 最新需求见[统一文档](../docs/current/README.md)，每关文件各有待执行验收清单。

| 历史记录 | 范围和边界 |
|---|---|
| [r8 整关失败](WHOLE_LEVEL_FAILURE_R8_VERIFICATION.md) | 第一/二关旧整关失败及重开、导航、既有三关输入，不证明新混合选材完成 |
| [二/三关旧验证](LEVELS23_VERIFICATION.md) | 当时的装配、几何、试舵，不覆盖新的安装角度/倒塌/下水 |
| [材质与嵌入课堂](WOOD_MATERIAL_ENTRY_VERIFICATION.md) | 当时材质、课堂环境与对应自动化 |
| [续检](../docs/archive/2026-10-31-before-rebaseline/docs/RESUME_VALIDATION.md) | 冻结版本首次导入及 26 组回归、Mac GPU/字体/静态科普；本轮未重跑 |
| [第一关旧流程](LEVEL01_CURRENT_VERIFICATION.md)、[UI 旧记录](RESUMED_UI_VERIFICATION.md) | 历史过程，旧计数/恢复机制不能直接照用 |

其他根级验证 Markdown 和 evidence 内 Markdown 均保留为原时点证据；原始 JSON、日志、截图及 `classroom/science/test_results.txt` 不改写为新结论。绝对证据路径仅指原保存位置，不是运行依赖。

入口 `python3 tests/run_suite.py --help`，分组和运行办法见[技术架构](../docs/current/TECHNICAL_ARCHITECTURE.md)。夹具可能写回 `res://tests/`，使用隔离副本。旧夹具失败须核对原因，不能靠删断言或回退产品行为制造通过。自动 Viewport 输入、headless 和 GPU 均不等于真人鼠标、实体触屏或目标机器完整验收。

第二关船壳承托与局部截段：标准 levels/visual 入口包含 `level02_structure_geometry_tests`（实际接触与净空）和 `level02_structure_tests`（完整正确/混合错误、三尺寸、课堂往返、缩放旋转）。见 [验证说明](LEVEL02_HULL_STRUCTURE_VERIFICATION.md)。

最新第一关观察与第二关重复船板合并：`observation_repeat_tests` 纳入 levels/visual。覆盖只读放大旋转/缩放、浅推恢复、三尺寸、整关反馈、七次手动十件记录、错误传播与按排撤回。见[验证](OBSERVATION_REPEAT_VERIFICATION.md)。

<details>
<summary>此前阶段记录（不代表当前规则）</summary>

> 2026-11-08 当前实现：第二关合为企口铺板、搭扣框与隔舱、扣合撑三组，正常流程四次拖动（扣合侧推与下压各一次）。同组采用相同真实缺口规格，原样继承选材，逐件校验路径并播放落座；船板整组按错缝排布，不再逐排选材。拖拽采用与第一关一致的 80–220 逻辑像素行程，增加抖动保护并修正放大中心。第一处错误搭扣/扣合仍在本处完整装入后弹出“拼装错误”。见[三组拼装与拖拽验证](LEVEL02_THREE_GROUPS_VERIFICATION.md)。以下带日期的记录为先前阶段，以本条为准。

> 2026-11-08 最新修正：首排错误榫型保留完整船板，真实落座后允许继续，自动件保持同样错误，装齐后试浪判错。A/B/C 扩大槽深/槽宽/槽位差异并露出槽壁；搭扣从外侧靠近后下落嵌合。真实装入路径被堵死时，接触动画后自动弹出组装失败。详见[可继续错误装配与候选辨识](LEVEL02_CONTINUABLE_JOINT_VERIFICATION.md)，优先于下文较早规则。

> 2026-11-08 用户再次纠正后的当前实现：类型卡恢复直接切换船上的待装件，撤销自动打开结构对照。没有新增场景文字标记；用实际分离位置与精简遮挡区分待装件和接收结构。首排底梁改为固定嵌槽，搭扣横向交叉进入，扣合中件沿自身长度推进；企口船板补充配套一体键。最新交接见[直接试装修正](LEVEL02_DIRECT_FIT_VERIFICATION.md)，优先于以下较早阶段说明。

</details>
