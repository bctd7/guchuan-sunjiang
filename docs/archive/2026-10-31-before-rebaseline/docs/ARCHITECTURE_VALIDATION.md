> 历史归档（2026-10-31 整理）。原路径：`docs/ARCHITECTURE_VALIDATION.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

> 最终收尾更新：以下保留阶段性历史记录。字体首导现已通过原生 FontFile 修复，临时 import_clean.py 已移除；当前九模型清理、最终验证范围与剩余五项旧静态审核失败请以 [FINAL_HANDOFF.md](FINAL_HANDOFF.md) 为准。

# 架构迁移测试记录

最终源码快照：final-source-sha256.json，191 个源码、场景和配置条目；完成测试后与实际工程逐一复核，变化：[]。

## 结果

迁移前后各执行 26 个测试调用：23 通过，3 既有失败；二次资源导入均通过。全部调用状态相同，失败 ERROR/FAIL 文本逐条相同，未发现本次迁移新增回归。不能宣称全测试通过。

既有失败：force_gallery 12项（粽角自动模式切换/循环），force_sequence 1项（cross_lap retained cases），静态 education 5项（粽角分离门控/原始接触面）。本次不改行为或测试断言以消除它们。

关键通过：九模型 core 993/0、碰撞145/0、真实 Viewport 拖动893/0；首关输入1241/0、二关输入370/0、三关输入155/0；课堂410/0；全 campaign447/0，课堂导航另外124/0，重进141/0（9个入口记录）。首关失败矩阵、故事、字体等见日志。这里是自动注入鼠标/触摸事件，不是人手硬件验收。

GPU：迁移前后各用 macOS open -g -n -W 后台新实例、最小化、NO_FOCUS 夹具执行木材/课堂25张和失败流程7张截图；4个报告都 fresh、0失败、macOS renderer、host_had_focus=false。32对 PNG SHA256完全一致，覆盖本轮截取状态；不代表所有可能状态的穷举视觉等价。

## 证据

- baseline-isolated-results-retry/summary.json
- final-results-retry/summary.json
- baseline-final-comparison.json
- gpu-results/summary.json
- gpu-results/image-comparison.json
- final-source-sha256.json

## 环境与限制

最初受限基线 core 2套仅因 user:// fixture 无写权限失败。macOS不采用 XDG 重定向；改用临时副本 override.cfg 的唯一 custom_user_dir_name，隔离目录为 /Users/bilibili/Library/Application Support/GuchuanMigrationBaseline-20261031 和 GuchuanMigrationFinal-20261031。未使用 HOME 覆盖、未覆盖游戏原用户数据。

干净 .godot 首次导入在字体尚未导入前报 default_font.tres 缓存缺失，baseline与final相同。已保留首轮日志并二次同命令导入通过。runner保留严格检查，尚未自动重试此特例。

runner tests/run_suite.py 支持 --group core/levels/classroom/campaign/all，all排除visual，--project、--output、--timeout、--user-data-name；最后一个选项只用于临时项目，拒绝覆盖现有override.cfg。现有夹具会写res://报告，务必使用副本。视觉runner仅minimized；本轮使用gpu_compare.py的后台launcher保障不抢焦点。
