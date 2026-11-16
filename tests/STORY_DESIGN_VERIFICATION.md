> 状态更新：本记录中的第一关视觉方案已按用户纠正撤回；截图仅作历史存档。第一关原有文案清理保留。当前第二关方案见 [第二关故事验证](BULKHEAD_STORY_VERIFICATION.md)。

# 小故事视觉改进 · 2026-11-01

## 结果

故事页已改成与第一章船场插画协调的暖色书页。直接重用 `shipyard_background.png` 作背景、`seven_stars_story.png` 作主插画，没有生成或替换图片。原六段正文与七星伴月图意保持不变。

- 纸色底、木色正文、铜色边线和控件取代原绿灰卡片；减少嵌套面板。
- 宽屏使用左右书页：左侧标题、完整插画及原文摘句；右侧独立滚动正文。读到故事末尾仍能看到七枚钱币与铜镜。
- 低于 900 像素宽时切换上下排布，收起摘句，为正文留出空间。
- 关闭按钮固定在顶部，保留 Esc、焦点恢复、源输入状态恢复及背景输入隔离。
- 未增加防御性小字，未改变故事正文、玩法或第二关代码。

## 验证

| 检查 | 通过 | 失败 |
| --- | ---: | ---: |
| 故事生命周期、输入恢复、响应布局边界 | 108 | 0 |
| 最小化无焦点 GPU 排版与滚动 | 71 | 0 |
| 中文字体（685 个字符、22 个界面） | 3465 | 0 |

GPU 覆盖 1440×900、1280×720、1100×700、960×600、768×900 五种窗口。各尺寸保存首屏及滚动至末尾截图，检查标题单行、图文不重叠、关闭按钮可见、末段完整可读、插画纵横比与阅读时位置不变。人工查看了 1440、960、768 宽首屏以及 960 宽末屏，文字清晰，七星与铜镜保留完整。

## 隔离与整合

在独立临时副本完成修改与测试。整合前逐字比较正式工程与初始快照，确认下列三个文件没有并行变化，再合入：

- `levels/level01/shipwright_story.gd`
- `tests/shipwright_story_tests.gd`
- `tests/seven_stars_visual.gd`

合入后再次逐字核对与测试副本一致。第二关文件未写入，无冲突或剩余阻塞。未提交、未推送，未操作用户运行窗口。`git diff --check` 通过。

- [1440 宽首屏](evidence/story-design/story-1440.png)
- [960 宽首屏](evidence/story-design/story-960.png)
- [960 宽末屏](evidence/story-design/story-960-bottom.png)
- [768 宽竖向排版](evidence/story-design/story-768.png)
- [GPU 报告](evidence/story-design/report.json)
- [全部验证结果](evidence/story-design/verification-summary.json)
- [本次独立补丁](evidence/story-design/story-design-only.patch)
