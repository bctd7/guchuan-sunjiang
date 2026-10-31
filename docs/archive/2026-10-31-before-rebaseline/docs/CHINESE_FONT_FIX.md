> 历史归档（2026-10-31 整理）。原路径：`docs/CHINESE_FONT_FIX.md`。下文“当前/最终/待办”均指记录当时，不作为最新产品要求或本轮验收结果。请从[文档入口](../../../current/README.md)阅读最新需求和现状。正文保留；相对链接按归档位置调整。

# 中文字体显示修复（Mac，2026-10-31）

用户反馈截图已通过 Library 支持流程获取并实际查看。截图中故事中文的字形、字重混杂；剧情文本编码正常，没有修改用户认可的六段内容。

## 根因与修复

原 `friendly_theme.gd` 只声明 Microsoft YaHei UI、Microsoft YaHei、Noto Sans CJK SC。这三个字体在测试 Mac 上都未安装，运行时主字体实际显示为 Open Sans SemiBold，中文依赖后续逐字系统回退。长度对照图也单独声明了未安装的微软雅黑，部分教学界面另有系统字体工厂。

统一使用项目自带 `shared/fonts/NotoSansSC-Variable.ttf`，通过 `shared/chinese_fonts.gd` 固定 400/500/600 的 wght 轴。项目默认字体、共用主题、教学样式工厂、故事、长度对照图都接到同一字体；默认字体同时覆盖无独立主题的控件与 Label3D。

字体来自 Google Fonts 官方仓库，保持原始字节，没有从 macOS 系统字体复制或重新打包。变量字体名称元数据含 Thin，但渲染时轴值已验证为 400/500/600，并非按 Thin 渲染。

- 官方元数据：https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/METADATA.pb
- 字体：https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf
- 许可：`shared/fonts/OFL.txt`（SIL OFL 1.1，随字体保留）
- SHA-256：`a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`

保留全项目原文案、布局、图片、模型与材质。仅故事正文从 22px 调到 24px，行距从 7 调到 8；小标题/说明文字略增大。关闭按钮与 Esc、滚动、输入恢复保持原行为。

## 验证

- 全项目源码中的 671 个中文/全角标点字符，在 400/500/600 三种字重的主字体内均有字形，无需系统字体补齐。
- `tests/chinese_font_tests.gd`：headless 3177 项通过；实际 Mac OpenGL GPU 3200 项通过，0 失败。
- 实际遍历并渲染 22 个界面：主目录，三关介绍与搭建，九种榫卯教学，燕尾/粽角受力弹层、第一关观察器、故事、第一/二关失败弹层。弹层调用只验证 UI 显示，不冒充关卡失败规则测试。
- 故事生命周期检查 89 项通过；GPU 32 项通过，覆盖 1440×900、1100×700、960×600 的图文、实际滚轮到最后一段、固定关闭按钮与 Esc。
- 现有 campaign classroom 导航检查 124 项通过，实际 Viewport 鼠标事件覆盖三关九种教学入口、返回与状态保留；报告另存 `tests/evidence/chinese-fonts/campaign-classroom-report.json`，未覆盖原 campaign 报告。
- 图像与报告：`tests/evidence/chinese-fonts/`；故事三尺寸截图：`tests/evidence/seven-stars/`。渲染宿主最小化、不获取焦点，操作通过 Viewport 事件进行，不声称人工硬件测试。

仅在当前 Mac 环境实际渲染；Windows/Web 未运行。项目自带字体消除了安装字体差异，其他平台仍应在导出版本验收。
