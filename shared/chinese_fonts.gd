extends RefCounted
## Project-owned Chinese glyphs and explicit weights; no host-font lookup.
const SOURCE: FontFile = preload("res://shared/fonts/NotoSansSC.font.res")
static var _fonts: Dictionary = {}

static func font(weight: int = 400) -> FontVariation:
	if not _fonts.has(weight):
		var value := FontVariation.new()
		value.base_font = SOURCE
		value.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight)}
		_fonts[weight] = value
	return _fonts[weight]
