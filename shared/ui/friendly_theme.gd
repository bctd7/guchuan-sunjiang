extends RefCounted
const Fonts = preload("res://shared/chinese_fonts.gd")
## One visual vocabulary for all nine workshop entries. No gameplay ownership.
const INK := Color("405343")
const CREAM := Color("fff8e8")
const SAGE := Color("bacbaa")
const WOOD := Color("edd0a5")
static var icons: Dictionary = {}

static func block(color: Color, edge: Color, depth := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.border_width_bottom = depth
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	style.shadow_color = Color(.35,.24,.12,.10)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,4)
	return style

static func make_theme(compact := false) -> Theme:
	var theme := Theme.new()
	theme.default_font = Fonts.font(600)
	theme.default_font_size = 19 if not compact else 18
	for kind in ["Label","Button","OptionButton","PopupMenu"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
			theme.set_color(state,kind,INK)
		theme.set_color("font_disabled_color",kind,Color("9e9d88"))
	for kind in ["Button","OptionButton"]:
		theme.set_stylebox("normal",kind,block(WOOD,Color("c9a479")))
		theme.set_stylebox("hover",kind,block(Color("f5dcb7"),Color("bc956b")))
		theme.set_stylebox("pressed",kind,block(SAGE,Color("849d76"),2))
		theme.set_stylebox("hover_pressed",kind,block(Color("c5d5b5"),Color("849d76"),2))
		theme.set_stylebox("disabled",kind,block(Color("e7dfcf"),Color("c8c0ae"),2))
		var focus := block(Color(0,0,0,0),Color("7b956e"),2)
		focus.shadow_size = 0
		theme.set_stylebox("focus",kind,focus)
		theme.set_constant("h_separation",kind,12)
		theme.set_constant("icon_max_width",kind,28)
	if compact:
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var style := theme.get_stylebox(state,"Button") as StyleBoxFlat
			style.content_margin_left = 9
			style.content_margin_right = 9
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			style.set_corner_radius_all(13)
			style.shadow_size = 2
			style.shadow_offset = Vector2(0,2)
	var picker := block(Color("dbe5cc"),Color("a2b48c"),3)
	theme.set_stylebox("normal","OptionButton",picker)
	theme.set_color("arrow_color","OptionButton",INK)
	theme.set_stylebox("panel","PopupMenu",block(CREAM,Color("dbc3a0"),2))
	theme.set_stylebox("hover","PopupMenu",block(SAGE,Color("a2b48c"),2))
	theme.set_constant("v_separation","PopupMenu",12)
	return theme

static func icon(id: String) -> Texture2D:
	if icons.has(id): return icons[id]
	var paths := {
		"science": '<path d="M5 7q5-3 11 0v20q-6-3-11 0z" fill="#f8e5bd"/><path d="M16 7q6-3 11 0v20q-5-3-11 0z" fill="#bccdad"/><path d="M9 12h3m-3 5h3m8-5h3m-3 5h3"/>',
		"xray": '<path d="M3 16q13-18 26 0-13 18-26 0z" fill="#f7ebd2"/><circle cx="16" cy="16" r="5" fill="#b4c7a2"/>',
		"view": '<rect x="4" y="9" width="24" height="17" rx="5" fill="#f7e0b6"/><path d="m10 9 2-4h8l2 4"/><circle cx="16" cy="17" r="5" fill="#b7c9a4"/>',
		"reset": '<path d="M7 13a10 10 0 1 1 0 9"/><path d="M7 5v8h8"/><path d="M14 17h6v6h-6z" fill="#e8bf86"/>',
		"blocks": '<path d="m4 11 10-5 10 5-10 5z" fill="#e9c086"/><path d="M4 11v11l10 5V16z" fill="#d4ab75"/><path d="m14 16 10-5v11l-10 5z" fill="#bccdad"/>'}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#536046" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">'+str(paths.get(id,paths.blocks))+'</g></svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	var texture := ImageTexture.create_from_image(image)
	icons[id] = texture
	return texture
