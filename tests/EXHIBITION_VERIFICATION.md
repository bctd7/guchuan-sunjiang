# 1920×1080 展览适配验证

2026-11-16；Godot 4.7.2、macOS、Apple M1、OpenGL Compatibility。先读根 README、docs/current 文档、测试说明及布局源码；测试在 `/private/tmp/guchuan-exhibition` 隔离副本运行。未修改系统配置。

## 通过的检查

- `tests/exhibition_visual.gd`：实际 GPU 渲染 1920×1080 SubViewport，以鼠标事件进入目录、三关介绍、九种单个榫卯、九种科普页、第一/二关船坊和观察页、完整木料放大、故事与隔舱；第三关八件通过 ScreenTouch 事件装配，完成左右试舵和成功页。35 张 PNG；保存时断言分辨率、按钮不出屏及短边至少 60 像素；独立断言操舵按钮与页脚间距。全部通过。入口与关键画面全尺寸复核，其余通过缩略总览检查。
- `tests/exhibition_native.gd`：原生 Window 实际启动 mode=3，注入 Ctrl+Shift+F11 后切窗口、再按恢复全屏，Ctrl+Shift+Q 后进程退出。窗口模式原生截图为 1920×1080；本机全屏物理屏幕为 2880×1800，逻辑视口仍为 1920×1080。因此不能声称本机是最终 1080p 实屏。
- 无界面回归：`touch_gesture_tests`（150 项）、`opening_navigation_tests`（254 项）、`level03_input_tests`、`inspection_workspace_tests` 通过。针对放大窗再次运行 opening_navigation，通过。上述检查是引擎事件注入，不是真人手指。
- 标准 campaign classroom 阶段通过。full 阶段 340 项通过，剩余 **1 项既存失败**：`six display groups retain ten placed members`；在修改前 HEAD 的独立副本复现同一失败，属于现有三组实现与旧六组断言不一致。本次未改规则、未删除该断言，不能宣称整套测试全绿。
- `git diff --check` 通过。日志中 macOS 证书读取和沙箱编辑器设置写入警告由既有 runner 单独标记，不作产品通过依据。

原生测试后，画面检查覆盖工作区并行加入的船板圆角及科普“返回”按钮；未覆盖或回退这些改动。最终 GPU 对应的源文件哈希见 evidence/exhibition-1080/source-manifest.json。早期 headless 回归未包含这些并行改动。

## 证据

- [截图浏览页](evidence/exhibition-1080/index.html)：35 张原尺寸图。
- [GPU 报告](evidence/exhibition-1080/report.json)：图片清单、按钮实际矩形、失败与渲染后端。
- [原生全屏与维护键报告](evidence/exhibition-1080/native.json)。
- regression 子目录保留选择性回归与修改前对照的汇总/日志，保留未全绿结果。

复现 GPU：`open -g -n -W -a /Applications/Godot.app --args --path <隔离副本> --minimized --rendering-method gl_compatibility --audio-driver Dummy --script tests/exhibition_visual.gd`。截图强制绘制后直接读取，避免最小化窗口等待下一次 frame_post_draw 而停滞。原生验证去掉 `--minimized` 并使用 `tests/exhibition_native.gd`，会短暂启动全屏并自动退出。

未验证：32 寸实体屏、实际手指和硬件键盘、系统级手势/应用切换锁定、目标系统导出包、长时间压力与重启恢复。不能用本轮 GPU/注入事件测试替代最终设备验收。部署待办和维护方法见 [部署说明](../docs/current/EXHIBITION_DEPLOYMENT.md)。
