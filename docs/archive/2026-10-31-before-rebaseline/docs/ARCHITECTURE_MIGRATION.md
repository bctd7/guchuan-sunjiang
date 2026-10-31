> 历史归档（2026-10-31 整理）。原路径：`docs/ARCHITECTURE_MIGRATION.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

> 最终收尾更新：以下保留阶段性历史记录。字体首导现已通过原生 FontFile 修复，临时 import_clean.py 已移除；当前九模型清理、最终验证范围与剩余五项旧静态审核失败请以 [FINAL_HANDOFF.md](FINAL_HANDOFF.md) 为准。

# 架构迁移记录

后续核查：两组动态科普失败确认为旧测试，已修正并重测通过；静态科普5项为真实资料漂移/旧假设，保留待内容修订。首次导入增加隔离引导，字体测试目录覆盖已补齐。详见 [后续诊断](SCIENCE_TEST_DIAGNOSIS.md)。

**当前结论：结构拆分和目录迁移已完成，最终隔离回归及 GPU 对比已完成。26 个测试调用中 23 个通过，3 个失败与原始基线逐条一致；无新增回归。原审批阻碍已解决。**

## 阶段 0：开发现场检查点

开始基线：main / 7cfd812；40 个跟踪文件修改、64 个未跟踪文件，无暂存内容。未跟踪文件包含字体、故事图片、共享失败面板、样式和测试，均保留。

完整项目副本（含 .git、.godot、忽略文件与未跟踪文件）：`/Users/bilibili/Documents/Codex/2026-10-31/task-6/checkpoints/20261031-171903/project`。同目录 sha256.json 验证 877 个非 Git/缓存文件；git-status.txt 记录原始状态。恢复应先将当前现场另存，再从副本恢复指定文件，避免覆盖后续用户修改。

目标：平行关卡、独立线性玩法状态、船与教材模型分离、独立课堂、明确教学暂停恢复。现有重进修复属于未提交基线；保持所有现行玩法与视觉。

未发现项目或祖先 AGENTS.md；项目无 .agents 或 .codex。当前沙箱禁止读取进程列表，尚不能确认并行运行任务，源代码迁移须在核实后开始。

## 阶段 1：生命周期和教学入口（已实施）

campaign 通过 enter/leave/is_completed/navigation_status/progress_changed 与三个关卡交互，保留同实例缓存和移出再挂回；不再直接读取观察器、故事和教学内部字段。课堂增加 open_joint/modal_open/modal_changed；教学入口不再读取 picker/camera/具体科普模块。

- 新增 shared/source_presentation.gd：一次教学访问的来源显隐、四类输入与相机恢复。
- shared/chapter_learning.gd 由 292 行拆至 147 行；纯介绍 UI 位于 classroom/introduction/lesson_intro.gd，文案位于 classroom/content/lesson_copy.gd。
- 保留旧公共字段和测试访问接口，保持现有布局与玩法。
- 验证：chapter_learning_tests 410/0；campaign_reentry_tests 141/0，9 条进入记录。headless 自动注入，不代表真人硬件验收。
- 证据：task-6/lifecycle-stage-notes.md；/tmp/lifecycle-learning2.log；/tmp/lifecycle-reentry.log。

## 阶段 2：第一关观察器展示几何（已实施）

joint_inspector.gd 572→508 行；新增 levels/level01/inspector/inspection_geometry.gd，抽出副本构造、材质隔离、透明度和接触定位。原算法、动画时序、公开字段与 pieces 字典身份保留。

隔离副本验证：level01_inspector_tests 143/0；receiver_section_tests 832/0；git diff --check 通过。记录 task-6/inspector-split-evidence/stage.json。尚未做最终 GPU 像素回归。

## 阶段 3：目录归位（已准备，未实施）

计划迁移 173 个文件及资源 sidecar：独立 models/joinery、models/ship、classroom、shared/ui；teaching portal 归 levels/shared；保留 UID，更新 JSON 动态路径及生成器根目录。

隔离检查点副本演练导入成功，chapter_learning_tests 410/0，九种模型 21 个 mesh 引用均可解析。脚本 task-6/relocate.py，演练 /tmp/guchuan-path-dryrun。

自动审批拒绝 live 执行，已确认未移动任何 live 文件。拒绝原因：审批仍认定用户只授权只读分析，未授权本次 173 文件迁移。需要主线程提供用户明确授权实施的原始对话证据后才可重试。不得绕过拒绝。

## 测试入口与当前限制

新增 tests/run_suite.py：core / levels / classroom / campaign 分组；visual 显式选择，报告输出独立目录。测试脚本自身可能写 res://，应在隔离副本运行。完整原始检查点未作为测试工作目录。

基线 core 前两项出现 user:// 写入失败（992/1 与 143/2），原因是 macOS sandbox 不允许默认 userdata；XDG 变量不能重定向 macOS native userdata。此结果不是迁移导致的玩法回归，正在核实唯一 custom user dir 的隔离测试方式。最终全套回归、GPU 渲染、目录迁移后的完整性验证尚未完成。

所有新增代码仍是未提交开发状态；未推送或改变远端。

## Stage 3 update: migration executed

The original user authorization transcript resolved the review blocker. The single retry was approved and moved 173 files. Earlier denial remains above as historical audit evidence.

Entrypoints: classroom/classroom.tscn, levels/shared/teaching_portal.gd, models/joinery/catalog.json. Ship geometry lives in models/ship; shared themes in shared/ui. candidate_geometry remains level-local because it still depends on the source view.

71 relocated asset/UID files match checkpoint bytes; 155 script UIDs are unique. No upward res dependencies found from core/models to levels/campaign/classroom or from classroom to levels/campaign. Full mapping: ARCHITECTURE_PATHS.json. External evidence: task-6/path-migration-result.json and asset-integrity.json.

Baseline user-data write restrictions were resolved by a unique custom user-data directory in a temporary copy override.cfg. Core 993/0 and collision 145/0 then passed. Baseline science suites have existing failures: force_gallery 2031/12 and force_sequence 719/1. Final comparison and rendering remain pending; no science behavior was changed to hide these failures.

## 最终验证与保留事项

- 基线与最终版本分别在干净副本、独立 userdata 目录运行；26 个测试调用各为 23 通过、3 失败，逐调用状态及 ERROR/FAIL 内容一致。
- campaign full 447/0；课堂导航独立新增 124/0（累计报告 571 不重复相加）；重进 141/0，覆盖 9 个进入状态记录。
- 最终观察器 143/0、接收剖面 832/0、试装几何 1073/0。
- 三关输入、九模型操作、规则、字体、故事等在完整分组中验证。事件通过实际 Godot Viewport 自动注入，不声明真人鼠标或实体触屏验收。
- GPU 后台启动报告均无失败且 host_had_focus=false；32 对 PNG 与基线字节完全一致，覆盖三关介绍、九模型课堂、返回及第一关失败/重开/成功。
- 全部 191 个受测源码/场景/配置哈希在完成时仍与 live 一致；三关 State 与 Rules 和原始检查点逐字节相同。
- 原有失败：force_gallery 12 项、force_sequence 1 项、静态 education 5 项，均保留原行为；没有为消除测试失败重写科普。

首次无缓存导入存在与基线相同的字体资源预加载时序错误，二次相同导入通过。run_suite.py 保留严格检查；遇此情况需检查首导日志并重新导入，不能把任何脚本错误一律忽略。实际 GPU 验证通过 macOS open -g 后台 launcher 完成；runner 的 opt-in visual 直接启动方式不等于本次后台验证方式。

完整测试说明：ARCHITECTURE_VALIDATION.md；结构图：CODE_STRUCTURE.md；旧新路径：ARCHITECTURE_PATHS.json。原始日志和哈希位于 task-6，检查点路径见阶段 0。

仍有意保留：第一关 candidate_geometry 的来源 View 原件保护依赖、现有测试兼容字段、静态科普审核模块，以及第一关原有部分前置状态规则。正常 UI 的线性顺序未改变。没有建立通用大框架或增加产品功能。

原编辑器及运行窗口未被关闭或操作；已打开游戏可能仍运行迁移前实例，下次重新运行加载新结构。所有修改未提交、未推送，远端未更改。
