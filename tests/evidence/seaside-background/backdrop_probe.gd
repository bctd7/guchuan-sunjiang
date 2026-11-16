extends "res://tests/auxiliary_panel_tests.gd"
## Background-specific extension of the original pointer/resize/classroom fixture.
## The product scripts and the original fixture are unchanged.
var captured_classroom:=false
var returned_from_classroom:=false
var awaiting_local_return:=false
func button(control: Button) -> void:
	var caption: String=control.text
	await super.button(control)
	if campaign.active_level!=2:return
	var level=campaign.instances[2]
	var expected: bool=level.view.is_visible_in_tree() and not level.view.inspected
	check(level.view.backdrop.visible==expected,"seaside plate follows overview/local/teaching visibility after "+caption)
	check(level.view.backdrop.get_child(0).texture.resource_path=="res://levels/level02/assets/seaside_shipyard.png","actual chapter-two CanvasLayer consumes the new seaside bitmap")
	if is_instance_valid(level.learning.workshop):
		awaiting_local_return=level.view.inspected
		check(not level.view.backdrop.visible,"seaside background does not leak behind original classroom")
		if not captured_classroom:
			captured_classroom=true
			await capture("second-original-classroom")
	if caption=="返回本关搭建" and awaiting_local_return:
		awaiting_local_return=false
		returned_from_classroom=true
		check(level.view.inspected and not level.view.backdrop.visible,"teaching returns to local neutral observation environment")
		await capture("second-after-classroom-local")
	if returned_from_classroom and caption=="返回船架":
		check(not level.view.inspected and level.view.backdrop.visible,"return from local restores seaside overview after teaching")
		await capture("second-after-classroom-overview")
