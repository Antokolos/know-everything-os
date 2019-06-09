extends TextureRect

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")

onready var game_params_screen_scene = preload("res://scenes/game_params_screen.tscn")
onready var language = get_node("VBoxMain/HBoxLanguage/VBoxLanguage/OptionLanguage")
onready var greeting_name_node = get_node("VBoxMain/VBoxGreeting/LabelName")
onready var stats_single_node = get_node("VBoxMain/VBoxGreeting/LabelStatsSingle")
onready var stats_multi_node = get_node("VBoxMain/VBoxGreeting/LabelStatsMulti")
onready var join_game_node = get_node("VBoxMain/VBoxContainer/HBoxMenu/VBoxContainer/JoinGame")
onready var leaderboards_node = get_node("VBoxMain/VBoxContainer/HBoxMenu/VBoxContainer/Leaderboards")

func _ready():
	game_params.init_styles(self)
	init_database()
	rebuild_user_info()
	if not godotsteam.is_steam_running():
		join_game_node.visible = false
		leaderboards_node.visible = false
	language.grab_focus()

func rebuild_user_info():
	if not godotsteam.is_connected("leaderboard_rank_retrieved", self, "rank_single"):
		if godotsteam.connect("leaderboard_rank_retrieved", self, "rank_single") == OK:
			godotsteam.fetch_leaderboard(godotsteam.LEADERBOARD_SINGLEPLAYER)

func format_greeting():
	if godotsteam.user_name:
		return tr("INFO_GREETING") % godotsteam.user_name
	else:
		return tr("INFO_STEAM_INIT_ERROR")

func rank_single(global_rank, score):
	greeting_name_node.text = format_greeting()
	godotsteam.disconnect("leaderboard_rank_retrieved", self, "rank_single")
	godotsteam.set_achievement("MAIN_MENU")
	if global_rank > 0:
		stats_single_node.text = tr("INFO_SCORE_RANK_SINGLE") % [score, global_rank]
		if global_rank <= 10:
			godotsteam.set_achievement("PROFESSOR")
	else:
		stats_single_node.text = ""
	godotsteam.store_stats()
	if godotsteam.connect("leaderboard_rank_retrieved", self, "rank_multi") == OK:
		godotsteam.fetch_leaderboard(godotsteam.LEADERBOARD_MULTIPLAYER)

func rank_multi(global_rank, score):
	godotsteam.disconnect("leaderboard_rank_retrieved", self, "rank_multi")
	if global_rank > 0:
		stats_multi_node.text = tr("INFO_SCORE_RANK_MULTI") % [score, global_rank]
		if global_rank <= 10:
			godotsteam.set_achievement("SUPERMAN")
			godotsteam.store_stats()
	else:
		stats_multi_node.text = ""

func init_database():
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS languages ("
			+ "language_id integer PRIMARY KEY,"
			+ "language_code text NOT NULL,"
			+ "language_name_english text NOT NULL,"
			+ "language_name_native text NOT NULL"
			+ ");",
		"SELECT * FROM languages;",
		[
			"INSERT INTO languages (language_code, language_name_english, language_name_native) VALUES ('en', 'English', 'English');",
			"INSERT INTO languages (language_code, language_name_english, language_name_native) VALUES ('ru', 'Russian', 'Русский');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS answer_groups ("
			+ "answer_group_id integer PRIMARY KEY,"
			+ "answer_group_hint text NOT NULL"
			+ ");",
		"SELECT * FROM answer_groups;",
		[
#			"INSERT INTO answer_groups (answer_group_hint) VALUES ('Astronomy question 1');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS answers ("
			+ "answer_id integer PRIMARY KEY,"
			+ "answer_group_id integer NOT NULL,"
			+ "correct integer NOT NULL"
			+ ");",
		"SELECT * FROM answers;",
		[
#			"INSERT INTO answers (answer_group_id, correct) VALUES (1, 1);",
#			"INSERT INTO answers (answer_group_id, correct) VALUES (1, 0);",
#			"INSERT INTO answers (answer_group_id, correct) VALUES (1, 0);",
#			"INSERT INTO answers (answer_group_id, correct) VALUES (1, 0);"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS answer_texts ("
			+ "answer_text_id integer PRIMARY KEY,"
			+ "answer_id integer NOT NULL,"
			+ "language_id integer NOT NULL,"
			+ "answer_text text NOT NULL"
			+ ");",
		"SELECT * FROM answer_texts;",
		[
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (1, 1, 'Mars');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (2, 1, 'Earth');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (3, 1, 'Venus');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (4, 1, 'Jupiter');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (1, 2, 'Марс');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (2, 2, 'Земля');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (3, 2, 'Венера');",
#			"INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (4, 2, 'Юпитер');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS categories ("
			+ "category_id integer PRIMARY KEY,"
			+ "category_name_hint text NOT NULL"
			+ ");",
		"SELECT * FROM categories;",
		[
			"INSERT INTO categories (category_name_hint) VALUES ('Astronomy');",
			"INSERT INTO categories (category_name_hint) VALUES ('Mathematics');",
			"INSERT INTO categories (category_name_hint) VALUES ('World literature');",
			"INSERT INTO categories (category_name_hint) VALUES ('Russian literature');",
			"INSERT INTO categories (category_name_hint) VALUES ('Cuisine');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS category_texts ("
			+ "category_text_id integer PRIMARY KEY,"
			+ "category_id integer NOT NULL,"
			+ "language_id integer NOT NULL,"
			+ "category_name text NOT NULL"
			+ ");",
		"SELECT * FROM category_texts;",
		[
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (1, 1, 'Astronomy');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (1, 2, 'Астрономия');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (2, 1, 'Mathematics');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (2, 2, 'Математика');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (3, 1, 'World literature');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (3, 2, 'Мировая литература');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (4, 1, 'Russian literature');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (4, 2, 'Русская литература');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (5, 1, 'Cuisine');",
			"INSERT INTO category_texts (category_id, language_id, category_name) VALUES (5, 2, 'Кулинария');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS quizzes ("
			+ "quiz_id integer PRIMARY KEY,"
			+ "category_id integer NOT NULL,"
			+ "answer_group_id integer NOT NULL"
			+ ");",
		"SELECT * FROM quizzes;",
		[
#			"INSERT INTO quizzes (category_id, answer_group_id) VALUES (1, 1);"
		]
	)

	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS quiz_texts ("
			+ "quiz_text_id integer PRIMARY KEY,"
			+ "quiz_id integer NOT NULL,"
			+ "language_id integer NOT NULL,"
			+ "quiz_text text NOT NULL"
			+ ");",
		"SELECT * FROM quiz_texts;",
		[
#			"INSERT INTO quiz_texts (quiz_id, language_id, quiz_text) VALUES (1, 1, 'Which planet has natural sattelite named Phobos?');",
#			"INSERT INTO quiz_texts (quiz_id, language_id, quiz_text) VALUES (1, 2, 'Спутником какой планеты является Фобос?');"
		]
	)
	
	var result = db.fetch_array("SELECT * FROM languages ORDER BY language_id")
	var i = 0
	var lang_to_select = game_params.language_id - 1
	for lang in result:
		var flag_file_name = "res://assets/flags/%s.png" % lang.language_code
		var texture = ImageTexture.new()
		var image = load(flag_file_name)
		texture.create_from_image(image)
		language.add_item(lang.language_name_native, i)
		language.set_item_icon(i, texture)
		language.set_item_metadata(i, lang)
		i = i + 1
	language.select(lang_to_select)
	_on_OptionLanguage_item_selected(lang_to_select)
	
	# Close database
	db.close()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS sessions ("
			+ "session_id integer PRIMARY KEY,"
			+ "timestamp integer NOT NULL,"
			+ "quiz_count integer NOT NULL,"
			+ "lives integer NOT NULL,"
			+ "is_win integer NOT NULL," # Needed because player can lose because he left before the game was finished or win because the opponent left the game
			+ "is_opponent_win integer NOT NULL"
			+ ");",
		"SELECT * FROM sessions;",
		[
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS players ("
			+ "player_id integer PRIMARY KEY,"
			+ "steam_id integer," # 0 for current user, NULL for CPU, Steam ID for human opponent
			+ "player_name text NOT NULL" # Steam name for human opponent
			+ ");",
		"SELECT * FROM players;",
		[
			"INSERT INTO players (steam_id, player_name) VALUES (NULL, 'CPU');",
			"INSERT INTO players (steam_id, player_name) VALUES (0, 'You');"
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS results ("
			+ "result_id integer PRIMARY KEY,"
			+ "session_id integer NOT NULL,"
			+ "player_id integer NOT NULL," # from 'players' table
			+ "timestamp integer NOT NULL,"
			+ "quiz_id integer NOT NULL,"
			+ "answer_correct integer NOT NULL,"
			+ "reward integer NOT NULL"
			+ ");",
		"SELECT * FROM results;",
		[
		]
	)
	
	create_table(
		db,
		"CREATE TABLE IF NOT EXISTS selections ("
			+ "selection_id integer PRIMARY KEY,"
			+ "result_id integer NOT NULL,"
			+ "answer_id integer NOT NULL"
			+ ");",
		"SELECT * FROM selections;",
		[
		]
	)
	
	# Close stats database
	db.close()

func create_table(db, creation_query, selection_query, insertion_queries):
	var result = null
	
	# Create table
	result = db.query(creation_query)
	
	# Fetch rows
	result = db.fetch_array(selection_query)
	
	if (!result || result.size() <= 0):
		for query in insertion_queries:
			# Insert new row
			result = db.query(query)
			
			if (!result):
				print("Cannot insert data for query = " + query)
		return true
	else:
		# Print rows
		#for i in result:
		#	print(i)
		return false

func _on_Game_pressed():
	game_params.play_click()
	return get_tree().change_scene_to(game_params_screen_scene)

func _on_Quit_pressed():
	game_params.play_click()
	get_tree().quit()

func _on_OptionLanguage_item_selected(ID):
	var md = language.get_item_metadata(ID)
	if game_params.language_id != md.language_id:
		game_params.play_click()
		rebuild_user_info()
	game_params.language_id = md.language_id
	TranslationServer.set_locale(md.language_code)
	game_params.save_settings()

func _on_Settings_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/screen_settings.tscn")

func _on_About_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/screen_about.tscn")

func _on_Stats_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/screen_stats.tscn")

func _on_JoinGame_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/game_join.tscn")

func _on_Leaderboards_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/screen_leaderboards.tscn")

func _on_Credits_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/screen_credits.tscn")

func _on_Editor_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/editor.tscn")

func _on_Rules_pressed():
	game_params.play_click()
	return get_tree().change_scene("res://scenes/rules.tscn")
