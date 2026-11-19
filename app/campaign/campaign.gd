extends Node
const ExhibitLayout=preload("res://components/ui/exhibition_layout.gd")
signal load_failed(chapter: int,reason: String)
const MENU_HINT := ""
const IntroductionLayout=preload("res://components/teaching/classroom/introduction/lesson_intro.gd")
const MenuView = preload("res://app/campaign/menu_view.gd")
const ExhibitionController = preload("res://app/exhibition.gd")
@onready var _exhibition: ExhibitionController = get_node("/root/Exhibition")
var menu_status: Label
var last_load_error: Dictionary={}
## Navigation owns no joinery rules; directory exit ends only the active round.
const Friendly = preload("res://components/ui/friendly_theme.gd")
const CHAPTERS := [
	{"title":"第一关 · 龙骨立架","description":"三次不同示范，自动补齐同构件\n观察榫头与槽口，搭稳一段骨架。","scene":"res://levels/level01/level01.tscn"},
	{"title":"第二关 · 船板合壳","description":"从船底铺向船舷\n看清板端错缝，装好隔舱并试水。","scene":"res://levels/level02/level02.tscn"},
	{"title":"第三关 · 帆樯舾装","description":"桅座、帆桁与尾部舵架\n固定的榫卯连接，独立可转的舵轴。","scene":"res://levels/level03/level03.tscn"}
]
var current_chapter: ShipChapter
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
	var welcome=preload("res://app/startup/startup.tscn").instantiate()
	welcome.replay_mode=true
	welcome.replay_finished.connect(func():
		remove_child(replay_layer)
		replay_layer.queue_free()
		replay_layer=null
		menu.show()
		menu_root.replay_button.grab_focus()
		_exhibition.reset_idle_window()
	)
	menu.hide()
	replay_layer.add_child(welcome)
	_exhibition.reset_idle_window()

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
	next_button.pressed.connect(_next_chapter)
	navigation_root.add_child(next_button)
	navigation.hide()

func _load_chapter(number: int) -> PackedScene:
	var path: String=CHAPTERS[number-1].scene
	return load(path) as PackedScene if ResourceLoader.exists(path,"PackedScene") else null

func _load_failure(number: int,reason: String) -> void:
	last_load_error={"chapter":number,"reason":reason}
	menu_status.text="这一关暂时无法打开，请重试。"
	next_button.tooltip_text=menu_status.text
	load_failed.emit(number,reason)
	push_warning("Chapter %d was not opened: %s"%[number,reason])

func open_level(number: int) -> void:
	if number < 1 or number > CHAPTERS.size() or number == active_level:
		return
	var packed := _load_chapter(number)
	if packed == null:
		_load_failure(number, "scene_unavailable")
		return
	var scene := packed.instantiate()
	var chapter := scene as ShipChapter
	if chapter == null or chapter.chapter_number != number:
		if scene != null:
			scene.free()
		_load_failure(number, "invalid_chapter_contract")
		return

	_release_chapter()
	current_chapter = chapter
	active_level = number
	chapter.directory_managed = true
	chapter.return_requested.connect(_show_menu)
	chapter.next_requested.connect(_next_chapter)
	chapter.completion_changed.connect(_chapter_completion_changed)
	chapter.navigation_changed.connect(_update_navigation)
	last_load_error.clear()
	menu_status.text = MENU_HINT
	next_button.tooltip_text = ""
	menu.hide()
	add_child(chapter)
	_chapter_completion_changed(chapter.is_completed())

func _next_chapter() -> void:
	if active_level < CHAPTERS.size() and current_chapter.is_completed():
		open_level(active_level + 1)

func _chapter_completion_changed(value: bool) -> void:
	completed[active_level] = value
	_update_badges()
	_update_navigation()

func _update_badges() -> void:
	for id in chapter_buttons:
		chapter_buttons[id].text = "✓ 已完成 · 再次进入  →" if completed.get(id, false) else "进入关卡  →"

func _release_chapter() -> void:
	if current_chapter == null:
		return
	var leaving := current_chapter
	current_chapter = null
	active_level = 0
	leaving.leave()
	remove_child(leaving)
	leaving.queue_free()

func _show_menu() -> void:
	completed.erase(active_level)
	_release_chapter()
	_update_badges()
	menu.show()
	navigation.hide()

func _update_navigation() -> void:
	if current_chapter == null:
		return
	var status := current_chapter.navigation_status()
	var intro_open: bool = status.intro_open
	# The chapter introduction shares the workshop's existing directory return.
	# Other teaching, story and result modals retain their own navigation.
	navigation.visible=not status.modal_open or intro_open
	back_button.text="返回主界面" if intro_open else "返回关卡目录"
	# Introduction content is viewport-anchored; map its shared right margin
	# back into the scaled workshop navigation coordinates.
	if intro_open:
		var right_edge:=get_viewport().get_visible_rect().size.x-IntroductionLayout.SIDE_MARGIN
		var local_edge:=navigation_root.get_global_transform_with_canvas().affine_inverse()*Vector2(right_edge,0)
		back_button.position.x=local_edge.x-back_button.size.x
	else:
		back_button.position.x=1244
	back_button.disabled=not status.can_leave
	next_button.visible=not intro_open and active_level<3 and completed.get(active_level,false)

	if next_button.visible:
		next_button.text = "进入第%d关" % (active_level + 1)

func _fit_layout() -> void:
	var dimensions:=get_viewport().get_visible_rect().size
	menu_root.fit(dimensions)
	ExhibitLayout.fit(navigation_root,dimensions)
	_update_navigation()
