# 兼容与冗余清理审计（2026-11-17）

## 实际修改
- level01/level_ui.gd：删除主界面 piece_buttons、joint_buttons、length_buttons 三个空字典。生产代码无读写；观察器中的真实选择字典保留。
- level01/assembly_drag_surface.gd：直接继承公共 inspection_orbit。删除仅转继承的 level01/inspection_orbit.gd 和 UID cynltmm2ddh06。源码、场景、资源无其他有效旧路径/UID引用；历史证据中的路径清单保留原样。
- level01_input_tests、campaign_tests：改为检查真实主界面按钮树（侧栏只有观察/故事，第一关输入测试另验证不存在选择型切换按钮），不依赖空字段。
- auxiliary_panel_tests：六组断言改成三组、十件，增加与规则表的一致性验证。
- campaign_tests：旧六组描述及截图名称改为三组；断言明确三组和十件已装记录。六块船板仍为有效规则，没有把“六块”误改成“三块”。

## 音频并行边界及暂缓
未修改音频管理、资源、总线、音量、播放触发、授权文件、project.godot、core/assembly.gd 或任何关卡协调器。
第二关 level02.gd 当前存在 seating_audio 调用，视为并行共享文件，不编辑。
- 端缝 UI：level_ui 构造位置按钮和说明；refresh_observer始终隐藏；layout_selected连接协调器中的interaction.cancel/choose_layout。用户路径不可达，但旧测试仍按 layout_buttons 点击。后续须同批删除构造/字段/刷新/信号/协调器连接，并把旧测试迁到“自动错缝排布与state.layouts记录”验证；不能删除船板生成、判定、试浪记录。此次整链暂缓，不留半条接口。
- 手动海浪按钮：构造后隐藏，check_requested连接_check，旧level02_input_tests仍直接emit按钮。自动入口位于安装完成/自动补齐完成路径，保留_trial_generation和动画finished时序。后续音频合并稳定后才同批删除按钮链并迁移旧测试。
- core/assembly：insert_part的旧instant参数有run_tests/collision_tests覆盖；Enter调用insert_part，Delete调用remove_part。can_remove=false及remove_part反馈permanent_lock是禁止拆除规则。disassembled虽不发出，但run_tests连接并断言零次数。暂不修改；以后迁移参数应同步API测试，保留Enter/Delete语义，禁止另加兼容壳。
- sea_trial：leak_rows用于wet判断；opening_points用于效果生成；loose_ids用于诊断测试。三个查询都返回副本；sea_trial_presentation_tests检查快照及不能反向修改数据，全部保留。
- 关卡缓存/导航不改；campaign_loading_tests验证失败加载、后续成功加载、缓存重入及释放。
- 历史视觉证据（tests/evidence、旧JSON报告）保留当时六组名称，不能改写成当前验证证据。

## 验证
在 /private/tmp/guchuan-cleanup 隔离副本导入，未发现脚本解析错误。宿主editor_settings写权限、系统证书、退出时资源存留警告单独记录，不等同断言通过或失败。
- cleanup_smoke_tests：三关加载、进入/返回、真实主界面选择器缺席、观察器选择器保留、公共继承路径、三组十件，0失败。
- campaign_tests默认smoke：52通过，0失败。
- campaign_loading_tests：10通过，0失败。
- level02_rules_tests：198通过，0失败。
- sea_trial_presentation_tests：6通过，0失败。
- level01_input_tests：1072通过，43失败；清理前文件恢复到独立baseline副本后同为1072/43，43条失败信息顺序与内容完全一致。主要涉及旧装配时序、按钮可用性及文案期望；未修改这些断言。
- auxiliary_panel_tests：96通过，3失败（cached card design scale、两次返回目录按钮可用性）。三组断言通过；这3项未做清理前对照，不能断言根因，更未擅自修复。
未做实体键鼠/触屏测试。未宣称全部自动补齐、试浪、撤回、重开路径通过；完整结果受现存旧测试与当前工作区行为差异限制。
- campaign_tests --phase=level03：95通过，0失败，覆盖第三关交互流程。
- campaign_tests --phase=level02：累计55个断言通过后，旧夹具把当前端缝ArrayMesh强制声明为BoxMesh而脚本中断；虽然夹具输出failed=0，本轮明确判定该套未完成，三组完成态断言也未执行。船壳正有其他工作修改，不替其回退造型或改此几何断言。
- 本轮目标文件 git diff --check 通过。
