# 测试与证据索引

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
