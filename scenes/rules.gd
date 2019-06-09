extends TextureRect

onready var back_node = get_node("VBoxContainer/HBoxControls/Back")
onready var rules_text_label_node = get_node("VBoxContainer/HBoxRules/ScrollContainer/RulesTextLabel")

func _ready():
	game_params.init_styles(self)
	var lang = TranslationServer.get_locale()
	var fallback_filename = game_params.abspath("readme_en.txt")
	var filename = game_params.abspath("readme_%s.txt" % lang) if lang else fallback_filename
	rules_text_label_node.bbcode_enabled = true
	rules_text_label_node.parse_bbcode(load_file(filename, fallback_filename))
	back_node.grab_focus()

func load_file(filename, fallback_filename):
	var file = File.new()
	if file.file_exists(filename):
		file.open(filename, File.READ)
	else:
		file.open(fallback_filename, File.READ)
	var content = file.get_as_text()
	file.close()
	return content

func _on_Back_pressed():
	return get_tree().change_scene("res://main.tscn")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()

