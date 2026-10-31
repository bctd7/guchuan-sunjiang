# 古船榫匠

古代福船榫卯互动游戏。最新方向为识别零件、从干扰材料中选配，再通过接合动画依次完成龙骨立架、船板合壳、帆樯舾装。干扰逐关增加；第四关暂不做，旧桥梁、亭子方案作废。

**当前工程尚未满足全部最新策划。** 最新文档统一放在 [docs/current/](docs/current/README.md)：

- [技术架构](docs/current/TECHNICAL_ARCHITECTURE.md)
- [第一关详细需求：龙骨立架](docs/current/LEVEL01_REQUIREMENTS.md)
- [第二关详细需求：船板合壳](docs/current/LEVEL02_REQUIREMENTS.md)
- [第三关详细需求：帆樯舾装](docs/current/LEVEL03_REQUIREMENTS.md)

导入 `project.godot`，F5 默认进入 `campaign/campaign.tscn`；独立九种榫卯课堂入口为 `classroom/classroom.tscn`。当前三关可直接进入，本次运行保留独立进度，没有跨运行存档。

[历史归档与清理清单](docs/archive/2026-10-31-before-rebaseline/README.md)保留旧方案和阶段证据；[测试索引](tests/README.md)说明历史结果的适用范围。第二关随后已实施拖动装配、实时错缝图、试浪漏水和隔舱小课堂，见[本次验证](tests/LEVEL02_REWORK_VERIFICATION.md)。其余未定目标仍以每关文档为准；不代表全部最新策划或真人设备验收完成。
