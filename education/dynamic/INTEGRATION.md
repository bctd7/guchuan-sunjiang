# 最小入口接线（由结构任务合入）

本任务只新增 `education/dynamic/`，没有改 workshop、core、models、catalog 或 project.godot。保留旧三维模块的隐藏状态，不把旧 presenter 重新显示。

在 `demo/workshop.gd` 常量/变量区新增：

```gdscript
const DynamicScience = preload("res://education/dynamic/presenter.gd")
var dynamic_science: CanvasLayer
```

在 `_ready()` 的 `_build_ui()` 调用前，assembly、interaction 已创建后新增：

```gdscript
dynamic_science = DynamicScience.new()
add_child(dynamic_science) # assembly 的兄弟节点
var previous_interaction_mode: int = interaction.process_mode
dynamic_science.lesson_visibility_changed.connect(func(is_open: bool):
    if is_open:
        interaction.cancel() # 释放拖动所有权，防止后台继续操纵木件
        interaction.process_mode = Node.PROCESS_MODE_DISABLED
    else:
        interaction.process_mode = previous_interaction_mode)
```

在 `_build_ui()` 中辅助面板 `box` 已创建后，插入：

```gdscript
box.add_child(dynamic_science.create_entry_button(assembly))
```

入口只在 catalog id 为 `dovetail` 时显示；不提供其他模型的猜测结论。modal 覆盖游戏 UI，Esc / 关闭隐藏后回到原工作台。`assembly.changed` 检测到其他模型时关闭演示，防止切换模型后保留错误标题；同一燕尾模型的普通刷新不关闭演示。没有更改 assembly 的木件姿态、状态或项目入口。宿主仍需验证一次实际入口与其最新改动的兼容性；本任务的 FakeAssembly 测试覆盖信号契约，不能替代最终工作台联调。

独立查看：用 Godot 运行 `res://education/dynamic/demo.tscn`，关闭后点击左上入口可重复打开。

