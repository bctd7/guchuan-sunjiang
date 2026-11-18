> 已由后续模型重建替代，当前结果见 [曲面船壳验证](ROUNDED_HULL_VERIFICATION.md)。以下为第一轮失败原型的历史记录。

# 第二关圆润船壳：未完成，原型未合入

2026-11-17。本次读取技术架构、第二关 README、船壳承托验证、上一轮企口圆角记录及生成/接触代码。

当前项目生产代码没有应用本轮曲面修改；原有未提交修改保留。

隔离基线：`/private/tmp/hull-round-before`；实验副本：`/private/tmp/hull-round-after`。
实验新增 `models/ship/hull/rounded_shell.gd`，在世界坐标对壳板和配套肋框/支撑分段弯曲及收首尾；通过 hull_view 构建入口应用，wood_surface 保留分段接触数据。此实现已被验证否决，不能直接复制合入。

实际验证：
- Godot 导入成功；规则测试 198 通过、0 失败，仅说明规则代码未变。
- Godot GPU 导出相同三个视角的前后截图。原型端部出现明显折面/三角斑块，不满足平滑要求。
- three_group_tests 实际运行失败：船板自动补齐失败，后续测试连带失败，最终脚本因 bulkhead 未安装而异常；已结束残留进程。
- 单独从正确选材 B 开始复测也失败，最终 placed 为空。不能将首轮失败仅归因于错选材分支。
- 尚未完成候选全件一致化、局部/放大往返、曲面正确落座、下一组、错误选材兼容以及最终 GPU 交互验收。

原因：通用空间弯曲后的凸体分段与原直线插入轨迹不兼容，原有短截段候选构建也不能代表弯曲后的完整船板。后续需要在船板参数曲面与接缝切线层面建立几何及装配路径，再生成相配肋框，不能只在已有直板网格上套通用弯曲。

[相同视角对比（失败原型）](evidence/rounded-hull-prototype/compare.html)
[失败交互日志](evidence/rounded-hull-prototype/failed-groups.log)
