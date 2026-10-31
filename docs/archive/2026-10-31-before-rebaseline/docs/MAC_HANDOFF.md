> 历史归档（2026-10-31 整理）。原路径：`docs/MAC_HANDOFF.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# Mac 接手指南 · 2026-10-31

> 当前整关验收 r8 已覆盖 r7 的单件立即失败流程：第一、二关装齐且实际动画结束后才统一判定；失败弹窗支持重开及回到目录。第三关保留错误候选拒绝入槽和试舵通关。当前行为与验证见 [r8](WHOLE_LEVEL_FAILURE_R8.md)。以下为迁移和早期实现的历史记录。

私有仓库：[bctd7/guchuan-sunjiang](https://github.com/bctd7/guchuan-sunjiang)。Mac 登录具有访问权限的同一 GitHub 账号后：

```sh
git clone https://github.com/bctd7/guchuan-sunjiang.git
cd guchuan-sunjiang
```

克隆后按下文安装 Godot、导入 `project.godot`。源码和资产都在 Git 中，无需额外素材包或 LFS 拉取。

这是桌面正式工程的迁移基线，包含截至 2026-10-28 r6 的现有代码和用户修改。迁移只整理文档与版本管理，不改变玩法。请先读本文，再读旧验收记录；旧文档有互相覆盖的历史规则，不能全部当成当前行为。

## 在 Mac 上打开

1. 安装 Git 和 **Godot 4.7.2 标准版**，不需要 .NET。官方版本归档：<https://godotengine.org/download/archive/4.7.2-stable/>。Windows 当前引擎文件版本为 `4.7.2.stable.official`，工程声明 `4.7`，渲染器为 Compatibility / `gl_compatibility`。
2. 登录有权访问此私有仓库的 GitHub 账号，用仓库页面的 HTTPS 或 SSH 地址 `git clone`。使用正常的 GitHub 登录/SSH 认证，不要把 token 写进工程、远程 URL 或文档。
3. Godot Project Manager 选择“导入”，选中克隆目录里的 `project.godot`。等待首次资源导入完成，再按 F5（部分 Mac 键盘需要 Fn+F5），或点右上“运行项目”。主场景为 `res://campaign/campaign.tscn`。
4. 三关均可从目录直接进入。原九种榫卯课堂为 `res://classroom/classroom.tscn`，也可以从关卡教学入口进入。

也可以在终端运行：

```sh
cd /你的路径/仓库目录
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT" --version
"$GODOT" --headless --editor --path . --import --quit
"$GODOT" --path .
```

如果 Godot.app 名称或位置不同，调整 `GODOT`。运行已有场景不需要 Blender、Python、Node 或另行安装插件；修改参数化生成器时才需要相应工具。导出 macOS App 时才需要同版本 Export Templates；这里交付的是可编辑工程，并未创建签名或公证安装包。

## 当前实际行为

- 第一关为固定龙骨、三次不同榫卯手动示范、七件同类构件自动补齐。观察页可看三种榫型和三档长度，拖动木料沿路径插入/拉回，松手达到深度后接好。三种榫型与长度均可试装；错误组合可以装上，但不满足稳定判定。
- 第一关目前仍是**装齐并等待动画结束后，手动点检查，错误构件才晃动**；可以撤回调整。没有实现错误后立即判为本关失败的流程。
- `assembly_drag_surface.gd` 仍绘制“沿槽口推入”/“松手接好”。此前移除悬浮文字的请求没有落到正式代码，不能据此认为已完成。
- r6 已包含去掉抓取圆环、接合镜头连续、观察页不透明局部剖开、错型接收空间路径适配，以及上图下文的“船匠的小故事”。见 [r6 记录](LEVEL01_ALIGNMENT_R6.md)。
- 第二关仍是正式版的 `seam_reference.png` 参考展开图；动态错缝图修复没有合入。第三关为桅座、帆桁、船尾舵架装配及左右操舵。
- 目录在一次运行中保留各关实例和完成标记；重新搭建重置本关。当前没有磁盘存档或云同步，退出应用不保留本次关卡进度。

## 接下来应完成的需求

用户已明确：错误发生后应自动晃动，并弹出“似乎拼接有错误哦”，下面提供“重新开始”；这代表**本关没过**。不应再等玩家点“检查连接/检查稳定”才触发，也不应只允许原地修正继续算通过。重新开始只重置当前关，不清空其他关卡进度。

建议从以下位置接手，迁移基线尚未实施这些修改：

| 文件 | 责任 / 待办入口 |
|---|---|
| `levels/level01/level01.gd` | `_check()` 仍触发晃动；协调器应接入自动失败、弹窗、动画和输入锁定。`_restart()` 已有本关重置入口。 |
| `levels/level01/level_state.gd`、`connection_rules.gd` | 放置状态与判定；区分未完成装配、错误配合、本关失败与完成状态。 |
| `levels/level01/level_ui.gd` | 失败提示及“重新开始”按钮，避免失败后仍能继续检查通关。 |
| `levels/level01/skeleton_view.gd` | 已有 `show_instability()` 晃动表现。 |
| `levels/level01/assembly_drag_surface.gd` | `_draw()` 中仍有“沿槽口推入”文字；移除用户指定的悬浮文字，保留必要的拖动路径交互。 |
| `campaign/campaign.gd` | 保证失败/重开仅影响本关实例和徽标，其他关卡保留。 |

还需验证失败后的动画回调取消、重复放置/点击隔离、返回目录、课堂往返、撤回/重开，以及重新挑战能够正常通关。旧测试期待“手动检查后晃动并可原地修正”，实现新规则后应同步调整这些断言。

## 工程结构

| 路径 | 内容 |
|---|---|
| `campaign/` | 三关目录、实例和完成状态管理 |
| `levels/level01/` | 龙骨立架、观察/选材/插入/故事；背景资源在 `assets/` |
| `levels/level02/` | 船板合壳、端缝与水密教学 |
| `levels/level03/` | 帆樯舾装与舵架，已有 OBJ 资源在 `assets/` |
| `levels/shared/`、`shared/` | 共享教学与关卡 UI |
| `core/` | 装配、输入、碰撞与路径逻辑 |
| `demo/`、`classroom/science/` | 原九种榫卯课堂、动态/受力展示及主题 |
| `models/joinery/` | 原始网格、预览、定义与可重复生成脚本 |
| `tests/` | GDScript/Python 检查源码与历史文本记录 |
| `docs/` | 分层、需求、验收与本次接手说明 |

保留 `project.godot`、`.gitattributes`、资源旁的 `.import` 设置和 `.uid`。`.godot/` 是机器生成缓存，应由 Mac 重建，不能拿 Windows 缓存替代导入。当前无 LFS 或 Git submodule 依赖，无额外 DLL/GDExtension/C# 依赖。

## 来源与保留边界

正式来源为 Windows 桌面“个人项目/古船榫匠”，原 `main` 历史保留，迁移前 HEAD 为 `ea7d16ff6131cadb38844e0d53236f318851d1e6`。这次提交同时纳入此前正式目录中未提交的关卡、课堂、源资产和测试源码，没有覆盖游戏代码或几何。

`Documents/Codex/2026-10-27/task/ship-level1` 是旧工作副本，不能整体覆盖正式工程：第一关源码相同，第二关 UI 不同，工作副本还额外含 `seam_diagram.gd`；正式版有工作副本缺少的若干 `.uid`。这些差异没有在迁移时擅自合并。

根目录的日期命名隐藏实验目录、`classroom/science/dynamic/backup-*`、`.godot/`、日志和测试生成的大量截图/GIF 已从迁移提交排除，但**原文件仍留在 Windows 磁盘，未删除**。参考图片、模型预览、船坊背景、游戏源资产和导入设置均保留。历史 Markdown/JSON 记录可能提到未纳入 Git 的旧截图和本机绝对路径；它们是历史证据位置，不是运行依赖，也不代表新机器已经重跑过。

## 验证办法与限制

先在克隆目录导入，再执行下面的现有测试；测试会写报告/截图，请用单独验证克隆，或先确认工作区没有未保存修改。测试套件中有较旧的规则断言，失败时先对照 r6 和本说明区分旧期望与当前代码问题，不要为迁移擅自回退用户现有逻辑。

```sh
"$GODOT" --headless --editor --path . --import --quit
"$GODOT" --headless --path . --script tests/level01_rules_tests.gd
"$GODOT" --headless --path . --script tests/level01_inspector_tests.gd
"$GODOT" --headless --path . --script tests/receiver_section_tests.gd
"$GODOT" --headless --path . --script tests/campaign_tests.gd -- --phase=full
"$GODOT" --headless --path . --script tests/campaign_tests.gd -- --phase=classroom
```

实际迁移验证结果见 [MIGRATION_VALIDATION.md](MIGRATION_VALIDATION.md)。历史验收记录不是本次测试结果。自动化使用 Viewport 注入事件，不能替代真实鼠标、触控板、实体触屏或 Mac GPU 验收。

Mac 首次手动检查：三个关卡均可进入、教学可返回、中文可读、窗口缩放后按钮可用、拖件/拉回/镜头旋转/滚轮正常、故事滚动正常、第二三关流程可继续。当前优先指定微软雅黑和 Noto 系统字体，Mac 会回退到可用字体，可能出现换行、字重与布局差异；未随项目分发微软字体。不要直接因字体差异改动几何。

截至本迁移，**没有在 Mac 实机运行或完成 macOS 导出验收**。Compatibility 渲染和静态资源检查不能证明所有 Apple GPU/触控板行为一致。船体、运动、水密和历史说明为教学简化，不是实体工程认证或历史施工复原。

日常在 Mac 修改前先 `git status` 和 `git pull --ff-only`，完成后提交推送；Windows 接续也先同步，避免两台机器覆盖未提交工作。不要推送 `.git/` 本身或使用 `git push --mirror`。
