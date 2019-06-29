extends TextureRect

onready var back_node = get_node("VBoxContainer/HBoxControls/Back")
onready var authors_text_label_node = get_node("VBoxContainer/HBoxAuthors/ScrollContainer/AuthorsTextLabel")

func _ready():
	game_params.init_styles(self)
	var lang = TranslationServer.get_locale()
	var fallback_filename = game_params.abspath("authors_en.txt")
	var filename = game_params.abspath("authors_%s.txt" % lang) if lang else fallback_filename
	authors_text_label_node.bbcode_enabled = true
	authors_text_label_node.parse_bbcode(load_file(filename, fallback_filename))
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
	return get_tree().change_scene("res://scenes/screen_credits.tscn")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()

