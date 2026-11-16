# 第二关总览入口与错型延后判断验证

日期：2026-11-01。本次是在[统一观察页](INSPECTION_WORKSPACE_VERIFICATION.md)之后的增量，不用旧版“榫型拒装”说明代替当前规则。源文件 SHA-256 见 [manifest.json](evidence/level02-late-fit/manifest.json)，正式写回结果见 [integration.json](evidence/level02-late-fit/integration.json)。

## 当前行为

1. 第二关黄色圆圈、锚点及其船体点击入口已移除，船体无隐藏圆圈点击区。统一从左侧“看榫头，挑木料”进入局部，组明细只选组；返回保留选择与装配。第一关的原青色圆圈及输入路径独立，本次未修改第一关或共用输入层。
2. 三种有效榫型都可试装。错型不再即时拒绝，玩家选的真实替代木料按原路径推入，保留未密合间隙；切换构件、返回总览/目录都从已接受 joint/opening/layout 记录还原，不悄悄替换为正确模型。未选择、顺序、重复、忙碌和释放深度门槛仍保留。
3. 全部十件真实落位后才试浪。错型木料在冲击阶段实际晃动，对应接合点产生裂纹和移动水滴，然后统一失败。最终标题指出“榫型不匹配，连接松动”，说明分别列出错型、有效同型开口不合、真实板列端缝对齐；保留“重新开始”和“回到关卡目录”。
4. 错型不重复算成开口错位，也不把被替代的船板当作完整船板报告虚构错缝。只有两块均为企口船板的相邻实际板列才判断端缝；全错型船体只报告实际榫型错误。正确开口与正确错缝仍正常通过。
5. 撤回仍逐件；重开取消试浪、清除错型/开口记录、晃动名单与水滴，旧回调不完成新一轮。相机按实际替代形状重新拟合，抓取点在真实替代网格上。

## 验证结果

环境为 Mac Apple M1、Godot 4.7.2、Compatibility/OpenGL。自动 Viewport 注入鼠标和模拟触摸，未直接改业务状态；后台 GPU 窗口最小化、NO_FOCUS，未操作用户窗口。不是实体触屏/真人验收。

| 检查 | 结果 | 证据 |
|---|---|---|
| 两种错型 × 十件真实拖装、撤回、目录与重开（headless） | 1353 通过，0 失败 | [headless.json](evidence/level02-late-fit/headless.json) |
| 同上 Mac GPU | 1324 通过，0 失败；不聚焦 | [gpu.json](evidence/level02-late-fit/gpu.json)，13 张截图 |
| 规则：20 个单件错型最终判定、三类混合原因、原正确/错误错缝 | 278 通过，0 失败 | [rules.json](evidence/level02-late-fit/rules.json) |
| 第二关输入：旧圆圈位置点击不进入、任务卡按钮、错型可装可撤回、正确/对齐反例 | 353 通过，0 失败 | [输入日志](evidence/level02-late-fit/logs/wrong-type-input.log) |
| 正确/错开口全关、两关观察页、旋转、教学与小尺寸触摸 | headless 1297 / GPU 1286，0 失败 | [无界面](evidence/level02-late-fit/workspace-headless.json)、[GPU](evidence/level02-late-fit/workspace-gpu.json) |
| 浅推/抽回、正确与错误错缝、三尺寸、模拟触摸任务卡、失焦/双指、试浪取消 | 629 通过，0 失败 | [drag-headless.json](evidence/level02-late-fit/drag-headless.json) |
| 跨关与几何 | 8 组通过 | [regression.json](evidence/level02-late-fit/regression.json) |
| 故事与字体 | 故事 89、合并后字体 3471，通过且0失败 | [故事日志](evidence/level02-late-fit/logs/late-fit-story.log)、[字体日志](evidence/level02-late-fit/logs/late-fit-merged-fonts-final.log) |

并行隔舱课堂更新另补验证：合并后的任务卡/课堂输入回归99通过，原生 GPU 43通过、0失败、不聚焦；覆盖1440×900、1100×800、960×600的课堂进入、关闭、卡片/关闭按钮边界、输入恢复与一次错型触摸试装。图片及两份源文件保持正式工程原版本，未写回覆盖，见[并行文件校验](evidence/level02-late-fit/concurrent-merge.json)及[GPU报告](evidence/level02-late-fit/merged-story-gpu.json)。首次副本缺少新插图导入缓存产生资源加载错误，补齐副本资源导入后重测通过；没有把“0失败”但伴随脚本错误的早期日志算通过。

错型 GPU 检查了两轮全部十件、全部二十个可选错型实体，以及真实移动/落位、已接受模型不变回正确木料、结束前不验收、波浪中实际晃动和漏水点、实际目录往返保留失败、失败重开清理。鼠标/触摸交替使用；防触摸生成重复鼠标的保护窗口仍保留。截图可[并排查看](evidence/level02-late-fit/compare.html)。

8 组为：原船壳几何、实际开口实体、完整观察页、完整拖动、三关目录完整流程、整关失败/重开、任务卡工具、缓存重入。最后“仅判断实际完整板列”的诊断守卫之后，额外重跑规则、错型 headless/GPU 和完整拖动；其余8组为该守卫之前，正确/同型路径无行为变化。自动帧等待断言数量会随渲染速率变化，不能相加当作功能数。

过程中重新核对正式工作树与故事文件，本轮写入集合不含第一关/故事源码，也不覆盖其他线程的故事测试或报告。正式工程写回前逐文件 SHA-256 复检，并备份所有被替换文件。没有提交、推送或重启用户正在运行的实例。

## 工程边界与未验证

- 改动限第二关的 State/View/UI/协调/指针、对应回归夹具和当前文档。复用原试装/深度/整关试浪机制，不复制第一关状态机，不改第一关圆圈或第三关。
- `mismatched_joints()`、`mismatched_openings()`、`row_has_boards()`/`leaking_rows()` 为只读诊断；错误记录不提前阻塞顺序。View 读取已接受几何类型；SeaTrial 只做可取消的定性晃动/漏水，未引入工程流体或力学求解。
- 新错型用既有船用三榫实体，未扩成未定数量的教学模型候选池。音效仍按用户要求后置。
- 实体触屏、触控板、Windows、目标机器及真人理解/舒适度待验收。用户当前旧游戏实例需自行结束后重新运行才加载新源码。
