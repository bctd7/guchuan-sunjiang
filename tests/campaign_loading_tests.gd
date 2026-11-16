extends SceneTree
const Campaign=preload("res://campaign/campaign.gd")
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
	check(campaign.active_level==0 and campaign.menu.visible and not campaign.instances.has(2),"missing chapter preserves directory and creates no cache")
	check(errors==[[2,"scene_unavailable"]] and not campaign.menu_status.text.is_empty(),"failure is observable without changing normal navigation")
	campaign.open_level(1);await process_frame
	var first: Node=campaign.instances[1];first.learning.start_button.pressed.emit();await process_frame
	var saved: Dictionary=first.state.placed.duplicate(true)
	for fault in ["missing","contract"]:
		campaign.failure_mode=fault;campaign.open_level(2);await process_frame
		check(campaign.active_level==1 and first.get_parent()==campaign and not campaign.menu.visible,"failed switch retains active chapter "+fault)
		check(first.state.placed==saved and not campaign.instances.has(2),"failed switch retains exact state and rejects invalid cached chapter "+fault)
	check(campaign.last_load_error.reason=="invalid_chapter_contract" and errors.size()==3,"contract failure has a stable diagnostic")
	campaign.failure_mode="";campaign.open_level(2);await process_frame
	check(campaign.active_level==2 and not first.is_inside_tree() and campaign.last_load_error.is_empty(),"later successful load detaches only after preparation and clears error")
	var second: Node=campaign.instances[2];campaign.open_level(1);await process_frame
	check(campaign.instances[1]==first and first.get_parent()==campaign and not second.is_inside_tree() and first.state.placed==saved,"normal cached reentry remains unchanged")
	var owned: Array=[weakref(first),weakref(second)];campaign.free()
	check(owned.all(func(ref):return ref.get_ref()==null),"freeing campaign releases attached and detached cached chapters")
	var report={"passed":passed,"failed":failures.size(),"failures":failures};FileAccess.open("res://tests/campaign_loading_report.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("CAMPAIGN_LOADING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
