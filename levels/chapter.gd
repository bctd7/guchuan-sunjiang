class_name ShipChapter
extends Node3D

signal return_requested
signal next_requested
signal completion_changed(completed: bool)
signal navigation_changed

const TeachingPortal = preload("res://components/teaching/teaching_portal.gd")

var chapter_number: int
var directory_managed := false
var learning: TeachingPortal
var workbench_ready := false
var busy := false:
	set(value):
		if busy == value:
			return
		busy = value
		request_navigation_update()
var _navigation_pending := false
var _completed := false

func _ready() -> void:
	learning = TeachingPortal.new()
	add_child(learning)
	learning.start_requested.connect(_start_workbench)
	learning.presentation_changed.connect(request_navigation_update)
	learning.configure(chapter_number)

func _start_workbench() -> void:
	if workbench_ready:
		return
	_build_workbench()
	workbench_ready = true
	request_navigation_update()

func _build_workbench() -> void:
	pass

func leave() -> void:
	if workbench_ready:
		_leave_workbench()

func _leave_workbench() -> void:
	pass

func is_completed() -> bool:
	return false

func update_completion() -> void:
	var completed := is_completed()
	if completed != _completed:
		_completed = completed
		completion_changed.emit(completed)

func navigation_status() -> Dictionary:
	return {
		"intro_open": learning.opened,
		"modal_open": learning.modal_open() or (workbench_ready and _workbench_modal_open()),
		"can_leave": not busy,
	}

func _workbench_modal_open() -> bool:
	return false

func request_navigation_update() -> void:
	if _navigation_pending:
		return
	_navigation_pending = true
	_emit_navigation_changed.call_deferred()

func _emit_navigation_changed() -> void:
	_navigation_pending = false
	if is_inside_tree():
		navigation_changed.emit()
