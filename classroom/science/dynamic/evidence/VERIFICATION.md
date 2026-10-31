> 历史验证证据：保留执行当时的结果与原路径，不作为最新需求或本轮重跑结果。最新要求与差异见[文档入口](../../../../docs/README.md)（2026-10-31 整理）。

# 实际验证记录 · 2026-10-23

- 引擎：Godot 4.7.2 stable；图形：OpenGL 3.3 Compatibility，NVIDIA GeForce RTX 4070 Laptop GPU。
- presenter、diagram、demo 三个脚本分别 `--check-only`，退出 0，无脚本错误。独立 demo 场景 headless 启动 20 帧，退出 0。
- headless 运行专属测试：131 断言，0 失败，退出 0。
- 非 headless 真实渲染重跑：131 断言，0 失败，退出 0；最终 results.json 的 render_capture 为 true。
- 已查看 approach、section、slide 实际 Viewport 截图。剖面中位移在接触处停止，固定支撑不移动；接触高亮、法向反力箭头、传力颗粒可见。滑出视图显示部件越过开放槽端，施力方向为 +Z。修正了早期施力箭头与文字交叠。
- 已捕获四个窗口尺寸：640×480、800×600、1280×800、1440×900。所有控制按钮与外部状态文字均在窗口内；小尺寸图内标注随图缩小。
- 全项目 `--editor --import --quit` 完成资源扫描、类注册、PNG 导入并退出 0，没有最终脚本编译错误；但启动和退出时出现 `Safe save failed`（file_access_windows.cpp:277）。即使只在验证进程使用临时 APPDATA / LOCALAPPDATA，该编辑器保存告警仍存在，具体保存目标未由日志给出。不能宣称编辑器配置保存完全成功；未改变安全软件或系统设置，没有绕过拒绝。专属运行时验证不受此告警影响。
- 工作台主入口未写入；精确接线在 ../INTEGRATION.md，由结构任务统一合入并联调。这里验证了相同接口的入口按钮信号与换模可见性，但没有声称完成最终工作台端到端鼠标验收。

新建源码：diagram.gd、presenter.gd、demo.gd、demo.tscn、test_dynamic.gd（及引擎生成 UID）。文档：BACKUP.txt、README.md、INTEGRATION.md、本记录。没有覆盖既有 education 源码；没有写模型、catalog、core、workshop 或 project.godot 源码。
