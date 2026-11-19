extends SceneTree
const Campaign=preload("res://app/campaign/campaign.gd")
class FaultyCampaign:
	extends Campaign
	var failure_mode:=""
	func _load_chapter(number: int) -> PackedScene:
		if number==2 and failure_mode=="missing":return null
		if number==2 and failure_mode=="contract":
			var packed:=PackedScene.new();var invalid:=Node.new();packed.pack(invalid);invalid.free();return packed
		return super._load_chapter(number)
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func run() -> void:
	var campaign:=FaultyCampaign.new();root.add_child(campaign);await process_frame
	var errors: Array=[];campaign.load_failed.connect(func(number: int,reason: String):errors.append([number,reason]))
	campaign.failure_mode="missing";campaign.open_level(2)
	check(campaign.active_level==0 and campaign.menu.visible and campaign.current_chapter == null,"missing chapter preserves directory and creates no cache")
	check(errors==[[2,"scene_unavailable"]] and not campaign.menu_status.text.is_empty(),"failure is observable without changing normal navigation")
	campaign.open_level(1);await process_frame
	var first: Node=campaign.current_chapter;first.learning.start_button.pressed.emit();await process_frame
	var saved: Dictionary=first.state.placed.duplicate(true)
	for fault in ["missing","contract"]:
		campaign.failure_mode=fault;campaign.open_level(2);await process_frame
		check(campaign.active_level==1 and first.get_parent()==campaign and not campaign.menu.visible,"failed switch retains active chapter "+fault)
		check(first.state.placed==saved and campaign.current_chapter == first,"failed switch retains exact state and rejects invalid cached chapter "+fault)
	check(campaign.last_load_error.reason=="invalid_chapter_contract" and errors.size()==3,"contract failure has a stable diagnostic")
	campaign.failure_mode="";campaign.open_level(2);await process_frame
	check(campaign.active_level==2 and not is_instance_valid(first) and campaign.last_load_error.is_empty(),"later successful load detaches only after preparation and clears error")
	var second: Node=campaign.current_chapter;campaign.open_level(1);await process_frame
	check(not is_instance_valid(second) and campaign.current_chapter.workbench_ready == false,
		"switching releases the previous scene and opens a fresh introduction")
	var active: WeakRef = weakref(campaign.current_chapter)
	campaign.free()
	check(active.get_ref()==null,"freeing campaign releases the current chapter")
	var report={"passed":passed,"failed":failures.size(),"failures":failures};FileAccess.open("res://tests/campaign_loading_report.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("CAMPAIGN_LOADING ",JSON.stringify(report))
	root.get_node("GameAudio").music.stop()
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
