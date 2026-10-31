> 历史归档（2026-10-31 整理）。原路径：`docs/SCIENCE_TEST_DIAGNOSIS.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

> 最终收尾更新：以下保留阶段性历史记录。字体首导现已通过原生 FontFile 修复，临时 import_clean.py 已移除；当前九模型清理、最终验证范围与剩余五项旧静态审核失败请以 [FINAL_HANDOFF.md](FINAL_HANDOFF.md) 为准。

# 科普测试与首次导入后续核查

本轮之前的完整检查点：`/Users/bilibili/Documents/Codex/2026-10-31/task-6/checkpoints/before-followup-20261031-173446/project`，886 个非缓存文件哈希已核验。产品脚本、网格、科普数据和实际字体设置本轮均未修改。

| 问题 | 性质与根因 | 用户影响及处理 |
|---|---|---|
| force_gallery 12 项 | 旧测试按每周期一个工况读取通用 diagram.mode。现行粽角时间轴在 13.2 秒内含 X/Z 两段，绘制读取 clock.mode_index() | 未证实玩家可见问题。修正测试验证实际绘制时间轴，2043/0 |
| force_sequence 1 项 | 测试仍期望搭扣单工况；README、生成器和 profiles 已规定两根木料依次 +X/+Z 两工况 | 修正精确成员、方向和数量断言，729/0 |
| static education 4 项 | 旧粽角资料寻找 y=.018 面；当前 xrail 水平面为0/1/.94，zrail为0/1/.78，提取正确返回0三角形 | 真实静态资料缺陷。独立审核场接触色块缺失，旧方向文案不匹配；主课堂没有启用此静态模块 |
| static education 1 项 | 测试假定每个资料木件reset后都会离位，当前xrail固定；Presenter只检查装配依赖，未表达接触显示所需邻件 | 同时有旧测试假设和显示条件不足。独立审核场可能在邻件分离时仍显示固定横材箭头 |
| 首次干净导入字体 | ThemeDB先读取全局字体，TTF导入缓存尚未生成；原始检查点同样触发 | 引擎初始化顺序，非迁移断链。新增隔离副本导入引导；普通编辑器冷打开仍可能有原有首导日志 |

## 已修正并验证

只修改 tests/force_gallery_tests.gd、tests/force_sequence_tests.gd 的陈旧契约，不删除实际工况覆盖。保留输入/返回恢复检查，新增实际移动成员、方向、0.02位移、固定件和阶段边界断言。专用粽角输入39/0、模型67/0。

修正 tests/chinese_font_tests.gd 的扫描目录：原demo/education改为classroom。这是迁移后遗漏的非res路径列表。重新扫描通过3177项，覆盖671个中文字形、22个界面。

新增 tests/import_clean.py，只允许无.git的显式临时副本，拒绝源工程。资产导入期间暂时省略副本的 gui/theme/custom_font 引用，finally逐字节恢复project.godot；字体文件与override.cfg不变。导入日志严格检查ERROR，不通过忽略错误或盲目重试掩盖问题。验证一次干净导入退出0、errors为空，配置SHA恢复一致。

```sh
python3 tests/import_clean.py --project /tmp/isolated-copy --output /tmp/import-log
python3 tests/run_suite.py --project /tmp/isolated-copy --skip-import --output /tmp/test-log
```

副本须排除.git和.godot，并使用独立userdata；macOS XDG变量不能替代native userdata隔离。现有override.cfg可配置唯一custom_user_dir_name。仅用override.cfg关闭全局字体不能解决editor首导，已实验确认。正式project.godot、default_font.tres、chinese_fonts.gd和TTF导入文件逐字节未变；此前32对GPU一致性证据仍适用于未变化的产品显示代码。

## 保留的实际问题

静态education仍424条断言、5项失败。不能把接触面坐标直接从.018改成0，不能跳过粽角、删除断言或放宽几何筛选容差。需要以当前粽角定义与网格重新核定接触面、必要邻件及可动方向，同时更新profiles.json和build_profiles.py；这属于科普内容修订，超出保持现有表现的结构迁移，本轮停止在诊断与证据。

其他历史夹具不等于现行覆盖：cross_lap_view_tests依赖未包含的20261023备份，且有旧单向工况预期；其备份路径曾被迁移替换，已恢复原education路径。zong_cutaway部分仍用旧mode/cutaway接口，未宣称通过。资源扫描的其他三处缺失JSON均是测试输出文件，不是运行时模型资源。模型catalog九种、21个mesh引用及正式运行资源均存在，Python生成器语法检查通过。

## 证据

工作目录 `/Users/bilibili/Documents/Codex/2026-10-31/task-6`：science-test-fix/DIAGNOSIS.md及四份重测日志；inspector-split-evidence/static-science-diagnosis.log；font-bootstrap目录中的原始首导/复导/引导日志及配置恢复摘要。完整迁移前后历史回归见ARCHITECTURE_VALIDATION.md；本轮是针对性补充验证，没有把所有旧夹具声明为通过。
