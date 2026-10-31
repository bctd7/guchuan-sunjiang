extends SceneTree
const OUTPUT := "res://tests/evidence/wood-material-entry/"
func _initialize() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	var rows: Array = []
	var montage := Image.create(1800, 990, false, Image.FORMAT_RGB8)
	montage.fill(Color("f3ead7"))
	for i in catalog.size():
		var id := str(catalog[i].id)
		var before := Image.load_from_file(OUTPUT+"before/embedded-"+id+".png")
		var after := Image.load_from_file(OUTPUT+"after/embedded-"+id+".png")
		var delta := 0.0
		var changed := 0
		var count := 0
		# Only pixels occupied by wood in both versions, excluding ghost overlays.
		# Cropping removes the UI; colour mask excludes the changed paper backdrop.
		for y in range(200,750):
			for x in range(500,1400):
				var a := before.get_pixel(x,y)
				var b := after.get_pixel(x,y)
				if a.r-a.b < .12 or b.r-b.b < .12 or a.r-a.g < .025 or b.r-b.g < .025 or a.b > .78 or b.b > .78: continue
				var difference := (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0*255
				delta += difference
				count += 1
				if difference > 8.0: changed += 1
		rows.append({"joint":id,"wood_pixels":count,"mean_rgb_change_255":delta/maxi(count,1),"wood_pixels_changed_over_8":float(changed)/maxi(count,1)})
		var crop := after.get_region(Rect2i(480,170,920,620))
		crop.convert(Image.FORMAT_RGB8)
		crop.resize(600,330,Image.INTERPOLATE_LANCZOS)
		montage.blit_rect(crop,Rect2i(0,0,600,330),Vector2i((i%3)*600,floori(float(i)/3)*330))
	montage.save_png(OUTPUT+"nine-embedded-models-after.png")
	var left := Image.load_from_file(OUTPUT+"before/embedded-dovetail-1000.png")
	var right := Image.load_from_file(OUTPUT+"after/embedded-dovetail-1000.png")
	left.convert(Image.FORMAT_RGB8)
	right.convert(Image.FORMAT_RGB8)
	var comparison := Image.create(2000,625,false,Image.FORMAT_RGB8)
	comparison.blit_rect(left,Rect2i(0,0,1000,625),Vector2i.ZERO)
	comparison.blit_rect(right,Rect2i(0,0,1000,625),Vector2i(1000,0))
	comparison.save_png(OUTPUT+"dovetail-before-left-after-right.png")
	FileAccess.open(OUTPUT+"pixel-comparison.json",FileAccess.WRITE).store_string(JSON.stringify({"method":"Same camera/pose/viewport before vs after; mean absolute RGB delta on mutual wood colour mask, UI/background excluded; not a perceptual score.","rows":rows},"  "))
	print("WOOD_PIXEL_COMPARISON ",JSON.stringify(rows))
	quit()
