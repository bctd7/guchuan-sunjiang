class_name JoineryInsertionPath
extends RefCounted
## Pure model-space polyline math. No scene, input, UI or animation ownership.
var points: Array[Vector3] = []
var cumulative: Array[float] = [0.0]
var length := 0.0

func _init(values: Array = []) -> void:
	for value in values:
		var point := Vector3(float(value[0]), float(value[1]), float(value[2]))
		if not points.is_empty():
			if point.is_equal_approx(points[-1]): continue
			length += points[-1].distance_to(point)
			cumulative.append(length)
		points.append(point)

func valid() -> bool:
	return points.size() >= 2 and length > 0.00001

func sample(progress: float) -> Vector3:
	var value := clampf(progress, 0.0, length)
	for i in range(1, points.size()):
		if value <= cumulative[i]:
			return points[i - 1].lerp(points[i], (value - cumulative[i - 1]) / (cumulative[i] - cumulative[i - 1]))
	return points[-1] if not points.is_empty() else Vector3.ZERO

func tangent(progress: float) -> Vector3:
	for i in range(1, points.size()):
		if progress < cumulative[i] - 0.00001: return (points[i] - points[i - 1]).normalized()
	return (points[-1] - points[-2]).normalized() if valid() else Vector3.ZERO

func traversal(from: float, to: float) -> Array[Vector3]:
	# Every intervening corner is retained, including a reverse drag across turns.
	var result: Array[Vector3] = []
	if to >= from:
		for i in range(1, points.size()):
			if cumulative[i] > from and cumulative[i] < to: result.append(points[i])
	else:
		for i in range(points.size() - 1, -1, -1):
			if cumulative[i] < from and cumulative[i] > to: result.append(points[i])
	result.append(sample(to))
	return result
