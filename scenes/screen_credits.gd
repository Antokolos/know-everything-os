extends TextureRect

onready var godot_url_node = get_node("VBoxContainer/HBoxGodot/VBoxContainer/GodotUrl")
onready var steinem_url_node = get_node("VBoxContainer/HBoxFont/VBoxContainer/SteinemUrl")
onready var back_node = get_node("VBoxContainer/HBoxControls/Back")

func _ready():
	game_params.init_styles(self)
	godot_url_node.push_meta(0)
	godot_url_node.append_bbcode("https://godotengine.org")
	godot_url_node.pop()
	steinem_url_node.push_meta(0)
	steinem_url_node.append_bbcode("https://www.1001fonts.com/roboto-font.html")
	steinem_url_node.pop()
	back_node.grab_focus()

func _on_Back_pressed():
	return get_tree().change_scene("res://main.tscn")

func _on_GodotUrl_meta_clicked(meta):
	godotsteam.open_url("https://godotengine.org")

func _on_SteinemUrl_meta_clicked(meta):
	godotsteam.open_url("https://www.1001fonts.com/roboto-font.html")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()

