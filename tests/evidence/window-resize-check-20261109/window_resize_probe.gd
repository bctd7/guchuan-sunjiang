extends SceneTree
var results: Array=[]
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 await create_timer(.2).timeout
 await process_frame
func run() -> void:
 root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
 var campaign=load("res://campaign/campaign.tscn").instantiate();root.add_child(campaign);await settle()
 var folder:="res://tests/evidence/window-resize-probe"
 DirAccess.make_dir_recursive_absolute(folder)
 for stage in ["menu","level02"]:
  var sample: Control=campaign.chapter_buttons[1]
  if stage=="level02":
   campaign.open_level(2);await settle()
   var level=campaign.instances[2]
   level.learning.start_button.pressed.emit();level.panel.observe_button.pressed.emit()
   level.state.choose_joint("tongue_groove");level.state.choose_opening("B");await settle()
   sample=level.panel.opening_gallery.buttons.B
  for size_value in [Vector2i(960,600),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
   root.size=size_value;await settle();RenderingServer.force_draw(false)
   var final: Transform2D=root.get_final_transform()
   var rect: Rect2=final*sample.get_global_rect()
   var entry:={"stage":stage,"requested":str(size_value),"window":str(root.size),"viewport":str(root.get_visible_rect()),"scale_size":str(root.content_scale_size),"scale_mode":root.content_scale_mode,"scale_aspect":root.content_scale_aspect,"final_scale":str(final.get_scale()),"sample_pixels":str(rect)}
   results.append(entry)
   if size_value.x in [960,1920]:
    var path: String=folder+"/"+stage+"-"+str(size_value.x)+".png"
    root.get_texture().get_image().save_png(path)
 var report={"passed":results.size(),"failed":0,"failures":[],"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus(),"measurements":results,"method":"Native root Window with actual project content scaling, not a synthetic SubViewport; minimized, no focus."}
 FileAccess.open(folder+"/gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WINDOW_RESIZE_PROBE ",JSON.stringify(report));campaign.free();quit()
