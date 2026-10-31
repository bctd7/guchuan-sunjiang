extends PanelContainer
## Ordinary Control: host chooses canvas/layout. No input code or camera coupling.
var presenter: Node3D
var body: VBoxContainer
var text_label: Label
var master: CheckButton

func configure(source: Node3D) -> void:
	presenter = source
	custom_minimum_size.x = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("faf8f1")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	add_child(box)
	master = CheckButton.new()
	master.text = "结构科普"
	master.button_pressed = presenter.enabled
	master.add_theme_color_override("font_color",Color("304638"))
	box.add_child(master)
	body = VBoxContainer.new()
	body.visible = presenter.enabled
	box.add_child(body)
	var row := HBoxContainer.new()
	body.add_child(row)
	for item in [["force","外力",true],["contact","候选面",true],["motion","趋势",true]]:
		var toggle := CheckBox.new()
		toggle.text = item[1]
		toggle.button_pressed = item[2]
		toggle.add_theme_color_override("font_color",Color("304638"))
		var key: String = item[0]
		toggle.toggled.connect(func(value: bool): presenter.set_layer(key,value))
		row.add_child(toggle)
	var cases := OptionButton.new()
	cases.add_item("① 受限方向 · 为什么挡住？")
	cases.add_item("② 可动方向 · 为什么能退出？")
	cases.item_selected.connect(presenter.set_case)
	body.add_child(cases)
	var legend := Label.new()
	legend.custom_minimum_size.x = 268
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "橙实线：假设施力　青：候选承压面\n红虚线+横杠：受限　绿虚线：可动趋势"
	legend.add_theme_font_size_override("font_size",13)
	legend.add_theme_color_override("font_color",Color("304638"))
	body.add_child(legend)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(268,330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	text_label = Label.new()
	text_label.custom_minimum_size.x = 252
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size",15)
	text_label.add_theme_color_override("font_color",Color("304638"))
	scroll.add_child(text_label)
	master.toggled.connect(func(value: bool):
		body.visible = value
		presenter.set_enabled(value))
	presenter.display_changed.connect(refresh)
	refresh()

func refresh() -> void:
	master.set_pressed_no_signal(presenter.enabled)
	body.visible = presenter.enabled
	text_label.text = presenter.summary()
