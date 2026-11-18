# 三关公共界面验证（2026-11-18）

本次统一第一关样式的小故事、主界面标题/任务卡/底栏，第三关加入公共观察页、候选卡、缩放、放大、课堂返回和呼吸引导。第三关故事允许 mock，显示待补充内容。没有修改三关装配判定或自动补齐规则。

## 修改位置

- 新公共组件：`levels/shared/chapter_chrome.gd`、`story_panel.gd`、`story_overlay.gd`、`selection_card.gd`、`workshop_backdrop.gd`。
- 第一/二关：`level_ui.gd` 接公共页面外壳；`shipwright_story.gd`、`bulkhead_lesson.gd` 变为内容适配；`type_gallery.gd`、`joint_gallery.gd` 接公共候选卡；背景脚本只配置图片。
- 第三关：`level_ui.gd` 接公共主界面、观察页、放大、相机控件；`level03.gd` 接故事/观察流程；`candidate_gallery.gd` 保留模型内容、复用公共卡片；`rigging_view.gd` 提供相机中心和插口投影。
- `selectable_orbit.gd` 增加不与旋转混淆的点击坐标信号，第三关用其发起原有安装请求。

## 实际运行

在隔离副本 `/private/tmp/guchuan-text-cfYvzk` 运行 Godot 4.7.2，未在用户正在运行的工程实例中注入操作。

| 检查 | 结果 |
|---|---|
| `shared_chapter_ui_visual.gd` | macOS OpenGL/Metal GPU 实际渲染，1920×1080，19 张截图，失败列表为空 |
| 三关故事 | 按钮打开/关闭、Esc、进度与相机恢复；前两关正文触摸滚动；第三关短 mock 内容无需滚动 |
| 第一/二关观察页 | 进入、选择类型、放大、关闭、返回 |
| 第三关完整流程 | 错型拒装；八件 ScreenTouch 安装；缩放和重置；放大/课堂返回；左右操舵成功；目录返回与新实例重新开始 |
| 触摸目标检查 | 所有截取页面的可见按钮均在视口内，尺寸不低于 60 像素 |
| `observer_entry_tests.gd` | 13 项通过，0 失败；第一关显式选择和观察页往返 |
| `bulkhead_story_visual.gd`（headless） | 60 项通过，0 失败；1920、1440、1280、1100、960、768 宽阅读布局、滚动、内容、输入恢复 |
| `level03_input_tests.gd`（headless） | 161 项通过，0 失败；鼠标/触摸、安装动画、依赖、撤回重装、左右操舵、完成事件去重和返回信号 |
| `git diff --check` | 通过 |

最终 GPU 日志没有脚本/资源报错。第二关故事和第三关 headless 脚本退出时仍有 4 个 ObjectDB 实例、2 个资源未释放的退出诊断；不能据此声称全套运行零警告。未验证实体 32 寸触屏、Windows 实机、导出包；本次也未重跑第一、二关全部装配路径或历史全量测试集。

## 截图与报告

- [第二关小故事](evidence/shared-chapter-ui/2-story.png)
- [第三关 mock 故事](evidence/shared-chapter-ui/3-story.png)
- [第三关搭建页](evidence/shared-chapter-ui/3-main.png)
- [第三关观察页](evidence/shared-chapter-ui/3-observe.png)
- [第三关操舵](evidence/shared-chapter-ui/3-helm.png)
- [第三关成功页](evidence/shared-chapter-ui/3-success.png)
- [GPU 结果及全部图片清单](evidence/shared-chapter-ui/report.json)
- [GPU 日志](evidence/shared-chapter-ui/shared-ui-final.log)
- [第三关输入报告](evidence/shared-chapter-ui/level03_input_report.json)

剩余独立组件详见 [三关组件核对](../docs/current/CHAPTER_COMPONENT_AUDIT.md)。主要页面共用不等于所有关卡 UI 都已配置化。
