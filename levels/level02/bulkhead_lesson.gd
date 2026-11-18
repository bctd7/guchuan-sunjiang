extends "res://levels/shared/story_overlay.gd"
## Chapter content only; presentation and lifecycle are shared.
const Illustration = preload("res://levels/level02/bulkhead_diagram.gd")
const STORY_TITLE := "水密隔舱"
const STORY_PARAGRAPHS := [
	"龙骨像脊梁，船板合成外壳。舱内再用横向隔板分成多个舱位，就像给船装上一道道内墙。",
	"一处船板破损时，密封良好的隔板能限制水向其他舱扩散，为处置险情争取时间。",
	"榫卯把木材接在一起，艌密工艺把板缝封好。船匠会在缝里填入麻料，配合桐油灰等材料密封，再把船放进水里检查。",
	"看看刚才的船段：隔板沿两侧船壳和底板相接，青色线表示需要密封的边缘。"
]
func _story_content() -> Dictionary:
	return {"name":"BulkheadStory", "title":STORY_TITLE, "paragraphs":STORY_PARAGRAPHS, "illustration":Illustration}

func show_lesson(interaction: Node) -> void:
	show_story(interaction)
