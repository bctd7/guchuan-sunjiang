# 成功与失败结果页 — 2026-11-18

新增 levels/shared/chapter_result.gd，三关成功与前两关既有失败入口共用布局。左侧为本轮真实、可见木件的只读网格副本，右侧为结果、真实判定原因与操作。模型不带脚本、碰撞或游戏状态；已知错误木件采用暖色材质叠层，无法定位时不编造损坏。第三关展示实际最后完成的舵架工作台，不虚构完整帆船，也不新增整关失败规则。

第一、二关成功主按钮发出 next_requested，由 campaign 校验完成状态并沿原加载入口进入下一关；第三关仅返回目录。失败继续沿原重开和返回事件。原结果音效绑定复用；本轮未实听音频。结果模态期间隐藏 campaign 外层导航，不变更步骤引导。

## 验证

隔离副本 /private/tmp/guchuan-results-JDSJvv；Godot 4.7.2 / Apple M1 / OpenGL。运行 tests/result_pages_visual.gd，GPU 报告 failures=[]，日志无脚本错误。1920×1080 截图：

- [第一关成功](evidence/results/1-success.png)
- [第一关失败](evidence/results/1-failure.png)
- [第二关成功](evidence/results/2-success.png)
- [第二关失败](evidence/results/2-failure.png)
- [第三关成功](evidence/results/3-success.png)

夹具预置真实装配记录，通过第一关实际 validate_structure、第二关实际试浪动画和 validate、第三关左右操舵回调触发结果；鼠标事件经过 Viewport 点击重开、下一关、返回目录及重新进入。验证模型副本非空、按钮在屏内、模态导航、失败清除、完成状态与第三关重进重置。

边界：不是三关完整手动拼装；未穷举第二关结构/混合/中途阻挡失败，未验证实体触摸屏、Windows 导出包、快速重复点击或实际扬声器。首轮测试夹具第三关规则访问有误，修正为 state.Rules 后最终 GPU 全部通过。前期 headless 出现沙箱日志及证书警告；最终 GPU 记录单独保存。
