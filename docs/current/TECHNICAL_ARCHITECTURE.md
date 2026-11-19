# 技术架构（当前工作树）

2026-11-18 更新：三关主页面外壳、故事页面与生命周期、榫型候选卡及背景绘制已共用；第三关观察页接入现有公共观察区、缩放、放大和输入。第三关故事使用明确标注的 mock 内容。仍存在专用尺寸面板、操舵区域组合及关卡适配脚本，详见 [三关组件核对](CHAPTER_COMPONENT_AUDIT.md) 和 [实际验证](../../tests/SHARED_CHAPTER_UI_VERIFICATION.md)。以下旧日期段落中的“第三关未接入”“故事/背景独立实现”由本条更新。

> 2026-11-08 当前第二关只采用两种装配结果：能继续则保留实际木件和原选项继续；不能继续则完成可达接触动作后自动弹出失败并提供重开。选错本身不触发提前失败，已能装齐的错口保留到试浪。取消“受阻后手动结束”流程。选材 UI 采用第一关式实体卡直接对照：缺口默认朝正面，参照和 A/B/C 共用同一比例，在实际缺口旁标关键尺寸。企口从下边量槽口高度，搭扣比较宽与深，扣合比较宽和居中／偏旁；仍可旋转、放大完整木料。上方参照对应实际试装接头：首处搭扣量取真实座木截面，配套扣合不套用后段标准尺寸；无对应量的接法只提示实际接合形状。三组、四次正常拖动、十件记录保持；第一处错选搭扣/扣合仍完成局部接头后报“拼装错误”。 见[统一结果与尺寸对照验证](../../tests/LEVEL02_UNIFIED_FIT_VERIFICATION.md)。 最新选材显示见[正面缺口与同尺度参照](../../tests/LEVEL02_DIRECT_COMPARISON_VERIFICATION.md)。

核对日期：2026-11-01。描述 `/Users/bilibili/Documents/GitHub/guchuan-sunjiang` 当前未提交工作树，依据静态源码与已有证据；随后第二关改造已运行针对性回归与 Mac GPU 验证，见[统一观察页记录](../../tests/INSPECTION_WORKSPACE_VERIFICATION.md)。产品目标见[文档索引](README.md)及每关需求；下文“已有”不表示新需求完成。

## 1. 文档结构与维护边界

`docs/current/` 是当前唯一技术/关卡需求入口：本文件维护实际架构，`LEVEL01/02/03_REQUIREMENTS.md` 分别维护关卡目标、交互、差距、验收与待确认。目标规则变更先改对应关卡文档；代码实现后再更新“现状”，不直接把候选建议填成定案。

旧接手、设计、迭代和验证说明移入 `docs/archive/2026-10-31-before-rebaseline/`；历史测试 Markdown 保留原位并标记，以保护证据引用。`models/joinery/`、`classroom/science/` 和故事来源仍属专门技术/内容资料，不覆盖关卡需求。归档路径映射和检查点见[清理清单](../archive/2026-10-31-before-rebaseline/README.md)。

## 2. 引擎与运行入口

| 项目 | 当前实际配置 |
|---|---|
| 引擎 | 历史运行环境为 Godot 4.7.2 标准版；工程声明 4.7，无 .NET 工程 |
| 主入口 | [project.godot](../../project.godot) → `res://app/startup/startup.tscn` 循环播放欢迎片 → 点击「开始体验」 → `res://app/campaign/campaign.tscn` |
| 渲染 | `gl_compatibility`，MSAA 3D=2 |
| 逻辑窗口 | 1920×1080，默认全屏，`canvas_items` + `keep`；船坊沿用 1440×900 内部坐标等比居中，不横向拉伸；见 [展览部署](EXHIBITION_DEPLOYMENT.md) |
| 默认字体 | `res://assets/fonts/default_font.tres`，内置字体和 OFL 许可保留 |
| 独立课堂 | `res://components/teaching/classroom/classroom.tscn`，原九种教材可独立使用 |

运行场景无需 Blender；重新生成部分网格才需要 Godot CSG、Python/NumPy/SciPy 或 Blender，具体看[教材模型说明](../../models/joinery/README.md)。资源 `.uid` 与 `.import` 设置随资产保留，`.godot/` 为本机导入缓存。

## 3. 目录与职责

| 目录 | 职责 |
|---|---|
| `app/` | 欢迎片、空闲回退、章节目录与导航 |
| `levels/` | 统一关卡接口，以及各关自己的规则、进度、装配和场景 |
| `models/` | 教材和船用几何、材质、尺寸、碰撞与资源复用 |
| `components/` | UI、候选预览、手势、放大及教学 |
| `audio/` | 音频播放、音量设置、音乐与音效 |
| `assets/` | 图片、字体、欢迎视频 |
| `tests/`、`docs/` | 自动回归与设计记录 |

## 4. 运行流程

```text
project.godot → 欢迎片 → 章节目录 → 当前关卡的介绍
                                      ↓ 开始本关
                            关卡状态 / 规则 → 船体、输入、UI
                                      ↓ 观察 / 放大
                               共用组件 → 共享模型资源
```

目录监听 `ShipChapter` 的 `completion_changed` 和 `navigation_changed`，同时持有一个关卡节点。加载失败时保留当前场景。成功切换或返回目录时释放旧节点。教学介绍先创建教学内容，开始搭建后才建立船体，第一次观察才创建选材预览。放大与结果视口随弹窗创建和释放。教学往返恢复来源页面、相机和浅推状态。

候选预览在模型、相机或尺寸变化时刷新一帧，动画期间连续渲染，隐藏时停止。第二关尺寸图监听预览比例、尺寸和数据变化。船用模型资源通过限量的 PackedScene 缓存复用；每次实例化拥有独立节点、位置和交互状态。历史章节从下一节起按实施日期记录。

空闲回退由 `app/exhibition.gd` 的单次计时器管理，窗口输入只记录最近活动。欢迎片和目录内的介绍重播会暂停计时。进入目录或关闭介绍后重新开始计时。

## 5. 三关实际状态与规则

| 关卡 | 状态/流程 | 当前完成和失败 |
|---|---|---|
| 1 | 固定龙骨；三次手动示范，七件同类补齐；显式榫型/长度选择、组历史及自动件来源 | r8 允许错型/错长试装，整关装齐且末动画结束后自动验收；错误锁定，重开或回目录；非最新规则定案 |
| 2 | 顺序十件/三组、正常四次拖动；选榫、选同型开口；原选材自动补齐、固定错缝、深度阈值松手安装；模型接缝标记 | 全部落位后先试浪再 validate；对齐端缝及错误开口对应位置显示移动水滴，失败重开或回目录；重开取消旧动效/回调 |
| 3 | 三工作台、八件依赖；每步选择候选，错误类型拒装；舵叶装好后记录左右试舵 | 两向达到当前 ±30° 才完成；没有错误装好后的倾倒状态或下水展示 |

第一、二关的失败面板与三关的成功面板使用 `components/ui/chapter_result.gd`。返回目录结束本轮，重新进入时开始新一轮。第一关重开取消旧插入、补齐和晃动回调。第三关通过拒装和试舵处理装配结果。

第三关规则当前粽角用于桅座、夹头用于帆桁，与书面指定相反；[第三关需求](LEVEL03_REQUIREMENTS.md)将其列为待确认差异。既有试舵范围只代表运动参数，不是安装卡牢角度。

## 6. 教学、几何与受力展示

`components/teaching/teaching_portal.gd` 管理本关三课和返回位置。同目录下的 `source_presentation.gd` 保存来源显隐、输入开关与相机。介绍布局和文案位于 `components/teaching/classroom/` 的 `introduction/` 与 `content/`。课堂公开 `open_joint(id)`、模态状态与相机接口。独立 Assembly 管理课堂装配进度。

教材原网格与碰撞属于 core/Assembly；课堂 display 管理显示副本与材质。第一关观察器的副本/透明/接触定位辅助位于 `levels/level01/inspector/inspection_geometry.gd`。`candidate_geometry` 仍依赖来源 View 的原件保护，当前不是完全独立的几何层；兼容字段仍保留供测试读取。

正式受力入口是燕尾专用 `classroom/science/dynamic/` 与其余八种 `force_gallery/`，均为定性矢量示意动画；`classroom/science/demo.tscn` 为独立静态接触审核工具，没有正式课堂入口。不能把审核工具、示意箭头或碰撞采样说成实时工程力学/水密计算。故事资料见[来源说明](../SHIPWRIGHT_STORY_SOURCES.md)，情景人物与史实分开标识。

## 7. 打开工程与验证

在 Mac 用 Godot Project Manager 导入工程，完成导入后 F5。终端示例：

```sh
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --version
"$GODOT_BIN" --path /你的路径/guchuan-sunjiang
python3 tests/run_suite.py --help
```

测试请在独立副本执行，避免报告写回正在开发的工程：

```sh
python3 tests/run_suite.py --project /你的路径/隔离副本 --group all --output /你的路径/测试输出
```

runner 默认执行 import，并支持 `core / levels / classroom / campaign / all`；`all` 排除 `visual`，视觉需显式启用。`--godot` 可指定二进制；`--user-data-name` 仅用于临时副本，会新建 `override.cfg` 且拒绝覆盖既有文件。macOS 原生 user data 不保证采用 XDG 重定向，不修改 HOME 或正式存档。输入套件含墙钟防重计时，不能以 `--fixed-fps` 加速整个引擎替代实时验证。

既有[续检记录](../archive/2026-10-31-before-rebaseline/docs/RESUME_VALIDATION.md)报告冻结版本首次导入及 26 组回归通过，并包含 Mac GPU/字体证据；这是历史记录，不能代替后续共享观察页的针对性回归。[测试索引](../../tests/README.md)列明范围。自动 Viewport 鼠标/触摸事件、headless、GPU 截图和真人输入分别记录，不能互相替代。

## 8. 跨平台、交付和未完成边界

已有 Mac 自动化及后台 GPU 记录；Windows 只有相关静态核对，不能据此宣布 Windows 实机、导出包或像素一致性通过。实体触屏、目标机器、完整新玩法人工验收、签名/公证/安装包均未因文档整理完成。内置字体覆盖当前受测字形，不代表所有未来字符不依赖回退。

本地 `10679f3` 已保存此前迁移与资产；随后任务页、共享观察页及相关验证仍有未提交改动，重新克隆不能自动恢复这些修改。不要以 `git clean`、`reset --hard` 或远端版本覆盖工作树。检查点及文件校验记录见[归档清单](../archive/2026-10-31-before-rebaseline/README.md)。

后续混合候选池、逐关难度、第三关角度/受力及下水属于待实施产品目标；本文件不凭空设计新服务、通用框架或新增平台依赖。

## 9. 第一、二关共享观察页与输入边界（2026-11-01）

`levels/shared/inspection_workspace.gd` 只建立两关相同的页框、顶栏、候选区、独立观察区、右侧选材和底栏，不判断关卡规则。`inspection_orbit.gd` 只改变相机；第一关同名文件为兼容入口，原第一关限角保持。`selectable_orbit.gd` 在共享相机上增加点选意图，拖动超过阈值只旋转，同一模型内的双指捏合缩放，失焦取消；`rotatable_preview.gd` 每卡持独立 World3D、相机和灯光，隐藏时暂停渲染、轨道输入与逐帧处理，并清除未结束手势；显示后保留观察角度。没有复制第一关状态机或试装逻辑到第二关。

第一关 `joint_inspector.gd` 继续负责原类型/长度候选与几何辅助，仅用共享外壳替代原 UI 构造。总览新增辅助卡按用户要求撤去，故事及补齐说明回到原任务卡，保留缩放与目录入口。原规则、自动件来源记录、长短干扰不变。

第二关 `level_ui.gd` 只发选榫/选开口/排布/继续/返回意图；`level_state.gd` 保存十件真实记录及当前选择；`connection_rules.gd` 声明十件顺序、三组展示和重复件来源，`opening_rules.gd` 定义同型开口的目标/偏移。分组不产生另一份进度，撤回代表件时一同取回其自动件。

第二关总览仅任务卡观察按钮请求进入局部，黄色圆圈/锚点及相应船体点击拾取已移除。局部由协调器把**同一** `hull_view` 挂到独立 SubViewport；回总览/试浪前挂回关卡并恢复相机。`view.inspected` 为模式来源，不复制装配状态。View 负责关卡模式和可见构件集合，`inspection_camera.gd` 接收相机、轨道和显示区域，集中完成宿主/子视口坐标转换、投影与可见范围拟合；旋转后重新拟合；仅鼠标滚轮显式缩放。拖动层区分抓住实际三角面与空白观察区，前者独占推入、后者旋转，不让按钮或镜头手势安装木料。浅推与释放令牌沿用原实现；`drag_guide.gd` 不占输入，并逐帧跟随镜头重投影。

局部、进度弹层期间隐藏外层目录，教学按 `source_presentation` 保存显隐、相机、输入。来源 panel 隐藏时暂停局部渲染与观察轨道，课堂返回恢复原局部及选择。页面/卡片和信号首次建立后复用，不按往返重复创建；自由节点和子视口随关卡释放。目录缓存离树的尺寸信号回调先检查 `is_inside_tree()`，重入再刷新。

## 10. 第二关实际几何、错缝与试浪

`ship_geometry.gd` 提供船板和教学示例；`models/ship/hull/boat_joints.gd` 独立生成船上搭扣、三件扣合和隔舱板底口。A/B/C 保持等外尺寸，差异为真实槽宽、槽深或通道位置。搭扣槽口相向，中撑的三种下口都能接下件，但错误上口阻挡顶件。三件最终中心共用 `THREE_CENTER`，角度为 60°/0°/−60°。中件沿 X 侧推 1.3 单位，0.18 宽的颈部穿过 0.184 宽导槽，上挡肩限制垂直进出，顶件落位后阻止中件水平退出。教学示例不跟随船用尺寸变化。实体交叠、实际插入扫掠和外包尺寸有独立回归，不宣称完整制造公差或力学验收。

第二关选择、观察、旋转、浅推不判错。正式松手经 `assembly_policy` 与协调器 `_physical_decision()` 检查，只有 continue/blocked 两种结果。能继续的错误保持原选材、原网格与实际接触姿态；不能继续的木件完成可达接触动画后由 `fail_installation()` 自动进入终局失败。已删除 `jammed`、抽回受阻件及手动结束试装的分支。扣合顶件用实际接触位置检查能否闭合，不再仅以中件答案是否正确决定；第一处错误接头在局部完整装完后终止，能装齐的其他错口留到试浪。失败刷新先清理预览状态，避免木件跳回待装位置。试浪仍区分船壳漏水、内部松动和混合原因。

端缝排布与开口选配相互独立。本列/已装下列实物同时可见；`model_seam_guides.gd` 只标记实际板端，随选位、推装和 Tween 落位更新，不发正确/错误结论。旧独立 `seam_diagram.gd` 已删除。局部看槽口只淡化接收件，移动木料保持实色；返回总览恢复。

普通接合可查看，点击继续才准备同组下一件，不自动安装。同列保留榫型/开口/端缝，新的扣合撑保留榫型但须重新选开口。`hull_view.gd` 把诊断结果、模型姿态及接合点转成 `trial_presentation.gd` 快照；`sea_trial.gd` 仅消费该快照，独立管理海浪、裂缝、水滴和松动，不访问 View/State/Rules。快照复制数组及木料姿态，但持有场景节点引用；取消/结束恢复原试装姿态并清理引用；先接近/冲击/漏水，再 `validate()`。协调器 busy 与代次令牌隔离取消后的旧回调，重开清理动效。`hull_backdrop.gd` 管滩头背景，`bulkhead_lesson.gd`/`bulkhead_diagram.gd` 管科普及焦点恢复，不修改 core/原课堂。

最新测试、实际截图、源文件校验与未测范围见[统一观察页验证](../../tests/INSPECTION_WORKSPACE_VERIFICATION.md)。此前 [UI](../../tests/LEVEL02_UI_VERIFICATION.md)、[辅助卡](../../tests/AUXILIARY_UI_VERIFICATION.md)、[精简](../../tests/LEVEL02_SIMPLIFY_VERIFICATION.md)仅描述各自阶段，不再代表当前面板和选材方式。

第二关总览圆圈移除及错型延后判断后的入口、返回与回归见[后续记录](../../tests/LEVEL02_MARKER_REMOVAL_VERIFICATION.md)；第一关原圆圈和点击目标保持，未修改共享输入协议或其玩法。

## 11. 工程整理与错误试装接触（2026-11-01）

第二关 `trial_contact.gd` 从外侧沿实际入口方向寻找首个阻挡面；`contact_cells.gd` 将沿 Y 挤出的凹多边形按底面三角形拆成实体棱柱，保留空腔。碰撞容差与停靠间隙分开。搭扣保持对口方向，浅槽停在下槽底、宽槽落座后沿余隙横向滑动；旧倾斜处理已移除。手动件和自动件通过同一入口检查插入路径，后件无法接合时在接触动画后自动失败。没有刚体物理或动态强度计算，几何采样只针对固定尺寸的教学模型。最新证据见[船用接头验证](../../tests/LEVEL02_BOAT_JOINTS_VERIFICATION.md)。

`level_state.gd.connection_seated()` 是配套状态只读查询，不能替代几何接触检查。只有实际铺成的板列显示端缝诊断。错误构件的冲击位移沿可退出方向；宽槽搭扣只沿其实际侧隙滑动，结束或取消恢复试装姿态。

第一关背景及第二关科普共用的原图移到 `shared/assets/shipyard_background.png`，像素与 UID 保留；第一关背景组件仍属于第一关，不抽象无关场景。已删除无调用的 `workshop_auxiliary.gd`，第二关废弃修复接口及旧候选动画字段；隐藏的验收按钮仍由输入门禁夹具使用，未删。三关状态、课堂/core 装配和船用模型边界不变。

标准测试入口补齐观察器/旋转/故事/加载恢复及试浪/接触夹具；`--case` 可在分组内选单个注册脚本。`visual` 十项均校验新报告、GPU 渲染和无焦点状态，macOS 通过后台独立 Godot 实例运行；超时只终止本次唯一项目和日志匹配的进程。日志中的脚本及资源错误即使进程返回 0 也失败，仅明确识别的系统证书读取警告单独记录。结果及限制见[本轮验证](../../tests/ARCHITECTURE_REFINEMENT_VERIFICATION.md)。

第二关 `hull_backdrop.gd` 现加载独立生成的 `levels/level02/assets/seaside_shipyard.png` 与局部 `seaside_background.gdshader`，处理参数匹配第一关；总览/局部/课堂可见性生命周期保持不变。第一关背景组件及旧第二关 SVG 不改，具体生成和 GPU 证据见[背景验证](../../tests/LEVEL02_SEASIDE_BACKGROUND_VERIFICATION.md)。

第二关显示使用 `wood_appearance.gd` 复用已有 `workshop_look` 配方；船用挤出几何只修正面绕序/光照法线，顶点与实体不变。缩放由 UI/指针意图经协调器进入 `inspection_camera`，抓木料期间拒绝改变投影；`model_magnifier.gd` 只持显示副本和相机，关闭恢复原选择/浅推，不依赖 State 或 Rules。主视图缩放上限 400%，标注大小补偿。旧同排自动半透明改为常态实木，手动接收件透视保留。回归和限制见[清晰度验证](../../tests/LEVEL02_CLARITY_ZOOM_VERIFICATION.md)。

第二关对位 helper 不依赖镜头/State，不改变几何或规则映射。类型预览仅拆开展示三件扣合木料，不替换船体接合模型。中间帧检查及当前工程映射来源边界见[对位验证](../../tests/LEVEL02_ALIGNMENT_VERIFICATION.md)。

只读类型大图的 `joint_demonstration.gd` 读取模型 metadata 展示部件、槽口及合拢顺序，仅持副本与 Tween。它不依赖关卡 State/Rules，关闭或模式切换取消动效；`rotatable_preview` 的 frame API 只调整显示镜头。安装位置与游戏装配流程不变。

### 第二关内构件与船壳承托（2026-11-01）

`models/ship/hull/support_geometry.gd` 生成贴近船壳的肋框、横梁和纵向承托，仅依赖本目录的静态几何，不引用关卡。搭扣、扣合接收件落在此框架上，替代独立细支腿；企口位置、正确安装坐标及状态/规则不变。`levels/level02/inspection_context.gd` 从实际已装网格裁出局部截段，近侧上板剖开以看清连接，错误件仍用实际错误几何。显示副本不进入 State 或 TrialContact 的障碍列表，选材和撤回清理重建，返回总览隐藏。局部隐藏全船接缝/水面/艌密层，保留专用于铺板的贴模端缝标记。框架和木件沿用同一木材外观。资料边界、安装映射及测试见[船壳承托记录](../../tests/LEVEL02_HULL_STRUCTURE_VERIFICATION.md)。

### 第一关观察复用与第二关重复安装（2026-11-01）

两关共用 `levels/shared/inspection_zoom_bar.gd`，第一关候选接入共享旋转输入及只读放大组件。局部状态不宣布成败，整关状态机保持判定职责。第二关 Rules 声明三排重复板，State 显式记录 `automatic`/`demonstrated_by` 并按操作撤回，Coordinator 串接代表件和重复件真实动画；View 不自动生成业务完成状态。当前为十件实体、四次手动、三组展示；早期七次/六组的记录仅描述当时版本。见[验证](../../tests/OBSERVATION_REPEAT_VERIFICATION.md)。

<details>
<summary>此前阶段记录（不代表当前规则）</summary>

> 2026-11-08 当前实现：第二关合为企口铺板、搭扣框与隔舱、扣合撑三组，正常流程四次拖动（扣合侧推与下压各一次）。同组采用相同真实缺口规格，原样继承选材，逐件校验路径并播放落座；船板整组按错缝排布，不再逐排选材。拖拽采用与第一关一致的 80–220 逻辑像素行程，增加抖动保护并修正放大中心。第一处错误搭扣/扣合仍在本处完整装入后弹出“拼装错误”。见[三组拼装与拖拽验证](../../tests/LEVEL02_THREE_GROUPS_VERIFICATION.md)。以下带日期的记录为先前阶段，以本条为准。

> 2026-11-08 最新修正：首排错误榫型保留完整船板，真实落座后允许继续，自动件保持同样错误，装齐后试浪判错。A/B/C 扩大槽深/槽宽/槽位差异并露出槽壁；搭扣从外侧靠近后下落嵌合。真实装入路径被堵死时，接触动画后自动弹出组装失败。详见[可继续错误装配与候选辨识](../../tests/LEVEL02_CONTINUABLE_JOINT_VERIFICATION.md)，优先于下文较早规则。

> 2026-11-08 用户再次纠正后的当前实现：类型卡恢复直接切换船上的待装件，撤销自动打开结构对照。没有新增场景文字标记；用实际分离位置与精简遮挡区分待装件和接收结构。首排底梁改为固定嵌槽，搭扣横向交叉进入，扣合中件沿自身长度推进；企口船板补充配套一体键。最新交接见[直接试装修正](../../tests/LEVEL02_DIRECT_FIT_VERIFICATION.md)，优先于以下较早阶段说明。

> 2026-11-08 当前实现优先说明：不适用于当前固定接口的类型卡打开完整配对的结构对照，不再换出单根异型件硬推向接收件。实际选材错误由同型 A/B/C 槽宽、槽深、通道差异与端缝提供；接收端不变形。默认显示完整待装件及相邻船架，“看槽口”进入细节且返回原视野。第二关共用固定灯光，主要接合木料共用整根坐标的连续纹理，剖切保留材质、硬边法线与纹理相位。旧即时失败、灰色接收件、相机补光与极局部取景说明均为阶段历史。详见[当前交接](../../tests/LEVEL02_INTERFIT_VERIFICATION.md)。

</details>

## 第二关尺寸呈现（2026-11-08）

2026-11-09 补充：`opening_gallery.gd` 同步候选缩放，参照读取实际 `camera.size`；原重置信号同时复位三张候选。`model_magnifier.gd` 对显式声明 `magnifier_whole_model` 的第二关开口候选重新包围完整模型，其他来源保持原取景。参照图与候选标线均限制在模型区域内。

木件构造器写入 `mating_dimensions`/`receiving_dimensions`；`ship_geometry.dimensions()` 遍历读取，重建时清除旧元数据。`opening_reference.gd` 同时识别当前部位和 `opening_geometry_id()`：标准接法读取实际接收件及后续顶件；首处搭扣对固定座木的实际三角面切片，读取跨接宽度和相邻未开槽处的高度差；首处配套扣合显示两件关系，不把后段 28 格顶件作为参照。其他异型接法省去无可比性的标尺，保留当前接合形状说明。`opening_gallery.gd` 保留第一关 72 高实体卡，默认正对缺口；`opening_measure_panel.gd` 共用候选默认相机的投影比例和测量基准，`opening_measure_marks.gd` 把尺寸线投影到实际缺口旁。企口缩略图正视时用远裁面去除定位键遮挡，旋转和放大恢复完整木料，换接法先重置远裁面。后段顶撑通过 `opening_section.gd` 读取已装两件的凸体截面，保留错误前件而非替换为标准模板。`opening_dimensions.gd` 只格式化关键量；所有候选最多两行，尺寸栏取统一最大宽度，避免改变单张相机尺度。显示不改几何、状态、输入或判错。见[验证](../../tests/LEVEL02_DIRECT_COMPARISON_VERIFICATION.md)。


## 触屏手势补齐（2026-11-09）

第一、二关的观察区、类型/尺寸候选及共享放大窗复用 `levels/shared/touch_pinch.gd`。原始 ScreenTouch/ScreenDrag 记录接触点，GUI 实际收到的按下事件才认领当前区域；两根手指须在同一区域起手才能缩放，跨卡片不选材也不缩放。第三指或任意一指抬起后暂停本轮手势，所有手指抬起后才接受新单指操作。各区域继续使用已有缩放范围，第二关尺寸卡同步缩放保持 A/B/C 与参照同一比例。

单指仍按起点区分拖木料与转视角。加入第二指时停止待提交动作并保留实际浅推位置；重新抓取后继续。失焦、窗口尺寸改变和显式取消清理旧坐标系的手势。打开放大窗前仅暂停手势并清空接触点，不恢复浅推木料；关闭后不会残留漏接的抬手事件。鼠标与触摸模拟鼠标重复事件保持互斥，触摸抖动阈值为 10 个逻辑像素。

此轮范围是第一、二关的以上区域，第三关及旧独立课堂没有统一接入双指。文字仍随设计画布等比缩放，未新增小屏重排或最小字号策略。目标机器已知为 Windows，物理分辨率、系统 DPI 和多点能力未确认；自动输入和 Mac GPU 通过不代表 Windows 触屏已实测。见[测试与实机检查边界](../../tests/TOUCH_GESTURES_VERIFICATION.md)。

## 公共步骤引导

`levels/shared/step_guide.gd` 为独立呈现组件，三关依据已有选材、装配、busy、完成状态提供文字和目标。无独立推进状态；边框忽略输入，辅助按钮保留布局占位并同步禁用指针与焦点。状态映射及验证边界见 [步骤引导验证](../../tests/STEP_GUIDE_VERIFICATION.md)。

启动视频和欢迎页实现、转码及验收边界见 [启动视频](STARTUP_VIDEO.md)。

## 统一结果页（2026-11-18）

`components/ui/chapter_result.gd` 呈现三关成功与前两关失败结果。打开结果页时创建视口并复制可见木件，失败原因来自关卡判定。第一、二关通过 `next_requested` 进入下一关，第三关返回目录。结果显示期间章节导航隐藏。验证范围及截图见 [结果页验证](../../tests/RESULT_PAGES_VERIFICATION.md)。
