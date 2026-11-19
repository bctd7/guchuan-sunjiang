extends RefCounted
## Cache immutable mesh and material resources in packed variants, never live nodes.
const CAPACITY := 64

var _scenes: Dictionary = {}

func populate(target: Node3D, key: String, build: Callable) -> void:
	var copy := instantiate(key, func() -> Node3D:
		var model := Node3D.new()
		build.call(model)
		return model)
	for name in copy.get_meta_list():
		var value: Variant = copy.get_meta(name)
		target.set_meta(name, value.duplicate(true) if value is Dictionary or value is Array else value)
	for child in copy.get_children():
		copy.remove_child(child)
		target.add_child(child)
	copy.free()

func instantiate(key: String, build: Callable) -> Node3D:
	var scene: PackedScene = _scenes.get(key)
	if scene != null:
		return instantiate_model(scene)
	var model := build.call() as Node3D
	scene = pack_model(model)
	if scene != null:
		if _scenes.size() == CAPACITY:
			_scenes.erase(_scenes.keys()[0])
		_scenes[key] = scene
	return model

static func instantiate_model(scene: PackedScene) -> Node3D:
	var model := scene.instantiate() as Node3D
	for node in model.find_children("*", "Node", true, false):
		node.owner = null
	return model

static func pack_model(model: Node3D) -> PackedScene:
	var descendants := model.find_children("*", "Node", true, false)
	var owners: Array[Node] = []
	for node in descendants:
		owners.append(node.owner)
		node.owner = model
	var scene := PackedScene.new()
	var error := scene.pack(model)
	for index in descendants.size():
		descendants[index].owner = owners[index]
	return scene if error == OK else null
