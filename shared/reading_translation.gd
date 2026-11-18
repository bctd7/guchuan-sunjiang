extends Translation
## Presentation-only translation: source strings, keys and gameplay data stay intact.
const READINGS := {"榫": "sǔn", "卯": "mǎo", "桅": "wéi", "樯": "qiáng", "舾": "xī", "舱": "cāng"}

static func annotate(source: String) -> String:
	var result := source.replace("\u2060", "")
	for character in READINGS:
		var suffix: String = "（" + READINGS[character] + "）"
		# Normalize existing annotations before adding one, including repeated refreshes.
		while result.contains(character + suffix):
			result = result.replace(character + suffix, character)
		result = result.replace(character, character + "\u2060" + suffix)
	return result

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	return StringName(annotate(String(src_message)))
