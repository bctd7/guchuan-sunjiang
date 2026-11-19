> 技术资料：描述现有模块或资料来源，不定义最新关卡需求或完成状态。最新要求与差异见[文档入口](../../../../../docs/README.md)（2026-10-31 整理）。

# 燕尾榫：当前受力演示

正式入口是 `classroom/classroom.gd` 的 `_open_education()`：燕尾榫打开本模块，其余八种打开 force_gallery。独立查看运行 `classroom/science/dynamic/demo.tscn`。这里不是图片或视频播放器：`diagram.gd` 用 Godot `_draw()` 绘制剖面、箭头及光带，`advance(delta)` 推进时序。

## 当前行为与接口

打开即播放，只有一个抗拔剖面，每 6 秒循环。没有方向切换、播放或重播按钮；唯一按钮是 ×，Esc 同样关闭。`open_for_joint("dovetail")` 从头开始，其他模型 ID 返回 false；`close()` 隐藏并停止处理。`set_paused(bool)` 用于生命周期暂停恢复，保留当前阶段。宿主通过 `lesson_visibility_changed` 暂停和恢复后台装配输入。

0.15–1.05 秒：活动件朝屏幕上方移动到斜面接触；1.05–4.5 秒保持接触。反力箭头在接触后出现并于 2 秒前淡出；2–4.25 秒的光带沿固定槽座到支撑；4.5–5.9 秒无施力复位，随后开始下一轮。关闭不继续计时，重开从零开始。

## 与当前模型的对应和边界

当前模型来自 `models/joinery/catalog.json` 的 `dovetail`，槽座固定，滑条沿 Z 装入开放贯通槽。本页展示横截面中朝 +Y 抗拔的定性接触，并不把 Z 装入方向说成受阻方向。

`diagram.gd` 的截面为简化手绘坐标，不从 OBJ 实时生成。当前 OBJ 接触面斜率约为滑条 0.441、槽壁 0.457；图中统一用 35/80 = 0.4375 表达近似平行斜面。测试从 OBJ 的主要接触三角面读取斜率，以 0.02 的近似容差核验方向和比例。此容差不是尺寸精度或承载能力结论。图中间隙 6 px 被放大，截止位移按图中间隙/斜率计算，不能换算为真实位移。

这是定性几何与时序动画，不是有限元或应力计算。箭头表示活动件所受示意力；光带不代表应力大小、传播速度或物质流动。没有求解材料、摩擦、刚度、平衡或承载力。复位是教学循环。绘图缩放上限 1.0，小窗口等比缩小，未更改三维相机。

## 验证

`test_dynamic.gd` 覆盖当前 OBJ/图示对应、至少八轮运动连续性、接触/箭头/光带时序、暂停恢复、关闭停机、Esc、五次重开、四种窗口尺寸，以及入口模型切换。`tests/dynamic_integration_tests.gd` 使用课堂实际入口和鼠标事件核验模态期间输入隔离及退出后的装配。

```sh
godot --headless --path <项目副本> --script classroom/science/dynamic/test_dynamic.gd
godot --headless --path <项目副本> --script tests/dynamic_integration_tests.gd
```

测试会写入副本的 evidence；图形截图需额外传 `-- --capture` 并使用可用图形环境。历史 evidence 是当时结果，不代表当前测试已执行。
