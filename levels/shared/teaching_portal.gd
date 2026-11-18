extends CanvasLayer
## A read-only doorway into the original lessons; owns no ship or campaign state.
const Friendly = preload("res://shared/ui/friendly_theme.gd")
const ModelPreview=preload("res://classroom/display/lesson_model_preview.gd")
const SourcePresentation = preload("res://shared/source_presentation.gd")
const Workshop = preload("res://classroom/classroom.gd")
const CHAPTER_LESSONS := {
	1: ["dovetail", "blind_tenon", "through_tenon"],
	2: ["cross_lap", "tongue_groove", "three_way_lap"],
	3: ["zong_corner", "clamp_head", "l_through"]
}
const LESSON_COPY = preload("res://classroom/content/lesson_copy.gd").LESSON_COPY
const Introduction = preload("res://classroom/introduction/lesson_intro.gd")

var opened := false
var workshop: Node3D
var start_button: Button
var lesson_buttons: Dictionary = {}
var back_button: Button
var source_view: Node3D
var source_panel: CanvasLayer
var source_interaction: Node
var chapter := 1
var lesson_ids: Array[String] = []
var previews: Dictionary = {}
var _intro: Control
var _heading: Label
var _scroll: ScrollContainer
var _cards: GridContainer
var _started := false
var _source_session = SourcePresentation.new()

func _ready() -> void:
	layer = 40
	_build_ui()
	_intro.hide()
	back_button.hide()

func configure(value: int, view: Node3D, panel: CanvasLayer, interaction: Node = null) -> void:
	if modal_open(): _leave_intro()
	chapter = clampi(value, 1, 3)
	source_view = view
	source_panel = panel
	source_interaction = interaction
	lesson_ids.assign(CHAPTER_LESSONS[chapter])
	_started = false
	_build_cards()
	show_intro()

func modal_open() -> bool:
	return opened or is_instance_valid(workshop)

func show_intro() -> void:
	if not is_instance_valid(_intro): return
	_close_workshop()
	_suspend_source()
	opened = true
	_heading.text = "第 %d 关 · 先认识这三种榫卯" % chapter
	start_button.text = "返回本关搭建" if _started else "开始本关"
	_intro.show()
	back_button.hide()
	start_button.grab_focus()

func _build_ui() -> void:
	_intro = Introduction.new()
	add_child(_intro)
	start_button = _intro.start_button
	_heading = _intro._heading
	_scroll = _intro._scroll
	_cards = _intro._cards
	lesson_buttons = _intro.lesson_buttons
	previews = _intro.previews
	_intro.start_requested.connect(_leave_intro)
	_intro.lesson_requested.connect(_open_lesson)
	back_button=Button.new()
	back_button.name="BackToChapterIntroduction"
	back_button.text="返回本关三种介绍"
	back_button.theme=Friendly.make_theme(true)
	back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back_button.offset_left=-250
	back_button.offset_right=-20
	back_button.offset_top=16
	back_button.offset_bottom=80
	back_button.pressed.connect(show_intro)
	add_child(back_button)


func _build_cards() -> void:
	_intro.configure(lesson_ids)

func _layout_cards() -> void:
	_intro._layout_cards()

func _open_lesson(id: String) -> void:
	if not lesson_ids.has(id): return
	_close_workshop()
	_suspend_source()
	opened = false
	_intro.hide()
	workshop = Workshop.new()
	workshop.name = "ChapterWorkshop"
	workshop.lesson_filter.assign(lesson_ids)
	add_child(workshop)
	workshop.modal_changed.connect(_sync_classroom_back_button)
	workshop.open_joint(id)
	back_button.show()
	back_button.grab_focus()

func _sync_classroom_back_button(_visible: bool) -> void:
	# The classroom return must never cover the active lesson's close control.
	back_button.visible=is_instance_valid(workshop) and not workshop.modal_open()

func _close_workshop() -> void:
	if not is_instance_valid(workshop): return
	# CanvasLayer descendants do not inherit a Node3D's visibility. Free the
	# complete embedded classroom before revealing the introduction again.
	remove_child(workshop)
	workshop.queue_free()
	workshop = null
	back_button.hide()
	_restore_camera()

func _suspend_source() -> void:
	_source_session.suspend(source_view,source_panel,source_interaction,get_viewport())

func _restore_camera() -> void:
	_source_session.restore_camera()

func _restore_source() -> void:
	_source_session.restore()

func _leave_intro() -> void:
	_close_workshop()
	opened = false
	_started = true
	_intro.hide()
	back_button.hide()
	_restore_source()

func _unhandled_key_input(event: InputEvent) -> void:
	if modal_open() and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(workshop): show_intro()
		else: _leave_intro()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_restore_source()
