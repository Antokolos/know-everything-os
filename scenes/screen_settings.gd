extends TextureRect

onready var music_volume = game_params.music_volume
onready var effects_volume = game_params.effects_volume
onready var background_image = game_params.background_image
onready var background_music = game_params.background_music
onready var game_theme = game_params.game_theme
onready var answer_result_animation = game_params.answer_result_animation
onready var fullscreen = game_params.fullscreen
onready var background_node = get_node("VBoxContainer/HBoxBackground/OptionBackground")
onready var background_music_node = get_node("VBoxContainer/HBoxMusicTrack/OptionMusicTrack")
onready var game_theme_node = get_node("VBoxContainer/HBoxGameTheme/OptionGameTheme")
onready var anwer_result_animation_node = get_node("VBoxContainer/HBoxAnswerResultAnimation/CheckButtonAnswerResultAnimation")
onready var fullscreen_node = get_node("VBoxContainer/HBoxFullscreen/CheckButtonFullscreen")
onready var cancel_node = get_node("VBoxContainer/HBoxControls/ButtonCancel")

func _ready():
	game_params.init_styles(self)
	$VBoxContainer/HBoxMusic/SliderMusic.value = music_volume
	$VBoxContainer/HBoxSound/SliderSound.value = effects_volume
	var i = 0
	for bg in game_params.list_files_in_directory(game_params.abspath("backgrounds"), "png", true):
		background_node.add_item(tr(bg.file), i)
		background_node.set_item_metadata(i, bg)
		if game_params.background_image == bg.file:
			background_node.select(i)
		i = i + 1
	var j = 0
	for mus in game_params.list_files_in_directory(game_params.abspath("music"), "ogg", true):
		background_music_node.add_item(tr(mus.file), j)
		background_music_node.set_item_metadata(j, mus)
		if game_params.background_music == mus.file:
			background_music_node.select(j)
		j = j + 1
	anwer_result_animation_node.set_pressed(game_params.answer_result_animation)
	fullscreen_node.set_pressed(game_params.fullscreen)
	game_theme_node.add_item(tr("SETTINGS_GAME_THEME_LIGHT"), 0)
	game_theme_node.set_item_metadata(0, game_params.GAME_THEME_LIGHT)
	game_theme_node.add_item(tr("SETTINGS_GAME_THEME_DARK"), 1)
	game_theme_node.set_item_metadata(1, game_params.GAME_THEME_DARK)
	match game_params.game_theme:
		game_params.GAME_THEME_LIGHT:
			game_theme_node.select(0)
		game_params.GAME_THEME_DARK:
			game_theme_node.select(1)
		_:
			game_params.game_theme = game_params.GAME_THEME_LIGHT
			game_theme_node.select(0)
	cancel_node.grab_focus()

func _on_ButtonApply_pressed():
	game_params.music_volume = music_volume
	game_params.effects_volume = effects_volume
	game_params.background_image = background_image
	game_params.background_music = background_music
	game_params.game_theme = game_theme
	game_params.answer_result_animation = answer_result_animation
	game_params.fullscreen = fullscreen
	game_params.save_settings()
	return get_tree().change_scene("res://main.tscn")

func _on_ButtonCancel_pressed():
	game_params.reset_background_music()
	game_params.reset_music_volume()
	game_params.reset_effects_volume()
	return get_tree().change_scene("res://main.tscn")

func _on_SliderMusic_value_changed(value):
	music_volume = value
	game_params.set_music_volume(value)

func _on_SliderSound_value_changed(value):
	effects_volume = value
	game_params.play_click()
	game_params.set_effects_volume(value)

func _on_OptionBackground_item_selected(ID):
	background_image = background_node.get_item_metadata(ID).file
	game_params.add_background(background_image)
	game_params.change_background_to(self, background_image)

func _on_OptionMusicTrack_item_selected(ID):
	background_music = background_music_node.get_item_metadata(ID).file
	game_params.add_music(background_music)
	game_params.change_music_to(background_music)
	game_params.set_music_volume(music_volume)

func _on_OptionGameTheme_item_selected(ID):
	game_theme = game_theme_node.get_item_metadata(ID)

func _on_CheckButtonAnswerResultAnimation_toggled(button_pressed):
	answer_result_animation = not answer_result_animation

func _on_CheckButtonFullscreen_toggled(button_pressed):
	fullscreen = not fullscreen
	game_params.init_fullscreen(fullscreen, true)

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_ButtonCancel_pressed()
