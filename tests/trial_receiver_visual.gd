extends "res://tests/dropzone_matrix_visual.gd"
const RELIEF_OUT="res://tests/evidence/trial-receiver/"
func save_frame(label: String) -> void:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=RELIEF_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"receiver GPU "+label)
	images.append(path)
func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RELIEF_OUT))
	await save_frame(label)
	if label.begins_with("bow-through_tenon") and label.ends_with("-inserted"):
		var inspector=level.inspector
		var original: Vector2=inspector.orbit.target_angles
		await button(inspector.xray_button)
		for angle in [Vector2(-.52,-.20),Vector2.ZERO,Vector2(.52,.20)]:
			# Explicit program-controlled inspection, never native-mouse evidence.
			inspector.orbit.target_angles=angle
			await settle(.4)
			await save_frame(label+"-inside-"+str(roundi(angle.x*100)))
		await button(inspector.xray_button)
		inspector.orbit.target_angles=original
		await settle(.4)
func finish_report() -> void:
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":rows,"case_count":rows.size(),"images":images,"method":"Hidden no-focus GPU; 27 Viewport-dispatched event combinations plus three cutaway angles for each wrong through-stock length at the end joint. Program verification; no native mouse or physical touchscreen claims."}
	FileAccess.open(RELIEF_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIAL_RECEIVER_GPU ",passed," passed; ",failures.size()," failed; cases=",rows.size())
	surface.free()
	quit(0 if failures.is_empty() else 1)
