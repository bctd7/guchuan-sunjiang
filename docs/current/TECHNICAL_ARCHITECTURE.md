# 技术架构（当前工作树）

核对日期：2026-10-31。描述 `/Users/bilibili/Documents/GitHub/guchuan-sunjiang` 当前未提交工作树，依据静态源码与已有证据；随后第二关改造已运行针对性回归与 Mac GPU 验证，见[改造记录](../../tests/LEVEL02_REWORK_VERIFICATION.md)。产品目标见[文档索引](README.md)及每关需求；下文“已有”不表示新需求完成。

## 1. 文档结构与维护边界

`docs/current/` 是当前唯一技术/关卡需求入口：本文件维护实际架构，`LEVEL01/02/03_REQUIREMENTS.md` 分别维护关卡目标、交互、差距、验收与待确认。目标规则变更先改对应关卡文档；代码实现后再更新“现状”，不直接把候选建议填成定案。

旧接手、设计、迭代和验证说明移入 `docs/archive/2026-10-31-before-rebaseline/`；历史测试 Markdown 保留原位并标记，以保护证据引用。`models/joinery/`、`classroom/science/` 和故事来源仍属专门技术/内容资料，不覆盖关卡需求。归档路径映射和检查点见[清理清单](../archive/2026-10-31-before-rebaseline/README.md)。

## 2. 引擎与运行入口

| 项目 | 当前实际配置 |
|---|---|
| 引擎 | 历史运行环境为 Godot 4.7.2 标准版；工程声明 4.7，无 .NET 工程 |
| 主入口 | [project.godot](../../project.godot) → `res://campaign/campaign.tscn` |
| 渲染 | `gl_compatibility`，MSAA 3D=2 |
| 逻辑窗口 | 1440×900，`canvas_items` 拉伸；不代表全部小屏布局已适配 |
| 默认字体 | `res://shared/fonts/default_font.tres`，内置字体和 OFL 许可保留 |
| 独立课堂 | `res://classroom/classroom.tscn`，原九种教材可独立使用 |

运行场景无需 Blender；重新生成部分网格才需要 Godot CSG、Python/NumPy/SciPy 或 Blender，具体看[教材模型说明](../../models/joinery/README.md)。资源 `.uid` 与 `.import` 设置随资产保留，`.godot/` 为本机导入缓存。

## 3. 目录与职责

| 目录/模块 | 职责 | 边界 |
|---|---|---|
| `campaign/` | 关卡目录、实例缓存、完成徽标、导航 | 不判断具体榫卯是否正确 |
| `levels/level01/` | 龙骨规则、示范/补齐状态、选材观察、骨架视图、故事 | 当前有长度与整关检测；不等于新混合选材已实现 |
| `levels/level02/` | 铺板顺序、榫型/排布、端缝校验、船壳和隔舱视图 | 独立拖动、实时展开图、试浪和隔舱小课堂；没有真实流体求解 |
| `levels/level03/` | 工作台依赖、候选、装配与试舵 | 安装角度/受力选择尚未实现 |
| `levels/shared/` | 教学接入、共用失败面板和指针交互辅助 | 关卡状态各自独立 |
| `models/ship/keel,hull,rigging` | 三关船用实体/展示几何及烘焙资产 | 与课堂教材网格分开 |
| `models/joinery/` | catalog、九类教材/21 个木件网格、预览、定义、生成与检查 | 教学选型，不代表古船原位复原 |
| `classroom/` | 课堂协调、介绍与文案、显示、界面、受力科普 | 不直接持有各关建船进度 |
| `core/` | 教材 Assembly、交互、路径、碰撞、指针与相机 | 教材装配与船关装配状态独立 |
| `shared/` | 来源呈现恢复、中文字体、共享主题/界面 | 不提供统一造船状态 |
| `tests/` | 规则、几何、输入、生命周期与视觉夹具及历史证据 | 夹具可能写 `res://`，使用隔离副本 |

## 4. 调用和状态流

```text
project.godot → campaign/campaign.tscn → campaign.gd
    → level01 / level02 / level03 协调器
        → 本关 State → 本关 Rules
        → 本关 UI / 输入 / View → models/ship
        → levels/shared/teaching_portal
            → shared/source_presentation（保存/恢复来源呈现与输入）
            → classroom/introduction + content
            → classroom/classroom
                → core/interaction + core/assembly
                → models/joinery/catalog.json
                → display / ui / science
```

这是调用与职责示意，不表示所有箭头是相同的信号或继承关系。通常输入由关卡协调器调用 State/Rules，再由 UI 和 View 表现；逻辑接受一次放置早于动画最终落位，协调器还需等待 Tween 完成才允许后续或验收，不能只用逻辑件数替代落位完成。

`campaign.gd` 首次实例化关卡并连接 `progress_changed`、`return_requested`；离开调用 `leave()` 并移出场景树，重进挂回同实例并调用 `enter()`。通过 `is_completed()` 更新徽标和下一关，通过 `navigation_status()` 决定模态界面期间的外层导航。退出时释放未挂树的缓存实例。

当前三个关卡平行开放，每关状态互不代替；目录往返保留本次运行实例，重开只重置本关。没有磁盘存档或云同步。重进会经过本关介绍入口，再恢复保留进度。

## 5. 三关实际状态与规则

| 关卡 | 状态/流程 | 当前完成和失败 |
|---|---|---|
| 1 | 固定龙骨；三次手动示范，七件同类补齐；显式榫型/长度选择、组历史及自动件来源 | r8 允许错型/错长试装，整关装齐且末动画结束后自动验收；错误锁定，重开或回目录；非最新规则定案 |
| 2 | 顺序十件；观察后选榫与 A/B，实际木材拖动及深度阈值松手安装；同层排布一致；实时展开图 | 全部落位后先试浪再 validate；对齐端缝显示移动水滴，失败重开或回目录；重开取消旧动效/回调 |
| 3 | 三工作台、八件依赖；每步选择候选，错误类型拒装；舵叶装好后记录左右试舵 | 两向达到当前 ±30° 才完成；没有错误装好后的倾倒状态或下水展示 |

第一/二关共用 `levels/shared/assembly_failure.gd` 面板。失败后导航往返保留失败状态；第一关重开取消旧插入/补齐/晃动回调，避免污染新轮。第三关仍是不同的拒装/试舵机制，不能把共享面板存在推断成三关规则已统一。

第三关规则当前粽角用于桅座、夹头用于帆桁，与书面指定相反；[第三关需求](LEVEL03_REQUIREMENTS.md)将其列为待确认差异。既有试舵范围只代表运动参数，不是安装卡牢角度。

## 6. 教学、几何与受力展示

`levels/shared/teaching_portal.gd` 管理本关三课及返回位置；`shared/source_presentation.gd` 保存来源显隐、输入开关与相机，课堂往返恢复。介绍布局位于 `classroom/introduction/`，文案位于 `classroom/content/`。课堂公开 `open_joint(id)`、模态状态与相机接口；独立 Assembly 不修改船体进度。

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

既有[续检记录](../archive/2026-10-31-before-rebaseline/docs/RESUME_VALIDATION.md)报告冻结版本首次导入及 26 组回归通过，并包含 Mac GPU/字体证据；这是历史记录，本轮未重跑。[测试索引](../../tests/README.md)列明范围。自动 Viewport 鼠标/触摸事件、headless、GPU 截图和真人输入分别记录，不能互相替代。

## 8. 跨平台、交付和未完成边界

已有 Mac 自动化及后台 GPU 记录；Windows 只有相关静态核对，不能据此宣布 Windows 实机、导出包或像素一致性通过。实体触屏、目标机器、完整新玩法人工验收、签名/公证/安装包均未因文档整理完成。内置字体覆盖当前受测字形，不代表所有未来字符不依赖回退。

当前有大量既有未提交的迁移、删除/新路径与资产，不能清理为“无用未跟踪文件”，不以 `git clean`、`reset --hard` 或远端版本覆盖。当前提交记录不包含全部工作树，重新克隆不能自动恢复这些修改。检查点及文件校验记录见[归档清单](../archive/2026-10-31-before-rebaseline/README.md)。

后续混合候选池、逐关难度、第三关角度/受力及下水属于待实施产品目标；本文件不凭空设计新服务、通用框架或新增平台依赖。

## 第二关本次新增模块

`hull_drag_interaction.gd` 只翻译真实 Viewport 鼠标/触摸手势；`level_state.can_attempt()` 只读检查，接受释放后才由协调器提交。`hull_view.gd` 管理未接受的预览深度与剩余吸附动画；其他关继续使用原输入层。`drag_guide.gd` 只画箭头，不占用输入。

`seam_diagram.gd` 从实际 state/layouts 与当前选择绘图，不读静态答案图片。`sea_trial.gd` 的独立容器管理海浪、裂缝与水滴；协调器保持 busy、等待 Tween 完成再判定，代次令牌隔离取消后的旧回调。`hull_backdrop.gd` 管理本关 SVG 背景；`bulkhead_lesson.gd`、`bulkhead_diagram.gd` 管理独立科普及输入/焦点恢复。均不修改 core 或原课堂。
