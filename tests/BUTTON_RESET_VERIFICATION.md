# 按钮与目录重置验证（2026-11-17）

实现：campaign 返回目录移除并禁用旧实例、排队释放，清除该关完成标记；再次进入创建新实例。关卡内部导航保持原有来源恢复逻辑。第一、二关删除准备试装控件与独有回调；选材刷新原本即配置拖动与状态提示。第三关按钮引用 workshop_ui_style，底部撤回/重新搭建采用 148×56 最小尺寸；保留操舵功能。

在 /private/tmp/guchuan-button-reset 隔离副本运行 Godot 4.7.2：
- observer_entry_tests：13 项通过，选材无需准备按钮。
- campaign_tests level01 / level02 / level03：142 / 79 / 95 项通过，真实 Viewport 指针输入完成搭建及目录重进。
- campaign_tests classroom：126 项通过，三关讲解往返保留状态。
- campaign_reentry_tests：146 项通过，第一关部分搭建、成功、失败后目录重进清空；三关重进均显示介绍并释放旧实例。
- exhibition_visual：GPU 1920×1080，0 失败；页面、观察、科普、放大及第三关完整触摸安装/操舵；捕获的可见按钮均至少 60px，无越界。

截图及结构化报告见 evidence/button-reset。自动输入不等于真实触摸硬件验收；未在 32 寸目标机器运行。未穷举第二关所有失败分支及每一种动画中途退出竞态。退出按钮正常在忙碌期间禁用。
