> 历史归档（2026-10-31 整理）。原路径：`README.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 古船榫匠

Godot 默认入口为 `campaign/campaign.tscn`。三个关卡平行开放，每关保存本次运行的独立进度。返回目录再进入先显示本关介绍，再恢复原船体进度；没有跨运行存档。

- 第一关：三次手动示范与七件自动补齐，全部落位后整关验收。
- 第二关：依次安装十件船材，动画结束后检查端缝。
- 第三关：桅座、帆桁、舵架，完成左右试舵。
- 独立九种榫卯课堂：`classroom/classroom.tscn`。课堂装配与船体进度独立。

现行操作见 [验收说明](docs/ACCEPTANCE.md)，模块边界见 [代码结构](docs/CODE_STRUCTURE.md)，本次路径与验证见 [迁移记录](docs/ARCHITECTURE_MIGRATION.md)。历史验证报告保留执行时的事实，不代表当前工作树已全部回归。

| 目录 | 用途 |
|---|---|
| campaign | 平行关卡目录、缓存与导航 |
| levels | 各关协调器、规则、状态、UI、视图与观察流程 |
| classroom | 独立课堂、介绍、内容、显示与受力科普 |
| models/ship | 船材构造、尺寸、试装展示几何与烘焙资产 |
| models/joinery | 九种教材模型、catalog、生成器与审核 |
| core | 教材装配语义、路径、碰撞、指针与相机适配 |
| shared | 字体、共享 UI、来源呈现恢复机制 |
| tests | 规则、输入、几何、生命周期及视觉验证 |

运行 `python3 tests/run_suite.py --help` 查看测试分组。测试应在隔离副本中执行，部分测试会写回 `res://tests/` 报告。导入命令：`godot --headless --editor --path <副本> --import --quit`。

模型和受力内容属于教学简化，不是历史原位复原或制造强度计算。运行不需要 Blender，部分网格重新生成才需要已有 Blender 环境。
