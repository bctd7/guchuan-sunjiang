extends "res://tests/step_guide_visual.gd"
const DEST="res://tests/evidence/gold-guide/"
var frame_index:=0
var timing: Array=[]
func capture(label: String) -> void:
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"frames"))
	RenderingServer.force_draw(false)
	surface.get_texture().get_image().save_png(DEST+label+".png")
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<2600:
		await create_timer(1.0/24).timeout
		RenderingServer.force_draw(false)
		var path:=DEST+"frames/%04d.png"%frame_index
		surface.get_texture().get_image().save_png(path)
		timing.append({"frame":frame_index,"ms":Time.get_ticks_msec(),"stage":label})
		frame_index+=1
	FileAccess.open(DEST+"timing.json",FileAccess.WRITE).store_string(JSON.stringify(timing))
	images.append(label)
