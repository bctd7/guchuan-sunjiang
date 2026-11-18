extends SceneTree
const Reading = preload("res://shared/reading_translation.gd")
func _initialize() -> void:
	var source := "榫卯桅樯舾舱榫\n[b]榫卯[/b]"
	var expected := "榫（sǔn）卯（mǎo）桅（wéi）樯（qiáng）舾（xī）舱（cāng）榫（sǔn）\n[b]榫（sǔn）卯（mǎo）[/b]"
	assert(Reading.annotate(source).replace("\u2060", "") == expected)
	assert(Reading.annotate(Reading.annotate(expected)) == Reading.annotate(expected))
	var font = preload("res://shared/chinese_fonts.gd").font()
	for character in "sǔnmǎowéiqiángxīcāng":
		assert(font.has_char(character.unicode_at(0)), character)
	var translation = Reading.new()
	translation.locale = "en"
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	assert(String(TranslationServer.translate("榫卯")).replace("\u2060", "") == "榫（sǔn）卯（mǎo）")
	print("READING PASS: repeated occurrences, idempotence, markup, accented glyphs, translation")
	TranslationServer.remove_translation(translation)
	quit()
