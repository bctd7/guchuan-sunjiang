# 古船榫匠音频来源与授权

2026-11-17。本次最终资源均为项目任务中程序化生成的原创声音，不含第三方录音、采样或引用旋律；不是实录古琴。作者/制作：古船榫匠项目本次 Codex 辅助生成。可复现源码：tools/audio/generate_audio.py（固定种子 20261117）。

| 文件 | 内容 | 授权 |
|---|---|---|
| workshop_loop.ogg | 64 秒 D 五声音阶原创拨弦器乐、无歌词无鼓点，尾音环绕叠加 | 自制素材，无第三方采样授权依赖；随本项目使用、处理及打包 |
| wood_seat_0/1/2.wav | 240 毫秒低频木质模态共振与柔化接触噪声 | 同上 |

没有第三方要求的署名。建议随发行包保留本文件以记录来源；不擅自替项目权利人对外作 CC0 权利放弃，不改变项目授权。调研核实的 CC0 原始条款：https://creativecommons.org/publicdomain/zero/1.0/legalcode 。未购买或订阅任何服务。

## 实际调研但未使用的第三方素材

- Charlie Huang，Improvisation No.1，古琴自作即兴，2006-04-23，6:11。来源 https://commons.wikimedia.org/wiki/File:Improvisation_1.ogg 。原始页面明确列出 CC BY-SA 3.0 / GFDL；不是 CC0。若使用须按所选授权署名并履行相应义务。本项目没有下载、剪辑或打包该录音。
- Mrguff，Wood Knock，2016-12-02，0.929 秒。来源 https://freesound.org/people/Mrguff/sounds/369710/ 。原始页面明确列出 Creative Commons 0，并说明可复制、修改、分发、公开演奏及商业使用。下载原文件需登录；未使用账号或打包该素材。
- CC0 原始说明 https://creativecommons.org/publicdomain/zero/1.0/ ：允许复制、修改、分发、公开演奏及商业使用，并保留商标、专利及他人权利方面的限制。

调研通过实际网络检索并打开原始页面完成。未完成上述第三方素材的主观试听，不能声称听过。最终选择原创合成方案以固定音域、动态、长度及循环边界。真实 CoreAudio 播放及引擎混音记录不能代替人的听感验收。

## 处理

44.1kHz。背景源以纯合成信号产生，无环境底噪；柔化起音，稀疏旋律，中低音域，64 秒循环，跨边界叠加尾音，无拼接静音。Vorbis Ogg 编码，约 320KB。音效 16bit mono PCM WAV，三种细微自然变化，每个约 21KB；1.8ms 起音、尾部衰减至零。峰值/RMS/首尾相邻样本差记录于 analysis.json。相邻样本差并不等同于爆音测量，最终听感需人工验证。

生成：`uv run --with numpy python tools/audio/generate_audio.py`，需要 ffmpeg 的原生 vorbis 编码器。生成的 workshop_loop.wav 是处理中间文件，编码后由脚本移除；发行仅引用 Ogg 及三个音效 WAV。

ui_tap.wav：从本项目 wood_seat_0.wav 裁取 65ms，尾部 12ms 淡出，沿用同一原创来源。操作反馈经音高变化实际约 43–93ms，不改变 240ms 落座声。
