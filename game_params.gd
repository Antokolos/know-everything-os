extends Node

const DEFAULT_FONT_SIZE = 32
const DEFAULT_ANSWER_RESULT_ANIMATION = true
const LANGUAGE_EN = 1
const QUIZ_COUNT_LOW = 15
const QUIZ_COUNT_NORMAL = 30
const QUIZ_COUNT_HIGH = 60

# Reward ratios. Player's score will be multiplied by these values
# and added to the total score as a bonus in case of victory
const QUIZ_COUNT_LOW_REWARD_RATIO = 0.3
const QUIZ_COUNT_NORMAL_REWARD_RATIO = 0.4
const QUIZ_COUNT_HIGH_REWARD_RATIO = 0.5

const DEFAULT_VOLUME = 60
const MAX_VOLUME = 100
const DEFAULT_BACKGROUND = "deep_sky_01.png"
const DEFAULT_MUSIC = "enchanted-tiki-86.ogg"
const TOTAL_LIVES = 5
const CORRECT_ANSWER_REWARD_MIN = 1
const CORRECT_ANSWER_REWARD_MAX = 5
const OPPONENT_NONE = 0
const OPPONENT_CPU = 1
const OPPONENT_HUMAN = 2
const GAME_THEME_LIGHT = 0
const GAME_THEME_DARK = 1

# Note that these constants' values correspond to ones from the Steam library
const LOBBY_PRIVATE = 0
const LOBBY_FRIENDS_ONLY = 1
const LOBBY_PUBLIC = 2

const LOBBY_DISTANCE_FILTER_CLOSE = 0
const LOBBY_DISTANCE_FILTER_DEFAULT = 1
const LOBBY_DISTANCE_FILTER_FAR = 2
const LOBBY_DISTANCE_FILTER_WORLDWIDE = 3

const QUESTION_TIMER_MAX_VALUE = 100
const QUESTION_TIMER_SPEED = 3
const CPU_OPPONENT_THRESHOLD_MIN_VALUE = 33
const CPU_OPPONENT_THRESHOLD_MAX_VALUE = 90
const CPU_OPPONENT_CORRECT_ANSWER_PROBABILITY_START = 0.88 # Start value for CPU correct answer probability. This probability will be increased with each error.
const CPU_OPPONENT_MAX_PLAYER_DIFF = 25 # When player makes his answer, CPU will "think" no longer than this value
const ANSWER_RESULT_TIMEOUT_MAX_VALUE = 6
const ANSWER_RESULT_TIMEOUT_SPEED = 3

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")

# Params that are saved to config file
var language_id = LANGUAGE_EN
var target_quiz_count = QUIZ_COUNT_NORMAL
var music_volume = DEFAULT_VOLUME
var effects_volume = DEFAULT_VOLUME
var background_image = DEFAULT_BACKGROUND
var background_music = DEFAULT_MUSIC
var game_theme = GAME_THEME_DARK
var font_size = DEFAULT_FONT_SIZE
var answer_result_animation = DEFAULT_ANSWER_RESULT_ANIMATION
var opponent_type = OPPONENT_NONE
var lobby_type = LOBBY_PUBLIC

# Params that are NOT saved to config file
var last_session_id = 0
var category_ids_array
onready var click_sound_player_node = get_node("ClickSoundPlayer")
onready var music_bus_id = AudioServer.get_bus_index("Music")
onready var effects_bus_id = AudioServer.get_bus_index("Effects")
var backgrounds = {}
var music = {}

func abspath(relpath):
	var dir = Directory.new()
	dir.open(".")
	return dir.get_current_dir() + "/" + relpath

func list_files_in_directory(path, extension):
	var files = []
	
	var dir = Directory.new()
	if not dir.dir_exists(path):
		return files
	dir.open(path)
	dir.list_dir_begin()
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if file.ends_with(extension):
				files.append({"path": path, "file": file})
			elif dir.current_is_dir():
				var inner_files = list_files_in_directory(path + "/" + file, extension)
				if inner_files.size() == 0:
					continue
				for f in inner_files:
					files.append(f)
	
	dir.list_dir_end()
	return files

func get_victory_reward(score):
	if target_quiz_count == QUIZ_COUNT_LOW:
		return round(score * QUIZ_COUNT_LOW_REWARD_RATIO)
	elif target_quiz_count == QUIZ_COUNT_HIGH:
		return round(score * QUIZ_COUNT_HIGH_REWARD_RATIO)
	return round(score * QUIZ_COUNT_NORMAL_REWARD_RATIO)

func get_category_ids_as_string():
	var result = ""
	if not category_ids_array:
		return ""
	for i in range(0, category_ids_array.size() - 1):
		result = result + str(category_ids_array[i]) + ","
	result = result + str(category_ids_array[category_ids_array.size() - 1])
	return result

func get_category_ids_as_parameter_string():
	var result = ""
	if not category_ids_array:
		return ""
	for i in range(0, category_ids_array.size() - 1):
		result = result + "?, "
	result = result + "?"
	return result

func get_quizzes_query_parameters():
	var result = []
	for cat in category_ids_array:
		result.append(cat)
	result.append(language_id)
	result.append(target_quiz_count)
	return result

func parse_category_ids_from_string(category_ids_string):
	var arr = category_ids_string.split(",")
	var cat_ids_array = []
	for s in arr:
		cat_ids_array.push_back(int(s))
	return cat_ids_array

func get_last_session_stats():
	var result = {}
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return
	
	var session_stats_array = db.fetch_array_with_args("SELECT quiz_count, lives, is_win, is_opponent_win FROM sessions WHERE session_id = ?", [game_params.last_session_id])
	var has_data = session_stats_array and session_stats_array.size() > 0
	var lives = session_stats_array[0].lives if has_data else 0
	var is_win = session_stats_array[0].is_win if has_data else 0
	var is_opponent_win = session_stats_array[0].is_opponent_win if has_data else 0
	result["is_win"] = is_win
	result["is_opponent_win"] = is_opponent_win
	
	var answer_stats = db.fetch_array_with_args("SELECT player_id, COUNT(result_id) as cnt, answer_correct, SUM(reward) as total_reward FROM results WHERE session_id = ? GROUP BY player_id, answer_correct", [game_params.last_session_id])
	var r = {}
	for astat in answer_stats:
		if not r.has(astat.player_id):
			r[astat.player_id] = {
				"incorrect_answers" : 0,
				"correct_answers" : 0,
				"total_reward" : 0
			}
		var ri = r[astat.player_id]
		match astat.answer_correct:
			0:
				ri["incorrect_answers"] = astat.cnt
			1:
				ri["correct_answers"] = astat.cnt
				ri["total_reward"] = astat.total_reward
	
	for ri in r.values():
		#var quiz_count = session_stats_array[0].quiz_count if has_data else 0
		#var skipped_quizzes = quiz_count - ri.correct_answers - ri.incorrect_answers
		ri["remaining_lives"] = lives - ri.incorrect_answers
	
	result["by_player"] = r
	
	# Close stats database
	db.close()
	
	return result

func get_CPU_player_id():
	var player_id = -1
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return player_id
	
	var player_ids = db.fetch_array("SELECT player_id FROM players WHERE steam_id is NULL")
	player_id = player_ids[0].player_id if player_ids and player_ids.size() > 0 else -1
	if player_id < 0:
		print("ERROR: Invalid player_id = %d for CPU player" % player_id)
	
	# Close stats database
	db.close()
	
	return player_id

func get_self_player_id():
	var player_id = -1
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return player_id
	
	var player_ids = db.fetch_array("SELECT player_id FROM players WHERE steam_id = 0")
	player_id = player_ids[0].player_id if player_ids and player_ids.size() > 0 else -1
	if player_id < 0:
		print("ERROR: Invalid player_id = %d for current player" % player_id)
	
	# Close stats database
	db.close()
	
	return player_id

func add_or_update_player(steam_ID, player_name):
	var player_id = -1
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return player_id
	
	var player_ids = db.fetch_array_with_args("SELECT player_id FROM players WHERE steam_id = ?", [steam_ID])
	player_id = player_ids[0].player_id if player_ids and player_ids.size() > 0 else -1
	if player_id < 0:
		# If such player does not exist, insert the new one
		db.query_with_args("INSERT INTO players (steam_id, player_name) VALUES (?, ?);", [steam_ID, player_name])
		player_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
	else:
		db.query_with_args("UPDATE players SET player_name = ? WHERE player_id = ?", [player_name, player_id])
	
	# Close stats database
	db.close()
	
	return player_id

# Returns category names from the corresponding ids array using the language of the local user
func get_cat_names(db, cat_ids_array):
	var category_names = ""
	var category_id
	for i in range(0, cat_ids_array.size()):
		category_id = cat_ids_array[i]
		var cats = db.fetch_array_with_args("SELECT category_name FROM category_texts WHERE language_id = ? AND category_id = ?", [game_params.language_id, category_id])
		var sep = ", " if i < cat_ids_array.size() - 1 else ""
		if not cats.empty():
			category_names = category_names + cats[0].category_name + sep
	return category_names

func get_all_cats(db):
	return db.fetch_array_with_args("SELECT category_id FROM category_texts WHERE language_id = ?", [game_params.language_id])

func get_lobby_info():
	var result = { "target_quiz_count" : target_quiz_count, "category_ids" : get_category_ids_as_string() }
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return result
	
	var allcats = get_all_cats(db)
	if allcats.size() == category_ids_array.size():
		result["category_names"] = tr("PARAMS_CATEGORIES_ALL")
	else:
		result["category_names"] = get_cat_names(db, category_ids_array)
	
	# Close database
	db.close()
	return result

func load_settings():
	var f = File.new()
	var error = f.open("user://settings.json", File.READ)

	if (error):
		print("no settings to load.")
		return

	var d = parse_json( f.get_as_text() )
	if (typeof(d)!=TYPE_DICTIONARY):
		return

	if ("language_id" in d):
		language_id = int(d.language_id)

	if ("music_volume" in d):
		music_volume = int(d.music_volume)

	if ("effects_volume" in d):
		effects_volume = int(d.effects_volume)
	
	if ("background_image" in d):
		background_image = str(d.background_image)
	
	if ("background_music" in d):
		background_music = str(d.background_music)
	
	if ("game_theme" in d):
		game_theme = int(d.game_theme)
	
	if ("font_size" in d):
		font_size = int(d.font_size)
	
	if ("answer_result_animation" in d):
		answer_result_animation = bool(d.answer_result_animation)
	
	if ("opponent_type" in d):
		opponent_type = int(d.opponent_type)
	
	if ("lobby_type" in d):
		lobby_type = int(d.lobby_type)

func save_settings():
	var f = File.new()
	var error = f.open("user://settings.json", File.WRITE)
	assert( not error )
	
	var d = {
		"language_id" : language_id,
		"target_quiz_count" : target_quiz_count,
		"music_volume" : music_volume,
		"effects_volume" : effects_volume,
		"background_image" : background_image,
		"background_music" : background_music,
		"game_theme" : game_theme,
		"font_size" : font_size,
		"answer_result_animation" : answer_result_animation,
		"opponent_type" : opponent_type,
		"lobby_type" : lobby_type
	}
	f.store_line( to_json(d) )

func play_click():
	click_sound_player_node.play()

func set_music_volume(level):
	# level in [0, 100] => volume from -30 dB to 0 dB
	var volume_db = 0.3 * level - 30
	var player = $MusicPlayer
	if level > 0:
		AudioServer.set_bus_volume_db(music_bus_id, volume_db)
		if not player.playing:
			player.play()
	else:
		player.stop()

func reset_music_volume():
	set_music_volume(music_volume)

func set_effects_volume(level):
	# level in [0, 100] => volume from -30 dB to 0 dB
	var volume_db = 0.3 * level - 30
	if level > 0:
		AudioServer.set_bus_mute(effects_bus_id, false)
		AudioServer.set_bus_volume_db(effects_bus_id, volume_db)
	else:
		AudioServer.set_bus_mute(effects_bus_id, true)

func reset_effects_volume():
	set_effects_volume(effects_volume)

func reset_background_music():
	change_music_to(background_music)

func add_background(image_file):
	if backgrounds.has(image_file):
		return backgrounds[image_file]
	var image = Image.new()
	image.load(abspath("backgrounds/" + image_file))
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	backgrounds[image_file] = texture
	return backgrounds[image_file]

func add_music(music_file):
	if music.has(music_file):
		return music[music_file]
	var ogg_file = File.new()
	ogg_file.open(abspath("music/" + music_file), File.READ)
	var bytes = ogg_file.get_buffer(ogg_file.get_len())
	var stream = AudioStreamOGGVorbis.new()
	stream.data = bytes
	music[music_file] = stream
	return music[music_file]

func init_styles(texture_rect):
	change_background(texture_rect)
	texture_rect.theme.default_font.size = font_size

func change_background(texture_rect):
	texture_rect.texture = backgrounds[background_image]

func change_background_to(texture_rect, image_file_name):
	texture_rect.texture = backgrounds[image_file_name]

func change_music_to(music_file_name):
	$MusicPlayer.stream = music[music_file_name]
	$MusicPlayer.play()

func is_event_cancel_action(event):
	var is_key = event is InputEventKey
	var is_joy = event is InputEventJoypadButton
	if not is_key and not is_joy:
		return false
	return event.is_action_pressed("ui_cancel")

func _ready():
	load_settings()
	add_background(background_image)
	add_music(background_music)
	reset_background_music()
	reset_music_volume()
	reset_effects_volume()

func _on_MusicPlayer_finished():
	# Make the loop programmatically, because loop in ogg import parameters doesn't work if the track is assigned programmatically
	$MusicPlayer.play()
