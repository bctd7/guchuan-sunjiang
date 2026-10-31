> 历史归档（2026-10-31 整理）。原路径：`docs/WHOLE_LEVEL_FAILURE_R8.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 整关拼接检测 r8

2026-10-31。第一关运行标记 `whole-level-failure-20261031-r8`。本说明取代 r7 单件入槽后立即失败的流程。

## 当前行为

- 第一关允许三种榫型、三档长度试装，保留玩家选择并复制到同组自动件。局部不合不弹失败、不锁操作，进度只显示“已试装”。三次示范与七件自动件全部入位、最后一件真实动画结束后，统一自动检查。
- 不完整状态及进行中的自动组不会触发失败。状态层的完整性检查优先于配合判定，协调器不再在代表件入槽时调用失败检测。手动“检查稳定”保留，未装齐和动画中不能验收。
- 第二关保留观察、顺序、候选适配及同列排布约束。十件全部入位且末件动画结束后自动验收相邻板列的端缝；不完整时不显示漏水验收结果。对齐端缝的完整船壳进入锁定失败，不再通过“修正端缝”续关。
- 第一、二关统一显示“拼接有错误哦”，提供“重新开始”和“回到关卡目录”。失败后阻止撤回、重新检查、故事/课堂及旧输入回调恢复当前挑战；Esc 不关闭失败弹窗。
- 返回目录保留当前挑战，重进后仍保持失败弹窗；重开清空本关状态和完成徽标，保留其他关实例与进度。第一关仍保留固定龙骨。第一关重开会取消插入、自动装配和晃动回调，旧动画代次不能影响新一轮。
- 正确整关自动通过，成功卡片、目录完成徽标和下一关入口保持同步。第三关未更改玩法：错误候选在形成接合前拒绝入槽，无“装上错误木件”的状态；完成全部八件并通过左右试舵后通关。

## 文件边界

第一关 `connection_rules.gd`、`level_state.gd`、`level01.gd`、`level_ui.gd`；第二关 `level_state.gd`、`level02.gd`、`level_ui.gd`；新增共享 `levels/shared/assembly_failure.gd`。对应规则、输入和渲染测试已同步。未修改故事素材或模型材质，未提交或推送。

## 验证入口

```sh
godot --headless --path . --script res://tests/level01_trial_rules_tests.gd
godot --headless --path . --script res://tests/level01_length_rules_tests.gd
godot --headless --path . --script res://tests/level02_rules_tests.gd
godot --headless --path . --script res://tests/level01_failure_tests.gd
godot --headless --path . --script res://tests/level01_input_tests.gd
godot --headless --path . --script res://tests/level02_input_tests.gd
godot --headless --path . --script res://tests/level03_input_tests.gd
```

输入测试使用墙钟防重计时，必须按真实时间执行，不能用 `--fixed-fps` 加速整个引擎。新增失败测试仅加速真实 Tween，不直接写入玩法状态。自动鼠标/触摸事件不等于真人鼠标、触控板或实体触屏验收。GPU 复核入口为 `tests/level01_failure_visual.gd`，使用最小化 NO_FOCUS 宿主和独立 SubViewport。

最新执行结果见 [r8 验证记录](../../../../tests/WHOLE_LEVEL_FAILURE_R8_VERIFICATION.md)。
