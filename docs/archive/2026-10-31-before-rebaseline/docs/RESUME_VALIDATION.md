> 历史归档（2026-10-31 整理）。原路径：`docs/RESUME_VALIDATION.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 九模型科普与字体续检（2026-10-31）

本轮基于未提交的正式工作树继续，未提交或推送。开始前完整备份 `task-6/checkpoints/resume-20261031-193409/project`；894 个非缓存文件 SHA256 全部核验一致。写回前逐文件比对备份，未覆盖并发修改。

## 正式课堂与静态审核工具的边界

正式课堂九种“受力演示”是 Godot Control 绘制的矢量示意动画，并非九张图片或真实力学求解。燕尾走 `classroom/science/dynamic`，另外八种走 `force_gallery`。后者 19 个来源 OBJ 路径、SHA256 与当前模型 catalog 全部一致；燕尾测试核对实际网格斜面与简化图示的对应关系，不宣称精确尺寸或应力计算。

`classroom/science/demo.tscn` 是独立静态审核工具，没有正式课堂入口。保留工具、生成器和完整测试；没有通过删除它来隐藏失败。

## 五个失败如何修复

四项失败来自旧粽角资料指定的 y=.018 水平面，在当前网格上不存在。本轮保持 xrail/zrail 观察对象，改用真实斜肩：

- 大边横材 x+y=1.008，相对角腿 x+y=.992；裁切 x=.6..8、y=.208..408、z=.4..5。
- 抹头横材 y+z=1.008，相对角腿 y+z=.992；裁切 x=.4..5、y=.208..408、z=.6..8。

每块提取 2 个原网格三角形；全部命中声明的角腿相对面。原平面容差、非空、对面、只读状态等断言保留。候选接触间隙为 .016/sqrt(2)，不是已有压力或强度数值。

第五项是显示条件不足：xrail 是游戏固定基准，reset 后自身仍到位，但角腿已经分离。增加内容数据 `required_neighbors=["leg"]`，Presenter 将其与装配依赖合并检查。角腿移走时隐藏箭头，回到位后恢复；候选面仍可单独观察。没有改 core 状态、游戏固定规则或装配路径。

用当前三个实际网格连续扫掠：两根横材分别沿 +Y 移动 .1、1.2 均无碰撞，沿 -Y .1 被阻挡，支持现有方向的几何解释；不据此推断承载力、摩擦或历史构造。新增回归覆盖上述方向与邻件缺失/恢复，静态审核最终 456 项、0 失败。生成器在新临时目录重生成，与 profiles.json 字节一致。

改动文件：静态 `build_profiles.py`、`profiles.json`、`presenter.gd`、`test_education.gd` 和 README。正式九种演示、模型、关卡玩法未改。

## 字体与跨平台

保留原生 FontFile 方案、原 TTF、OFL 和生成器。再次核对原生资源 13,290,957 字节、SHA256 040e0055a056e1ab891ae5db6fb6ddb7232104e60b14beeffa7a3a01be4aef6b；TTF SHA256 a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da。当前原生文件与已验证版本完全一致。

新的无 .godot 副本直接 headless 首次导入通过；另一个无缓存副本用实际 Mac GUI 编辑器后台最小化首次导入，通过且无错误/警告。没有使用临时移除字体配置或二次重试绕过。

当前中文检查 headless 3177/0、GPU 3200/0，扫描 670 个当前文字字形、22 个界面。字形扫描数量随本轮静态文案更新从先前671变为670。现有中文字形由内置字体覆盖，不要求安装系统字体；原资源保留 allow_system_fallback=true，不能声称未来未覆盖字符绝不使用系统回退。

Windows 无运行环境，只有静态检查：res:// 路径、内嵌字体字节、无外部字体资源依赖与 OS 绝对字体路径。未验证 Windows 实际渲染、导出包或像素一致性。

## 回归与渲染

最终冻结版本：首次无缓存导入 + 既定26组回归全部通过，27项运行记录均为 passed，日志无 ERROR/Parse Error。包括 core 993/0、碰撞145/0、拖动893/0；三关输入1241/0、370/0、155/0；课堂410/0；动态6805/0、动态鼠标集成63/0、gallery2043/0、sequence729/0、静态456/0；campaign完整流程、课堂导航与重进均通过。正式树214个源码/资源与该最终副本SHA256一致。连接恢复后重新核对上述214个文件，仍完全一致；本次未重跑测试。

另完成后台最小化 NO_FOCUS GPU：25 张九模型课堂/返回/透视画面、7 张失败/重开/通关画面、22 张中文界面，报告均无失败。54 张截图已复制到持久证据目录，避免依赖临时目录。

与早前记录的32张图片哈希比较：25张课堂全部一致，失败流程6/7一致；唯一不同为晃动动画中的截图，其夹具等待4个process_frame而非固定动画时间。该帧已目视检查、流程断言通过，未宣称32张完全等价。另实际渲染独立静态场5张，确认斜肩色块、中文解释、邻件移开隐藏箭头；host_had_focus=false。

这些是自动注入 Viewport 鼠标/触摸事件及 GPU 截图，不是实体触摸屏或人手验收。既定 suite 之外的历史夹具（如依赖旧归档的 cross_lap_view）没有全部重写/运行；不将旧历史文件冒充当前覆盖。

## 证据

持久目录 `/Users/bilibili/Documents/Codex/2026-10-31/task-6/`：

- `resume-final-results/summary.json` 和逐组日志：冻结最终源码的回归。
- `resume-static-final.log`、`inspector-split-evidence/resume-static-geometry.md` 与 static-contact 探针：真实几何与456断言。
- `resume-model-consistency.json`：19个来源网格。
- `resume-gui-cold.log`：真实 GUI 冷导入；headless 首导在回归 import.log。
- `resume-gpu-results/summary.json`、`saved-images.json`、`images/`、`classroom-comparison.json`：GPU与持久截图。
- `resume-static-gpu.json`、`resume-static-*.png`：独立审核层。
- `resume-checkpoint-verification.json`、`resume-source-verification.json`：检查点与实际测试源码一致性。
