extends RefCounted
## Raw input tracks fingers; GUI delivery claims a surface. Two fingers must
## belong to the same surface. After multitouch, all fingers must lift before
## another tap/drag; lifting one or adding a third never starts a new gesture.
const MIN_SPAN := 16.0
const DISTANCE_SLOP := 2.0
var points: Dictionary = {}
var claimed: Dictionary = {}
var blocked := false
var active := false
var suppress_current := false
var _finished := false
var _distance := 0.0

func reset() -> void:
	points.clear()
	claimed.clear()
	blocked = false
	active = false
	suppress_current = false
	_finished = false
	_distance = 0.0

func feed(event: InputEvent) -> Dictionary:
	var was_blocked := blocked
	var factor := 1.0
	if event is InputEventScreenTouch:
		if event.pressed:
			points[event.index] = event.position
		else:
			points.erase(event.index)
			claimed.erase(event.index)
			if blocked:
				_finished = true
				active = false
		if points.size() > 1: blocked = true
		if points.size() > 2 or event.canceled:
			_finished = true
			active = false
		if points.is_empty(): reset()
	elif event is InputEventScreenDrag and points.has(event.index):
		points[event.index] = event.position
		if active:
			var span := _span()
			if span >= MIN_SPAN and absf(span - _distance) >= DISTANCE_SLOP:
				factor = _distance / span
				_distance = span
	suppress_current = was_blocked or blocked
	return {"interrupt": not was_blocked and blocked, "factor": factor, "suppress": suppress_current}

func claim(index: int) -> void:
	if not points.has(index): return
	claimed[index] = true
	if not _finished and not active and points.size() == 2 and claimed.size() == 2:
		_distance = _span()
		active = _distance >= MIN_SPAN

func _span() -> float:
	var values := points.values()
	return (values[0] as Vector2).distance_to(values[1]) if values.size() == 2 else 0.0
