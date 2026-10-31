# 布局、分关教学与动画门控：本轮验证

2026-10-28。正式项目入口保持 campaign/campaign.tscn；工作副本验证后以文件哈希防冲突合入，不修改 project.godot，不覆盖用户设置或删除旧材料。

本轮改动：第一关收紧侧栏，依据真实最终构件边界调整镜头，删除右上编号/观察全架及旧集中九课入口；三关开头各三课，原课堂用可选过滤复用、默认九课保留。第一关 shipyard_background.png 使用原始批准图片，workshop_backdrop.gd 仅在运行时降饱和、柔化与压对比度。只有第一关环境改为画布背景与透明阴影承接面。模型和原木材质未改。

第一关保留三次手动示范和七件自动构件，每件实际 Tween.finished 后再启动下一件；过早关闭局部演示也等待代表件实际插入。检查稳定需十件移动构件装齐、pending 为空且动画结束。第二关增加 busy 门控，不能用快速换件取消插入动画；撤回、修复、重置可明确取消。第三关已有八件实际动画与 busy，新增教学往返和输入保护。

自动化 headless 测试本轮全部通过（2679/0）：

| 测试 | 通过 | 失败 |
|---|---:|---:|
| 第一关规则 |333|0|
| 第一关鼠标/触摸事件注入、逐件动画、撤回重置 |656|0|
| 第二关输入与动画防跳过 |339|0|
| 第三关输入 |155|0|
| 榫型选前观察 |384|0|
| 局部旋转 |42|0|
| 第二关几何 |20|0|
| 第三关几何 |24|0|
| 三关共享教学组件、默认独立九课 |191|0|
| 实际三关场景全部九课往返 |121|0|
| 三关完整流程输入注入 |414|0|

证据：tests/evidence/chapter-learning-regression-summary.json、campaign-classroom-learning-report.json；完整流程报告副本在 tests/evidence/layout-current/campaign_report.json。原有验证文档和截图保留，不能把旧记录当本轮人工试玩。

真实 GPU：tests/layout_visual_regression.gd，Compatibility/OpenGL，独立 1440×900 SubViewport。10 张图，0 失败；隐藏 NO_FOCUS 宿主前后均无焦点，不发送桌面输入。图片在 tests/evidence/layout-current/；report.json 记录方法和结果。已人工读取渲染图片检查布局、背景层次、局部画面、完成骨架、俯视图、三关介绍和后两关背景。脚本设置场景用于截图，不能等同于人工操作完成。

原路径验证：正式工程后台资源导入退出 0，无 ERROR / SCRIPT ERROR；campaign 实际 Viewport 输入启动检查 50/0。2799 个旧文件无丢失、无意外修改，2284 个受保护文件零变动。全部 51 个合入目标与工作副本哈希相同；project.godot 保留用户当前文件。

限制：未做本轮实体触屏或用户前台完整人工试玩。用户已授权将六张截图上传 Library；官方上传流程报告 Library prepare_uploads is not available，未返回文件 ID，未完成上传，未改用其他方式绕过。全部截图已保存本地，不影响工程验收。未提交、推送或覆盖远端。
