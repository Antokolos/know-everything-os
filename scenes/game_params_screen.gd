extends TextureRect

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")

onready var questions_count_label_node = get_node("VBoxContainer/QCLabel")
onready var count_low_node = get_node("VBoxContainer/HBoxQuestionsCount/CountLow")
onready var count_normal_node = get_node("VBoxContainer/HBoxQuestionsCount/CountNormal")
onready var count_high_node = get_node("VBoxContainer/HBoxQuestionsCount/CountHigh")

onready var categories_label_node = get_node("VBoxContainer/CatLabel")
onready var all_categories_node = get_node("VBoxContainer/HBoxCategories/VBoxContainer/HBoxSpecialCategories/CategoryAll")
onready var random_category_node = get_node("VBoxContainer/HBoxCategories/VBoxContainer/HBoxSpecialCategories/CategoryRandom")
onready var categories_node = get_node("VBoxContainer/HBoxCategories/VBoxContainer/GridCustomCategories")
onready var opponent_node = get_node("VBoxContainer/HBoxOpponent/OptionOpponent")
onready var lobby_type_box_node = get_node("VBoxContainer/HBoxOpponent/HBoxLobbyType")
onready var lobby_type_node = lobby_type_box_node.get_node("OptionLobbyType")

onready var start_node = get_node("VBoxContainer/HBoxActions/Start")
onready var back_node = get_node("VBoxContainer/HBoxActions/Back")
var selected_categories = []
const SIZE_LIMIT = 3

func _ready():
	game_params.init_styles(self)
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	for node in categories_node.get_children():
		node.queue_free()
	
	var cats = db.fetch_array_with_args("SELECT category_id, category_name FROM category_texts WHERE language_id = ?", [game_params.language_id])
	for cat in cats:
		var category_id = int(cat.category_id)
		var category_name = str(cat.category_name)
		var name_node = random_category_node.duplicate(0)
		name_node.text = category_name
		name_node.set_meta("category_id", category_id)
		if name_node.connect("pressed", self, "_on_Category_pressed", [name_node]) != OK:
			print("Error connecting to _on_Category_pressed for %s" % category_name)
		categories_node.add_child(name_node)
	
	# Close database
	db.close()
	
	count_low_node.text = str(game_params.QUIZ_COUNT_LOW)
	count_normal_node.text = str(game_params.QUIZ_COUNT_NORMAL)
	count_high_node.text = str(game_params.QUIZ_COUNT_HIGH)
	if game_params.target_quiz_count == game_params.QUIZ_COUNT_LOW:
		count_low_node.pressed = true
		count_normal_node.pressed = false
		count_high_node.pressed = false
	elif game_params.target_quiz_count == game_params.QUIZ_COUNT_HIGH:
		count_low_node.pressed = false
		count_normal_node.pressed = false
		count_high_node.pressed = true
	else:
		count_low_node.pressed = false
		count_normal_node.pressed = true
		count_high_node.pressed = false
	
	opponent_node.add_item(tr("PARAMS_OPPONENT_NONE"), 0)
	opponent_node.set_item_metadata(0, game_params.OPPONENT_NONE)
	opponent_node.add_item(tr("PARAMS_OPPONENT_CPU"), 1)
	opponent_node.set_item_metadata(1, game_params.OPPONENT_CPU)
	if godotsteam.is_steam_running():
		opponent_node.add_item(tr("PARAMS_OPPONENT_HUMAN"), 2)
		opponent_node.set_item_metadata(2, game_params.OPPONENT_HUMAN)
	elif game_params.opponent_type == game_params.OPPONENT_HUMAN:
		game_params.opponent_type = game_params.OPPONENT_NONE
	opponent_node.select(game_params.opponent_type)
	
	if game_params.opponent_type == game_params.OPPONENT_HUMAN:
		lobby_type_node.disabled = false
	lobby_type_node.add_item(tr("PARAMS_LOBBY_PUBLIC"), 0)
	lobby_type_node.set_item_metadata(0, game_params.LOBBY_PUBLIC)
	lobby_type_node.add_item(tr("PARAMS_LOBBY_FRIENDS_ONLY"), 1)
	lobby_type_node.set_item_metadata(1, game_params.LOBBY_FRIENDS_ONLY)
	lobby_type_node.add_item(tr("PARAMS_LOBBY_PRIVATE"), 2)
	lobby_type_node.set_item_metadata(2, game_params.LOBBY_PRIVATE)
	match game_params.lobby_type:
		game_params.LOBBY_PUBLIC:
			lobby_type_node.select(0)
		game_params.LOBBY_FRIENDS_ONLY:
			lobby_type_node.select(1)
		game_params.LOBBY_PRIVATE:
			lobby_type_node.select(2)
		_:
			game_params.lobby_type = game_params.LOBBY_PUBLIC
			lobby_type_node.select(0)
	lobby_type_box_node.visible = godotsteam.is_steam_running()
	back_node.grab_focus()

func get_target_quiz_count():
	if count_low_node.pressed:
		return game_params.QUIZ_COUNT_LOW
	elif count_normal_node.pressed:
		return game_params.QUIZ_COUNT_NORMAL
	elif count_high_node.pressed:
		return game_params.QUIZ_COUNT_HIGH
	return game_params.QUIZ_COUNT_NORMAL

func get_category_ids_array():
	var all_categories = []
	for category in categories_node.get_children():
		all_categories.append(category.get_meta("category_id"))
	if all_categories_node.pressed:
		return all_categories
	if random_category_node.pressed:
		randomize()
		return [all_categories[randi() % all_categories.size()]]
	var result = []
	for category in categories_node.get_children():
		if category.pressed:
			result.append(category.get_meta("category_id"))
	return result

func _on_Start_pressed():
	game_params.target_quiz_count = get_target_quiz_count()
	game_params.category_ids_array = get_category_ids_array()
	game_params.save_settings()
	if game_params.opponent_type != game_params.OPPONENT_HUMAN:
		return get_tree().change_scene("res://scenes/game.tscn")
	else:
		return get_tree().change_scene("res://scenes/game_wait.tscn")

func _on_Back_pressed():
	return get_tree().change_scene("res://main.tscn")

func _on_Category_pressed(cat):
	random_category_node.pressed = false
	all_categories_node.pressed = false
	if cat.pressed:
		selected_categories.push_back(cat)
		if selected_categories.size() > SIZE_LIMIT:
			var oldcat = selected_categories.pop_front()
			oldcat.pressed = false
	else:
		selected_categories.clear()
		for category in categories_node.get_children():
			if category.pressed:
				_on_Category_pressed(category)
	check_has_category()

func check_has_category():
	start_node.disabled = selected_categories.empty() and not random_category_node.pressed and not all_categories_node.pressed

func _on_CategoryAll_pressed():
	for category in categories_node.get_children():
		category.pressed = false
	selected_categories.clear()
	random_category_node.pressed = false
	check_has_category()

func _on_CategoryRandom_pressed():
	for category in categories_node.get_children():
		category.pressed = false
	selected_categories.clear()
	all_categories_node.pressed = false
	check_has_category()

func _on_OptionOpponent_item_selected(ID):
	var md = opponent_node.get_item_metadata(ID)
	lobby_type_node.disabled = md != game_params.OPPONENT_HUMAN
	game_params.opponent_type = md
	game_params.save_settings()

func _on_OptionLobbyType_item_selected(ID):
	var md = lobby_type_node.get_item_metadata(ID)
	game_params.lobby_type = md
	game_params.save_settings()

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()
