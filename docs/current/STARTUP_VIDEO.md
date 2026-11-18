> 2026-11-18 目录新增右下角“重播欢迎片”入口：点击在覆盖层播放同一欢迎视频，结束、跳过或不可用时返回原目录实例，不清空目录状态。启动自动播放流程不变。验证见 [目录改版与欢迎片重播](../../tests/MENU_REDESIGN_VERIFICATION.md)。

> 最新调整：按用户要求移除欢迎静帧页。现在启动自动播放视频，播放结束、跳过或视频不可用时，直接进入现有章节目录。没有“开始体验”和“重播介绍”中间页。保留弱化的跳过按钮、音乐恢复及重复进入保护。以下欢迎页截图与说明为此前实现记录，已不代表当前启动流程。

# 启动视频与欢迎页（2026-11-18）

入口已改为 startup/startup.tscn：自动播放介绍 → 欢迎静帧 → 开始体验 → 原 campaign/campaign.tscn。关卡内返回目录不经过启动场景。没有闲置计时、自动重播或关卡重置改动。

原始用户文件 `/Users/bilibili/Downloads/古船棹匠-探索版20s_1118_003558.mp4` 保留不变。运行只引用项目 assets/welcome/introduction.ogv 和 welcome.jpg，不依赖 Downloads。项目名称始终使用古船榫匠，Label 沿用 ReadingTranslation 注音。

## 转码与画面

使用独立 imageio-ffmpeg 9.0 二进制（包含 libtheora）：

`ffmpeg -i SOURCE.mp4 -map 0:v:0 -map 0:a:0 -c:v libtheora -q:v 7 -pix_fmt yuv420p -r 24 -c:a libvorbis -q:a 4 assets/welcome/introduction.ogv`

1920×1080、24fps、视频20.041667秒、音频20.064秒，均从0开始；总13,152,521字节（约12.54MiB）。源为10bit HEVC，转换为Theora支持的8bit；没有烘焙文字。抽查首帧、10秒、18秒、19.9秒画面及转码前后18秒，未见明显色偏；未做色度仪测量。

欢迎背景从原片18秒独立导出JPEG（约69KiB）。左上局部米白面板承载标题、简介和按钮，中央人物与右侧船体保留。统一1920×1080逻辑画布等比居中，非16:9留黑边。跳过按钮已按反馈弱化：右下220×72触摸区，22px文字、30%透明深色底，无明显阴影；悬停/按下增强至55%。

## 音频与生命周期

原声保留为Vorbis，不删除或主观宣称不适合。afplay实际播放原音轨，Godot实测CoreAudio；工具无法进行人耳主观听辨，因此没有确认环境声/音乐/对白分类，也未完成感知音画同步验收。源音轨平均-32dB、峰值-3.5dB；保守保留播放器0dB，通过既有Music总线（默认-19dB）控制，并继承音量/静音。现场可能需要按已有维护入口调节。

GameAudio.pause_for_video 只临时暂停音乐播放器，终止旧淡入Tween；结束或跳过后恢复原播放位置，以1.2秒淡入恢复。不会保存临时暂停到audio.cfg。单个VideoStreamPlayer复用，退出播放立即stop并清空stream。VIDEO/WELCOME/ENTERING守卫防重复点击；目录在开始体验后才创建，不存在输入穿透。缺资源/加载失败直接显示欢迎页；停滞超过3秒或播放超过25秒有降级保护；维护热键不拦截。

## 验证

真实GPU OpenGL与CoreAudio，tests/startup_tests.gd：0失败，覆盖自动完整结束、0.1/9/19秒跳过、重播后跳过、音乐恢复与静音/音量保持、缺失视频降级、1280×1024等比布局、开始进入目录、第一关返回目录不重播。

tests/startup_preview.gd：0失败，弱化按钮实际指针点击、各10次连续调用重播/跳过/开始的守卫测试。连续调用属于程序级边界验证，不是实体连续触屏实测。截图见 tests/evidence/startup；Mac Retina截图物理像素可能大于1920×1080逻辑画布。测试退出有ObjectDB/资源未释放警告，未声称资源泄漏验收通过。

未完成：人耳原声内容判断、主观音画同步与流畅度评价、真实32寸触屏和最终扬声器验收、损坏码流/设备中断所有分支、重播后第二次完整自然结束、带声音录屏。本次提供真实运行截图，不将转码完成或驱动存在等同于听感验收。

环境：原ffmpeg缺Theora，获批安装ffmpeg-full；过程中使用imageio-ffmpeg完成转码，随后Homebrew安装也已完成。没有更改shell PATH或升级Command Line Tools。
