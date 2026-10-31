> 历史验证证据：保留执行当时的结果与原路径，不作为最新需求或本轮重跑结果。最新要求与差异见[文档入口](../docs/README.md)（2026-10-31 整理）。

> 历史记录：本页的单件立即失败流程已由 [r8 整关检测](../docs/archive/2026-10-31-before-rebaseline/docs/WHOLE_LEVEL_FAILURE_R8.md) 取代，不作为当前验收标准。

# 第一关自动失败 r7 · 验证记录

2026-10-31，macOS / Apple M1，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility。玩法版本 `automatic-failure-20261031-r7`。当前操作见 [r7 流程](../docs/archive/2026-10-31-before-rebaseline/docs/LEVEL01_FAILURE_R7.md)。

## 最终结果

| 检查 | 通过 | 失败 |
|---|---:|---:|
| 第一关基础规则 | 315 | 0 |
| 榫型与长度规则，27 个目标选择、729 组混合组合 | 33905 | 0 |
| 长度规则，27 组组合及失败后重开 | 2209 | 0 |
| 第一关鼠标/触摸输入、自动装配、撤回和重置 | 1239 | 0 |
| 新增自动失败流程，三处连接的全部 27 种选择 | 955 | 0 |
| 局部观察、选材和回看 | 143 | 0 |
| 接收件局部剖切及恢复 | 832 | 0 |
| 沿路径拖动、续拖、抽回、触摸及失焦 | 18 | 0 |
| 完整三关联调 | 426 | 0 |
| 三关课堂往返补充 | 124 | 0 |
| Mac GPU 截图检查 | 7 张 | 0 |

资源最终导入退出 0。上表最终运行全部退出 0，执行日志无 `ERROR` / `SCRIPT ERROR`；`git diff --check` 通过。不同套件存在重叠，不把断言总数当作独立玩家体验次数。

测试在 `/private/tmp/guchuan-r7-u6ldb_db` 的独立验证副本运行，避免覆盖正式目录的历史报告；正式工作区另完成最终资源导入。最终玩法源码及本轮测试源码与验证副本逐文件一致。

## 新规则重点

- 三个阶段各测试三种榫型 × 三种长度，共 27 个选择。24 个错误选择在实际插入结束后自动失败；3 个正确选择继续原有自动装配。
- 错误代表件不再触发同组自动补齐。提前关闭观察页仍等待船架插入结束；重复检查、装入、取回、撤回信号不能跳过判定。
- 弹窗文案为“拼接有错误哦”，按钮为“重新开始”。失败不能通过 Esc、撤回、重新检查或重复放置恢复；不显示成功卡片、不解锁下一关。
- 在其他关通过正常 UI 保留第二关部分装配、完成第三关后，第一关失败/返回目录/重开不会改动其他关的记录与完成标记。
- 失败后重开可再次完成三次示范、七件自动件和最终验收；课堂往返保留新挑战进度。
- 重开中断插入/晃动并隔离旧代次回调，包括新旧挑战正在操作同名船肋的情况。另检查错误木料确实在自动晃动中产生位置变化。

新增流程测试通过 Viewport 注入真实 GUI 鼠标事件与拖动事件，读取玩法状态而不直接改写它；加速实际 Tween，并在最终运行使用 `--fixed-fps 60` 加速模拟。基础输入与完整三关套件使用通常的实时运行。纯规则的混合组合测试会构造完整候选用于诊断，不代表玩家在运行中能越过已经触发的失败。

## 画面检查

实际 Mac GPU 渲染使用 OpenGL API 4.1 Metal / Apple M1。独立 SubViewport 配合最小化、`NO_FOCUS` 宿主；最终宿主未获得桌面焦点，未发送桌面鼠标或键盘操作。

已读取并检查开场、无悬浮文字的拖动页、晃动时失败弹窗、晃动后弹窗、1100×800 弹窗、重开和重开后成功画面。1440×900 与 1100×800 的失败标题和重开按钮完整可见；原方向箭头保留。小窗口检查针对新增弹窗，不宣称旧页面的所有固定布局均已响应式改造。

最终图片、JSON 报告及运行日志保存在 `tests/evidence/level01-failure-r7/`。图片和日志按仓库既有忽略规则保留本地，文本报告可版本管理。

## 复测

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/level01_failure_tests.gd --fixed-fps 60
godot --headless --path . --script tests/level01_trial_rules_tests.gd
godot --headless --path . --script tests/level01_length_rules_tests.gd
godot --headless --path . --script tests/level01_input_tests.gd
godot --headless --path . --script tests/campaign_tests.gd -- --phase=full
godot --path . --script tests/level01_failure_visual.gd --position -10000,-10000
```

这些结果证明本轮自动化输入、状态和 GPU 渲染通过；尚未进行真人鼠标、触控板、实体触屏或 macOS 导出验收。

后续文案调整：按用户反馈，失败标题改为“拼接有错误哦”，去掉不确定措辞。此项仅修改文案及对应断言；上述截图保留调整前的标题，未因本次文字调整重跑流程测试。
