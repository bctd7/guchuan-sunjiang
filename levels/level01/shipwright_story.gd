extends "res://levels/shared/story_overlay.gd"
## Chapter content only; presentation and lifecycle are shared.
const STORY_TITLE := "龙骨里的七星伴月"
const STORY_PARAGRAPHS := [
	"福建泉州出土的一艘宋代古船，龙骨接头里藏着一个小秘密：七个小孔里放着钱币，另一个大孔里放着铜镜。小孔排成北斗七星的样子，圆圆的铜镜像满月，人们把它叫作“七星伴月”，寄托着平安出海的心愿。",
	"让我们沿着这个发现，想象一个造船的早晨。海风吹动帆角，船场传来笃、笃、笃的敲木声。小帮手阿禾蹲在船匠师傅身边，看见木头上摆着钱币和铜镜，好奇地问：“船还没出海，怎么先把星星请来了？”",
	"师傅笑了：“你数数看。”阿禾伸出手指，一枚、两枚……正好七枚！他顺着钱币的排列看过去：“这几颗连起来，像一把长柄勺子！”师傅又指了指旁边的铜镜：“再加上这轮小月亮，便是七星伴月。我们把盼望平安的心愿，藏进船里。”",
	"阿禾看看大船，又望望远处的海：“有了星星和月亮，船就不怕风浪了吗？”师傅摇摇头：“心愿很美好，木头也要接得牢。哪一处没对齐，哪一段没装稳，都要仔细看看。出海的人，还得留心天气，懂得掌舵。”阿禾明白了：祝福装在心里，功夫用在手上。",
	"他低头望着龙骨。长长的龙骨像船底的脊梁，一根根船肋向两边伸开，仿佛大船慢慢张开了怀抱。刚才只顾着找星星的阿禾，这回认真看起木头的接头：“师傅，这里也要接得稳稳的！”",
	"海风又吹来了。阿禾想，等船扬起帆，钱币和铜镜会静静留在龙骨里，陪着船上的人去远方。现在，再看看画里的七枚钱币与铜镜：你能找到那把长柄勺子吗？大船带走的不只是货物，还有岸上人盼它平安归来的心愿。"
]
const Illustration=preload("res://levels/level01/seven_stars_illustration.gd")

func _story_content() -> Dictionary:
	return {"name":"ShipwrightStory", "title":STORY_TITLE, "paragraphs":STORY_PARAGRAPHS, "illustration":Illustration}
