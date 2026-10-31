extends SceneTree
## Rebuild the self-contained runtime font from the licensed source TTF.
## Run after normal Godot asset import; this is an authoring tool, not startup code.
const SOURCE := "res://shared/fonts/NotoSansSC-Variable.ttf"
const DESTINATION := "res://shared/fonts/NotoSansSC.font.res"

func _initialize() -> void:
	var source := ResourceLoader.load(SOURCE, "FontFile", ResourceLoader.CACHE_MODE_IGNORE) as FontFile
	if source == null or source.data != FileAccess.get_file_as_bytes(SOURCE):
		push_error("Imported source must preserve the complete licensed TTF bytes.")
		quit(1)
		return
	var error := ResourceSaver.save(source, DESTINATION, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not save native font: " + str(error))
		quit(1)
		return
	var generated := ResourceLoader.load(DESTINATION, "FontFile", ResourceLoader.CACHE_MODE_IGNORE) as FontFile
	if generated == null or not ResourceLoader.get_dependencies(DESTINATION).is_empty():
		push_error("Runtime font must be self-contained.")
		quit(1)
		return
	for property in source.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0 and property.name != "resource_path":
			if source.get(property.name) != generated.get(property.name):
				push_error("Native font changed stored property: " + str(property.name))
				quit(1)
				return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(generated.data)
	print("BUNDLED_NATIVE_FONT ", JSON.stringify({"source_sha256": hash.finish().hex_encode(), "source_bytes": generated.data.size(), "native_bytes": FileAccess.get_file_as_bytes(DESTINATION).size(), "dependencies": ResourceLoader.get_dependencies(DESTINATION), "stored_properties_equal": true}))
	quit(0)
