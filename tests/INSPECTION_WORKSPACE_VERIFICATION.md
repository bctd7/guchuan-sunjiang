# 统一观察页与真实开口验证

> 后续界面精简：第二关黄色圆圈与船体点击入口已移除，改为仅从任务卡进入；错榫型也改为允许试装并延后至整关试浪判断。当前证据见 [入口与错型试装记录](LEVEL02_MARKER_REMOVAL_VERIFICATION.md)；下文保留上一阶段测试与画面。

日期：2026-11-01。范围为本轮未提交工作树，正式源文件逐文件 SHA-256 见 [source-manifest.json](evidence/inspection-workspace/source-manifest.json)。本记录取代此前辅助卡/精简阶段对当前界面的描述，历史报告仍保留。

## 已完成的本轮变更

- 第一关新增辅助面板撤去，故事与同类木料补齐说明恢复原任务卡。保留既有缩放、目录入口、原长度/错型/自动补齐规则与来源记录。
- 两关使用同一 `inspection_workspace.gd` 页框及相同的顶栏、三候选区、观察区、右侧选材和底栏位置。第一关相机逻辑提取为共享 `inspection_orbit.gd`，第一关保留兼容入口，未复制其玩法到第二关。
- 第二关删除总览浮动指令。点击船体当前安装点或任务卡进入局部，候选可旋转；同型三件木料**外尺寸相同，实际开口位置不同**，不再采用已撤销的长短方案。右侧放大真实接合特征，扣合候选横向观察槽口，隔舱板聚焦底部凹口。
- 第二关同一 hull_view 在总览/局部 World3D 之间挂接，不复制状态；返回、教学、目录、重开恢复输入/呈现。抓住木料推装，拖空白旋转，候选拖转与点选分离；多指/失焦取消。旋转后重算真实范围，包含偏心三向木料，箭头逐帧跟随镜头。
- 开口与板端排布独立。保留十件/六组、同排连续安装、实际上下排接缝和逐件撤回。错误榫型仍拒装；同型错误开口允许试装，保留未密合间隙，全部十件落位后试浪，在实际错误连接处展示漏水并统一失败。正确开口和错缝均满足才能完成。
- 保留并合并并行文案的八个文件；涉及本轮变化的文件采用三方合并/再对照，未用旧副本覆盖文案。记录见 [concurrent-merge.json](evidence/inspection-workspace/concurrent-merge.json)。

## 自动和 GPU 结果

设备/环境：Mac Apple M1，Godot 4.7.2，原生 macOS Compatibility/OpenGL；隔离 user-data，后台 GPU 最小化且不聚焦。Viewport 注入真实 Godot 鼠标与模拟触摸事件，不直接写业务状态，不等于真人输入。

| 验证 | 结果 | 主要证据 |
|---|---|---|
| 最新观察页，无界面 | 1297 通过，0 失败 | [headless.json](evidence/inspection-workspace/headless.json) |
| 最新观察页，Mac GPU | 1283 通过，0 失败；host_had_focus=false | [gpu.json](evidence/inspection-workspace/gpu.json)，12 张画面 |
| 浅推/错缝/试浪，无界面 | 629 通过，0 失败 | [drag-headless.json](evidence/inspection-workspace/drag-headless.json) |
| 浅推/错缝/试浪，Mac GPU | 629 通过，0 失败；host_had_focus=false | [drag-gpu.json](evidence/inspection-workspace/drag-gpu.json)，24 张画面 |
| 实际开口几何 | 36 通过，0 失败 | [opening-geometry.json](evidence/inspection-workspace/opening-geometry.json) |
| 跨关回归 | 13 组通过 | [regression.json](evidence/inspection-workspace/regression.json) |

观察页覆盖：同一 campaign 中进入两关；实际总览与局部控件矩形相等；候选鼠标/触摸旋转不误选，双指跨卡不选择，主模型旋转不装配/不改几何，全部可见木料在观察区；课堂返回、局部/总览渲染切换；四种错误开口完成十件后对应漏水失败；正确开口+错缝完成；撤回保留其余九件并重新选择；1100×800、960×600 下触摸浅推及返回可达。

拖动补充覆盖：1440×900、1100×800、960×600 的实际模型端缝靠左/靠右、标记锚定、接收件淡化、浅推/继续/抽回、混合鼠标/模拟触摸、整关正确和对齐错缝失败、动态浪峰/水滴、失败锁定、小课堂、失焦/双指取消、试浪中重开与旧回调失效、节点释放。截图 [并排查看](evidence/inspection-workspace/compare.html)。

实体检查覆盖：船板/搭扣/隔板 BoxMesh 相交、三向扣合裁切多边形相交，正确开口清空接合体积、错误位置反例确有实体冲突；十件 A/B/C 均有不同实体网格但相同外包尺寸。偏移扣合撑中心及支脚抬高 0.2 模型单位以保持壳体净空。不是完整制造公差或物理求解验收。

跨关 13 组为规则35、开口实体36、既有船壳几何20、第一关输入1241、第二关输入347、第一关旋转55、第一关观察器143、任务卡工具99、三关完整目录流程445、整关失败1436、教学410、缓存重入141、字体3447。此批运行早于最后的观察区取景/预览放大修正；影响的完整观察页与拖动 GPU 已在最后源文件上重跑，其他玩法源文件不再改变。第一关/第三关/课堂回归未因取景修正再次全量运行。

通过数含逐帧等待期间的不提前验收检查，因此不同渲染器/重跑计数可不同，不能把数值差当覆盖差。

## 本轮发现并修复的问题

1. 初版 GPU 夹具在首帧尚未绘制时注入点击，已补真实绘制/鼠标移动同步；旧拖动夹具也需等待介绍布局完成。失败日志保留，未放宽产品判定。
2. 混合输入夹具触摸结束立即用鼠标点候选，命中已有 450ms 防重复事件保护；夹具等待保护结束后再换设备，所有安装/来源断言保留。并非宣称实体设备已验收。
3. 三向裁切最初未把偏移参数传到底层，已由真实实体负例发现并修复；不只验证规则表。
4. 相机转动时箭头原先不刷新，已逐帧重投影；相机围绕槽口时偏心三向木料曾被裁切，现按槽口两侧范围拟合并新增实体投影在框内断言。
5. 第一关旧断言查找已被并行文案移除的“自动”，改为现行“同类木料”，仍断言同类补齐数量/来源记录。初次失败与重跑日志均保留，未回滚文案。

导入扫描完成、无脚本解析错误。沙箱阻止保存用户全局 `editor_settings-4.7.tres`，未为此申请写用户设置；无界面另有 macOS 证书读取告警。这些环境告警与测试失败分开记录，见 logs。Python runner 采用工作区内显式 pyc 路径完成语法检查，避免默认用户缓存路径。

## 执行与保留边界

在隔离副本执行：

```sh
Godot --headless --path /隔离副本 --script tests/opening_geometry_tests.gd
Godot --headless --path /隔离副本 --script tests/inspection_workspace_tests.gd
Godot --headless --path /隔离副本 --script tests/level02_drag_tests.gd
```

Mac GPU 需通过 LaunchServices 启动带 `--minimized --rendering-method gl_compatibility --audio-driver Dummy` 的独立进程，指定对应脚本并附 `-- --gpu`。脚本在 run 内设置 NO_FOCUS 并将窗口最小化。不要操作用户正在运行的窗口。

本次完成的是用户批准的界面/开口/旋转及既有错缝试浪整合。扩大混合候选池、逐关递增干扰、卡片/成就及音效仍未实施；音效按用户要求最后统一做。Windows 导出、实体触屏/触控板、目标设备、真人对开口及错缝的理解和舒适度仍待试玩，自动/GPU 不替代这些验收。无真实流体仿真。没有提交或推送。

正式写回采用合并后基线 SHA-256 全量预检、每文件复检及原文件备份；结果另见 [integration.json](evidence/inspection-workspace/integration.json)。对正在运行的旧游戏实例不做重启，查看新版本需用户结束当前运行后重新运行场景。
