# 第二关海边船台背景

日期：2026-11-01。用户要求第二关与第一关画风一致，仍为海边船台。先核对第一关原图和实际 GPU 总览，再用内置 image_gen 生成新的室外背景。第一关源码、原图及第二关原 SVG 保持不变。

## 风格与实现

第一关参考为暖色侧光、旧木材、自然纹理和空间纵深的写实船坊；实际画面另有五点柔化、降饱和、压对比和暖灰处理。新图是开放海边船台，含远海、山岸和边缘工作台，中央留空，不把室内图直接拿来充当海边。它使用相同处理参数，保持模型及奶油色/深绿色 UI 的优先级。

新位图：[seaside_shipyard.png](../levels/level02/assets/seaside_shipyard.png)。[完整生成提示词和参考哈希](../levels/level02/assets/seaside_shipyard.generation.json)记录 built-in image_gen 来源；[背景组件](../levels/level02/hull_backdrop.gd)只换第二关图片与材质，不改相机、模型、玩法或课堂。处理参数在 `seaside_background.gdshader`。原 `tidal_shipyard.svg` 保留。

## 验证

隔离副本中资源导入、第二关几何回归通过；三项 Mac GPU 执行项通过：原共享观察页、原辅助入口、背景专项扩展。全部使用独立后台无焦点实例，未操作用户窗口。

- 1440×900、1100×800、960×600 实际截图检查裁切、模型与 UI 可读性。
- 原观察页覆盖鼠标/模拟触摸、旋转、正确装配和错开口试浪，未发现本轮背景影响既有交互。
- 背景专项检查实际加载的新纹理；总览可见、局部隐藏；进入原榫卯课堂隐藏，返回局部保持浅色，再回总览恢复海边。
- 第一关背景源码和原 SVG 字节核对一致；新资源均随工程保存。

[逐项结果](evidence/seaside-background/validation.json)和 [画面对照](evidence/seaside-background/compare.html)保留原始报告、日志及截图。背景 probe 最初把目录重进也当成局部课堂返回，修正夹具上下文后通过；产品导航未修改，初次日志保留。隔离导入的 macOS 证书/全局编辑器设置保存警告按已知环境限制记录，不隐去其他错误。

复现请用独立副本：`python3 tests/evidence/seaside-background/run_background_gpu.py --group visual --case auxiliary_panel_tests --case inspection_workspace_tests --case backdrop_probe --allow-visual`。这只临时注册背景扩展，不修改正式标准 runner；夹具会写 res://tests 报告。

本轮无提交或推送。自动输入与 GPU 截图不等于真人鼠标、实体触屏或其他系统实机验收。
