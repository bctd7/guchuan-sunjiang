# 三关公共组件核对（2026-11-18）

结论：三关已经共用主要页面外壳和通用交互组件，但尚未达到“完全没有关卡独立 UI 实现”。关卡目录下的文件也不全是独立组件，其中有内容配置、数据适配、模型和玩法规则。

## 已共用

| 部位 | 公共实现 | 使用情况 |
|---|---|---|
| 搭建页标题、任务卡、底栏 | `levels/shared/chapter_chrome.gd` | 三关调用同一构建函数；任务文字和动作由关卡提供 |
| 船坊背景绘制 | `levels/shared/workshop_backdrop.gd` | 三关共用处理；第二关配置海边背景图 |
| 小故事页面 | `levels/shared/story_panel.gd` | 同一标题、图片、正文阅读区、关闭按钮和排版 |
| 故事打开/关闭 | `levels/shared/story_overlay.gd` | 三关共用输入暂停/恢复、Esc、焦点恢复 |
| 观察页框架 | `levels/shared/inspection_workspace.gd` | 三关共用；第三关没有尺寸候选，隐藏右栏 |
| 榫型候选卡 | `levels/shared/selection_card.gd` | 三关复用同一个卡片布局，模型内容各自提供 |
| 旋转、缩放、放大查看 | `inspection_orbit.gd`、`selectable_orbit.gd`、`inspection_zoom_bar.gd`、`rotatable_preview.gd`、`model_magnifier.gd` | 第三关已接入现有公共路径；第一关预览仍有自身模型适配 |
| 呼吸引导 | `levels/shared/step_guide.gd` | 保留当前公共版本，无新增文字引导 |
| 讲解入口 | `levels/shared/teaching_portal.gd` | 三关共用介绍、课堂及来源恢复 |
| 成功/失败呈现 | `levels/shared/chapter_result.gd`、`assembly_failure.gd` | 三关成功及前两关原有失败共用；第三关仍按原规则拒绝错误安装 |

第一关 `shipwright_story.gd`、第二关 `bulkhead_lesson.gd` 现在仅提供内容配置（第二关保留既有调用名称），不是另一套故事 UI。第三关直接配置公共故事组件，文本和配图明确标记待补充。

## 仍有独立 UI / 呈现代码

| 关卡 | 位置 | 现状 |
|---|---|---|
| 第一关 | `length_candidate_gallery.gd`、`length_measure_panel.gd`、`length_comparison.gd` | 长度候选、槽深/定位标尺和尺寸呈现仍为本关专用 |
| 第一关 | `candidate_preview.gd`、`candidate_geometry.gd`、`inspector/inspection_geometry.gd` | 实际木件预览、局部副本和遮挡适配仍独立 |
| 第二关 | `opening_gallery.gd`、`opening_measure_panel.gd`、`opening_measure_marks.gd` | 开口候选、同尺度参照及标线仍独立 |
| 第二关 | `level_ui.gd` 的材料分组面板、`drag_guide.gd` | 分组展开和木料拖动提示仍在本关实现 |
| 第三关 | `level_ui.gd` 的操舵状态/按钮组 | 采用公共面板和按钮样式，但操舵区域的组合仍在本关脚本中 |
| 三关 | `level_ui.gd`、第一关 `joint_inspector.gd`、各关候选 gallery | 仍有适配代码负责将本关状态/模型/事件接入公共组件；并非纯 JSON 配置 |

因此不能把本次完成描述为“所有独立组件都已消除”。如果后续要求所有 UI 组合也配置化，上表是继续抽取范围；不应仅把文件搬到 shared 就声称完成复用。

## 应保留的独立玩法与数据

三关各自的 `level_state.gd`、`connection_rules.gd`、协调器、骨架/船壳/帆舵视图与几何仍独立。第一/二关拖动装配、第二关接触校验及试浪、第三关八件依赖和操舵校验不是相同业务；本次没有强制合并规则，也没有把真实模型替换成 mock。

验证与截图：[公共界面验证](../../tests/SHARED_CHAPTER_UI_VERIFICATION.md)。
