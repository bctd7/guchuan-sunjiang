extends Node
const ExhibitLayout=preload("res://shared/ui/exhibition_layout.gd")
signal load_failed(chapter: int,reason: String)
const MENU_HINT := ""
const MenuView = preload("res://campaign/menu_view.gd")
var menu_status: Label
var last_load_error: Dictionary={}
## Navigation owns no joinery rules; directory exit ends only the active round.
const Friendly = preload("res://shared/ui/friendly_theme.gd")
const CHAPTERS := [
	{"title":"第一关 · 龙骨立架","description":"三次不同示范，自动补齐同构件\n观察榫头与槽口，搭稳一段骨架。","scene":"res://levels/level01/level01.tscn"},
	{"title":"第二关 · 船板合壳","description":"从船底铺向船舷\n看清板端错缝，装好隔舱并试水。","scene":"res://levels/level02/level02.tscn"},
	{"title":"第三关 · 帆樯舾装","description":"桅座、帆桁与尾部舵架\n固定的榫卯连接，独立可转的舵轴。","scene":"res://levels/level03/level03.tscn"}
]
var instances: Dictionary = {}
var completed: Dictionary = {}
var chapter_buttons: Dictionary = {}
var active_level := 0
var menu_root: Control
var navigation_root: Control
var menu: CanvasLayer
var navigation: CanvasLayer
var back_button: Button
var next_button: Button
var replay_layer: CanvasLayer

func _ready() -> void:
	_build_menu()
	_build_navigation()
	_show_menu()
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

func _build_menu() -> void:
	menu=CanvasLayer.new()
	add_child(menu)
	var background:=ColorRect.new()
	background.color=Color("faf3e3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(background)
	var directory:=MenuView.new()
	menu.add_child(directory)
	directory.build(CHAPTERS,open_level,_replay_welcome)
	menu_root=directory
	chapter_buttons=directory.buttons
	menu_status=directory.status

func _replay_welcome() -> void:
	if active_level!=0 or is_instance_valid(replay_layer):return
	replay_layer=CanvasLayer.new()
	replay_layer.layer=110
	add_child(replay_layer)
	var welcome=preload("res://startup/startup.tscn").instantiate()
	welcome.replay_mode=true
	welcome.replay_finished.connect(func():
		replay_layer.queue_free()
		replay_layer=null
		menu.show()
		menu_root.replay_button.grab_focus()
	)
	menu.hide()
	replay_layer.add_child(welcome)

func _build_navigation() -> void:
	navigation=CanvasLayer.new()
	navigation.layer=100
	add_child(navigation)
	navigation_root=Control.new()
	navigation_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	navigation.add_child(navigation_root)
	back_button=Button.new()
	back_button.text="返回关卡目录"
	back_button.position=Vector2(1244,34)
	back_button.custom_minimum_size=Vector2(160,48)
	back_button.theme=Friendly.make_theme(true)
	back_button.add_theme_font_size_override("font_size",18)
	back_button.add_theme_stylebox_override("normal",Friendly.block(Color("f2e5cd"),Color("cab38e"),1))
	back_button.add_theme_stylebox_override("hover",Friendly.block(Color("f9eedb"),Color("bda27b"),1))
	back_button.pressed.connect(_show_menu)
	navigation_root.add_child(back_button)
	next_button=Button.new()
	next_button.position=Vector2(1020,20)
	next_button.custom_minimum_size=Vector2(190,52)
	next_button.theme=Friendly.make_theme(true)
	next_button.pressed.connect(func(): open_level(active_level+1))
	navigation_root.add_child(next_button)
	navigation.hide()

func _load_chapter(number: int) -> PackedScene:
	var path: String=CHAPTERS[number-1].scene
	return load(path) as PackedScene if ResourceLoader.exists(path,"PackedScene") else null

func _supports_chapter(level: Node) -> bool:
	if not is_instance_valid(level):return false
	for method in ["enter","leave","is_completed","navigation_status"]:
		if not level.has_method(method):return false
	return level.has_signal("return_requested") and level.has_signal("progress_changed")

func _load_failure(number: int,reason: String) -> void:
	last_load_error={"chapter":number,"reason":reason}
	menu_status.text="这一关暂时无法打开，请重试。"
	next_button.tooltip_text=menu_status.text
	load_failed.emit(number,reason)
	push_warning("Chapter %d was not opened: %s"%[number,reason])

func open_level(number: int) -> void:
	if number < 1 or number > CHAPTERS.size(): return
	var current: Node=instances.get(number)
	var created:=not is_instance_valid(current)
	if created:
		var packed:=_load_chapter(number)
		if packed==null:
			_load_failure(number,"scene_unavailable")
			return
		current=packed.instantiate()
	if not _supports_chapter(current):
		if created and is_instance_valid(current):current.free()
		_load_failure(number,"invalid_chapter_contract")
		return
	# Prepare and validate first: failure retains the current chapter/menu exactly.
	_detach_active()
	if created:
		instances[number]=current
		current.connect("return_requested",_show_menu)
		if current.has_signal("next_requested"):
			current.connect("next_requested",func():
				if active_level==number and current.is_completed() and number<3:open_level(number+1))
		current.connect("progress_changed",func(): _chapter_changed(number))
	add_child(current)
	current.enter()
	# Campaign owns the visible return control; standalone chapters keep theirs.
	var chapter_panel = current.get("panel")
	if is_instance_valid(chapter_panel) and is_instance_valid(chapter_panel.get("return_button")):
		chapter_panel.return_button.hide()
	active_level=number
	last_load_error.clear()
	menu_status.text=MENU_HINT
	next_button.tooltip_text=""
	menu.hide()
	navigation.show()
	_chapter_changed(number)

func _chapter_changed(number: int) -> void:
	var level=instances.get(number)
	if is_instance_valid(level):
		completed[number]=level.is_completed()
	for id in chapter_buttons:
		chapter_buttons[id].text="✓ 已完成 · 再次进入  →" if completed.get(id,false) else "进入关卡  →"
	next_button.visible=active_level > 0 and active_level < 3 and completed.get(active_level,false)
	if next_button.visible: next_button.text="进入第%d关" % (active_level+1)

func _detach_active() -> void:
	if active_level > 0 and instances.has(active_level):
		var level: Node=instances[active_level]
		if level.get_parent() == self:
			level.leave()
			remove_child(level)
	active_level=0

func _show_menu() -> void:
	var leaving := active_level
	var old: Node = instances.get(leaving)
	_detach_active()
	if is_instance_valid(old):
		old.process_mode=Node.PROCESS_MODE_DISABLED
		instances.erase(leaving)
		completed.erase(leaving)
		old.queue_free()
		_chapter_changed(leaving)
	menu.show()
	navigation.hide()

func _process(_delta: float) -> void:
	if active_level < 1: return
	var level=instances.get(active_level)
	if not is_instance_valid(level): return
	var status: Dictionary=level.navigation_status()
	navigation.visible=not status.modal_open
	back_button.disabled=not status.can_leave

func _label(parent: Node,text: String,font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _exit_tree() -> void:
	for level in instances.values():
		if is_instance_valid(level) and not level.is_inside_tree(): level.free()

func _fit_layout() -> void:
	var dimensions:=get_viewport().get_visible_rect().size
	menu_root.fit(dimensions)
	ExhibitLayout.fit(navigation_root,dimensions)
