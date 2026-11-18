# 单个榫卯展示返回按钮

两处科学展示器共用 `shared/ui/joint_return_button.gd`，文字为返回，最小尺寸 144×64，字号 28，居中。沿用继承主题、顶部独立布局及原 close 回调、ui_cancel 输入；未改进度逻辑。

在隔离副本运行 `godot --path /private/tmp/joint-return-WgcB4T --script tests/joint_return_visual.gd`，Godot 4.7.2 / Apple M1 OpenGL 实际渲染 1920×1080。夹具通过鼠标事件进入、返回、再次进入；注入非零课堂进度并比较进度/状态字典，另外发送 Esc。

前七种完成全部流程且未报告断言错误；第八种夹头榫已生成两次进入截图，但其后流程与第九种 l_through 未完成。运行停留在第三关末段，未输出最终 JSON 汇总，已终止，不能视为全套通过。截图位于 evidence/joint-return。已人工查看燕尾截图，返回按钮清晰且未覆盖模型。

未验证：32 寸实体触屏、Windows 设备、真实手指点击，以及实际手动装配后的船体进度。自动夹具的非零进度是测试注入，不代表真人拼装验收。
