# 视角复位入口（2026-11-17）
保留既有工作区修改，仅调整相机入口及布局。

- 公共 inspection_workspace 为模型下方预留独立操作行，第一、二关观察页共用。inspection_zoom_bar 将复位按钮移入右端，160×64 逻辑像素，实际1080p为192×76.8或更高，与上方缩放栏分离。
- model_magnifier 在模型外底部右端放置同名按钮，缩放组在左。复用 preview.reset_view。
- 第二关新增 camera_reset_requested，只重置 inspection_camera；不再调用重新观察回调。候选开口卡仍全部同步 reset_view。重新观察保留原功能。
- 单榫卯课堂按钮统一名称，保留原固定左侧工具栏位置和 _reset_view 回调。
- 第三关固定取景主模型不增加相机按钮；未改动船壳、导航、装配规则。

验证环境：隔离副本 /private/tmp/guchuan-camera，Godot 4.7.2。
exhibition_visual 实际GPU、1920×1080，三关/观察/课堂/放大/科普/第三关完成流程，0失败，截图见本目录 evidence/camera-reset。
camera_reset_tests 专项覆盖缩放、克隆旋转与复位、鼠标/模拟触摸、浅推木件位置、选材及进度保留。
完整 level02_clarity_zoom_tests 返回368通过、17失败，失败集中在后续整船拖动装配流程（motion finishes及后续不可操作）；尚未完成基线对照，不能声称完整第二关装配回归通过。
未完成第一关所有状态及第二关部分拼装/完成状态的复位专项验收；未验证实体32寸触屏。课堂入口此次保留左侧布局，未迁移至右下角。
