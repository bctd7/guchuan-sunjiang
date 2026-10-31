extends RefCounted
## One STATIC, strictly increasing world-coordinate map for all three woods.
## Exact source travel is mapped after displacement. Equal contact points remain
## equal; disjoint solid interiors remain disjoint. No model/profile is modified.
## Split triangles at every map breakpoint so straight chords cannot bridge air.
const GAIN := 12.0
var bands := [[],[]]

func configure(profile: Dictionary) -> void:
	for slot in 2:
		var axis := 0 if slot == 0 else 2
		var mode: Dictionary = profile.modes[slot]
		var values: Array[float] = [float(mode.pull_anchor[axis])]
		for part in profile.parts:
			if part.id != mode.moving[0]: continue
			for vertex in part.vertices+part.cut_vertices:
				var value := snappedf(float(vertex[axis]),.000001)
				if not values.has(value): values.append(value)
		values.sort()
		for value in values:
			var end := value+float(mode.distance)
			if not bands[slot].is_empty() and value <= bands[slot][-1].y+.000001:
				bands[slot][-1].y = maxf(bands[slot][-1].y,end)
			else: bands[slot].append(Vector2(value,end))

func coordinate(value: float, slot: int) -> float:
	var extra := 0.0
	for band in bands[slot]:
		extra += (GAIN-1.0)*(clampf(value-band.x,0.0,band.y-band.x)-clampf(.4-band.x,0.0,band.y-band.x))
	return value+extra

func point(value: Vector3) -> Vector3:
	return Vector3(coordinate(value.x,0),value.y*1.5,coordinate(value.z,1))

func clip(poly: Array, axis: int, at: float, low: bool) -> Array:
	var result: Array = []
	for i in poly.size():
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[(i+1)%poly.size()]
		var da := (a[axis]-at)*(1.0 if low else -1.0)
		var db := (b[axis]-at)*(1.0 if low else -1.0)
		if da <= .00000001: result.append(a)
		if da*db < -.0000000000000001: result.append(a.lerp(b,da/(da-db)))
	return result

func polygons(source: Array) -> Array:
	var result: Array = [source]
	for slot in 2:
		var axis := 0 if slot == 0 else 2
		for band in bands[slot]:
			for at in [band.x,band.y]:
				var next: Array = []
				for poly in result:
					var low := INF
					var high := -INF
					for vertex in poly:
						low = minf(low,vertex[axis])
						high = maxf(high,vertex[axis])
					if low < at-.00000001 and high > at+.00000001:
						next.append(clip(poly,axis,at,true))
						next.append(clip(poly,axis,at,false))
					else: next.append(poly)
				result = next
	var mapped: Array = []
	for poly in result:
		var output: Array = []
		for vertex in poly: output.append(point(vertex))
		mapped.append(output)
	return mapped

func segment(a: Vector3, b: Vector3) -> Array:
	var times: Array[float] = [0.0,1.0]
	for slot in 2:
		var axis := 0 if slot == 0 else 2
		if absf(b[axis]-a[axis]) < .00000001: continue
		for band in bands[slot]:
			for at in [band.x,band.y]:
				var t: float = (at-a[axis])/(b[axis]-a[axis])
				if t > 0.0 and t < 1.0: times.append(t)
	times.sort()
	var result: Array = []
	for t in times: result.append(point(a.lerp(b,t)))
	return result
