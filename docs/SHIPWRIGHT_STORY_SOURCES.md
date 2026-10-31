> 技术资料：描述现有模块或资料来源，不定义最新关卡需求或完成状态。最新要求与差异见[文档入口](README.md)（2026-10-31 整理）。

# 第一关可选船匠小故事

当前版本核实日期：2026-10-31。第一关可选故事“龙骨里的七星伴月”；只读弹层，不改变装配状态或其他关卡。

## 官方一级来源

- 闽南文化生态保护区·泉州文史资料全文库：[后渚港宋代海船](https://www.mnwhstq.com/szzy/qzwszlqwk/201608/t20160816_106901.htm)。2026-10-31 已读取正文。“保寿孔”一节记载主龙骨接头横断面的七个小孔及一个大圆孔，小孔置钱币、大孔置铜镜，排列状若北斗星与满月，象征吉祥。仅采用这一文物线索及平安寓意。
- 央视网央博：[福船的故事：从泉州驶向马六甲展](https://yangbo.cctv.cn/2023/05/17/ARTIRg9Wi0rjFuBtb2cRw0GE230517.shtml)。泉州海外交通史博物馆承办展览的展品介绍，正文说明宋船龙骨衔接处七个小槽内放钱币、大槽内放铜镜。2026-10-31 已读取正文，与上一来源交叉核对。

以下水密隔舱来源为此前故事的研究留档，当前七星伴月文本没有采用其工艺细节：

- 中国非物质文化遗产网·中国非物质文化遗产数字博物馆：[中国水密隔舱福船制造技艺](https://www.ihchina.cn/directory_details/11847)。检索结果正文说明榫接是木板槽舌接合，艌缝使用苎麻、桐油、石灰等作为板缝堵塞材料。页面直开超时，搜索工具可读到上述正文。
- 同站国家级项目条目：[水密隔舱福船制造技艺，项目编号Ⅷ-138](https://www.ihchina.cn/project_details/14574.html)。正文说明以横隔板分隔舱位，增加船体强度；板间缝隙用桐油灰与麻绳艌密。此页正文已获取。面板采用保守表述“帮助限制进水范围”，不作永不沉没保证。
- UNESCO：[Watertight-bulkhead technology of Chinese junks，00321](https://ich.unesco.org/en/USL/watertight-bulkhead-technology-of-chinese-junks-00321)。本次直开遇验证码，未把不可读正文当作核实依据。官方[照片条目](https://ich.unesco.org/en/photo-pop-up-00973?photoID=07629)检索可读到项目名称及2010年列入急需保护名录信息；面板没有采用年份/名录现状，避免以旧名录状态暗示当前状态。

## 创作边界

首段为有来源的文物线索；其后五段以“想象一个造船的早晨”进入故事，并在人物登场前明确提示“下面的小帮手阿禾、师傅和他们的对话，是我们想象的故事”。人物、船场声响、对话与动作均为创作，不冒充真实人物或历史引语。

文案面向7岁以上读者，用数钱币、长柄勺子和船底脊梁等具体画面解释七星伴月。祝福只表达心愿，没有神奇保护或必然安全的承诺。接头牢固、留心天气与掌舵为故事中的一般常识，不声称游戏榫卯就是宋船的实物用法。既有插图及“非精确考古复原”图注保留，图片展示位置不充作孔位考古复原。

视觉上保留上图下文与单个关闭按钮，增加图片圆角、标题层次、柔和阅读底色与段间距；正文滚动，标题和关闭按钮固定。

## API 与连接建议

```gdscript
const Story = preload("res://levels/level01/shipwright_story.gd")
var story = Story.new()
add_child(story)
story.show_story(interaction) # 调用前确保其他模态页未打开；同次打开重复调用无操作。
story.close()               # 可重复调用；未打开时无操作。
```

- `CanvasLayer.layer = 35`，公开 `opened: bool`、`close_button: Button`、`root: Control`，`closed` 信号。
- `show_story(source_interaction: Node = null)` 可无来源调用。指定来源时保存并禁用 input、unhandled_input、unhandled_key_input、shortcut_input 四类开关；若来源有 `cancel()`，清除未完成指针手势。关闭按钮或 Esc 精确恢复四个开关及先前可见控件的焦点。来源已释放时安全跳过恢复。退出树时同样恢复输入。
- 根控件与柔和遮罩均全屏 `MOUSE_FILTER_STOP`，禁止滚轮向下传递；内容可滚动，关闭按钮固定在正文外。只读内容不持有装配状态、模型、镜头或关卡引用，不暂停 SceneTree、不替换模型、不新增必做流程。
- 关卡调用方负责模态互斥；传入的是 socket interaction，不会修改其余节点或摄像机输入设置。用于本项目的第一关视图不声明 `_input` / `_unhandled_input`；如移植到在 `_input` 中处理指针的其他视图，调用方应额外管理该视图输入。

## 验证

2026-10-31 当前版本：Godot 4.7.2，headless 控件/生命周期检查 89 项通过；最小化 NO_FOCUS GPU 实际渲染检查 32 项通过。覆盖 1440×900、1100×700、960×600 的起始与末尾截图、图片比例、真实滚轮滚动到最后一段、固定关闭按钮、点击关闭后重开及 Esc 关闭。GPU 报告：`tests/evidence/seven-stars/report.json`。截图已实际查看；这是离屏 GPU 和 Viewport GUI 事件验证，不声称人工物理鼠标操作。

下方为早期独立弹层验证记录：

`tests/shipwright_story_tests.gd` 为 headless 控件/生命周期验证，不声称进行了人工界面验证。运行方式：

```powershell
& 'C:\Users\27902\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/shipwright_story_tests.gd
```

验证覆盖16种原输入开关组合、重复打开/关闭、遮罩阻断底层按钮、Esc、焦点往返、1440×900与960×600关闭按钮在视口内、来源释放、开放面板移除时恢复输入，以及镜头/装配数据/模型位置不变。缩放测试同步设置 `Window.content_scale_size`，以测试实际逻辑视口尺寸。

最终运行：Godot 4.7.2，`SHIPWRIGHT STORY: 80 passed, 0 failed`，退出码0。为了在受限环境避免默认 user:// 日志目录不可写，实际执行额外指定 `--log-file C:\Users\27902\AppData\Local\Temp\shipwright-story-headless.log`；最终日志无错误。没有打开或操作前台桌面。
