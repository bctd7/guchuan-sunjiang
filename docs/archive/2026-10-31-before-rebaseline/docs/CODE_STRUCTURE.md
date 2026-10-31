> 历史归档（2026-10-31 整理）。原路径：`docs/CODE_STRUCTURE.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 当前代码结构

本页描述迁移后的工作树，验证与限制见 [迁移记录](ARCHITECTURE_MIGRATION.md)。

```text
campaign → level01 / level02 / level03
             ├─ 本关 State → Rules
             ├─ 本关 View → models/ship
             └─ levels/shared/teaching_portal
                    ├─ shared/source_presentation
                    ├─ classroom/introduction + content
                    └─ classroom/classroom
                           ├─ core/interaction → core/assembly
                           ├─ models/joinery/catalog.json
                           ├─ classroom/display + ui
                           └─ classroom/science
```

campaign 使用关卡 `enter()`、`leave()`、`is_completed()`、`navigation_status()` 与 `progress_changed`。关卡首次创建后缓存，离开移出场景树，重进复用同一实例，不重复 configure 或创建输入适配器。campaign 退出时释放 detached 实例。

各关 State 独立。第一关三次示范与自动补齐、第二关 next_id 顺序、第三关工作台依赖都保留。规则接受早于动画落位，协调器仍等待动画后验收。第一关状态规则仍是部分前置约束，此次没有新增玩法限制。

View 拥有场景、相机和 Tween，models/ship 拥有实体与展示几何。第一关 candidate_geometry 仍在关卡，因为原件保护检查依赖 source_view；迁移没有掩盖该耦合。观察器几何与材质辅助抽至 `levels/level01/inspector/inspection_geometry.gd`。

教学接入器 `levels/shared/teaching_portal.gd` 保管本关三课映射和返回位置。`shared/source_presentation.gd` 保存恢复来源显隐、输入与相机。介绍布局位于 `classroom/introduction/lesson_intro.gd`，文案位于 `classroom/content/lesson_copy.gd`。兼容字段保留供现有测试读取。

课堂以 `open_joint(id)`、`modal_open()`、`modal_changed` 和相机激活接口接入。课程范围在 add_child 前设置；关闭课堂移出并释放整个实例，避免 CanvasLayer 残留。回介绍不恢复船输入，离开介绍才恢复来源，失败关卡保留原输入锁。

课堂创建独立 Assembly。display 管理材质和显示副本；core 使用原教材网格及碰撞边界。受力入口使用燕尾专用演示与其他八种 gallery。旧静态接触科普保留在 science 和独立审核场景，不宣称主课堂已有其可见入口。

| 模块 | 内容 |
|---|---|
| models/joinery | catalog、21 个教材 mesh 引用、资产与同目录生成器 |
| models/ship/keel | 第一关几何、长度、试装和接收件展示 |
| models/ship/hull | 第二关几何 |
| models/ship/rigging | 第三关几何、生成器、船用 OBJ |
| shared/ui | 跨模块主题 |
| shared/chinese_fonts.gd、shared/fonts | 中文字体与项目默认字体 |
| classroom/ui | 课堂面板及木梯控件 |

资源 UID 和 import 元数据随文件移动，动态路径、catalog 与生成器同步更新。历史证据保留原记录。core 与模型无向上资源依赖，课堂无具体关卡资源依赖。课堂网格路径验证与造船玩法试装动画保持各自职责。
