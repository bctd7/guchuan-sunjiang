# 第2关：船板合壳

入口 `res://levels/level02/level02.tscn`。

最新目标、流程、输入、成败反馈、科普、现状差距、验收与待确认统一见[本关详细需求](../../docs/current/LEVEL02_REQUIREMENTS.md)；实际模块职责见[技术架构](../../docs/current/TECHNICAL_ARCHITECTURE.md)。旧操作说明已[归档](../../docs/archive/2026-10-31-before-rebaseline/levels/level02/README.md)，不能作为当前需求。

当前操作：观察并选榫/排布后，按住真实木料沿箭头推入；浅推保留，可继续或拉回，达到深度后松手接合。十件装齐后自动试浪，最后统一判定；失败只能重新开始或回目录。实时端缝展开图随 A/B 更新，水密隔舱小课堂可独立开关。音效本轮不做。

模块：`hull_drag_interaction.gd` 输入；`hull_view.gd` 预览/装配；`seam_diagram.gd` 当前排布；`sea_trial.gd` 动效；`hull_backdrop.gd` 滩头背景；`bulkhead_lesson.gd` 科普。测试入口和证据见[改造验证](../../tests/LEVEL02_REWORK_VERIFICATION.md)。
