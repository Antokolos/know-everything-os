extends TextureRect

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")

onready var games_played_node = get_node("VBoxContainer/HBoxGameStats/GridContainer/GamesPlayedValue")
onready var wins_node = get_node("VBoxContainer/HBoxGameStats/GridContainer/WinsValue")
onready var losses_node = get_node("VBoxContainer/HBoxGameStats/GridContainer/LossesValue")
onready var stats_grid = get_node("VBoxContainer/HBoxStats/StatsGrid")
onready var category_name_node = get_node("VBoxContainer/HBoxStats/StatsGrid/CategoryAll")
onready var category_correct_answers_node = get_node("VBoxContainer/HBoxStats/StatsGrid/CorrectAnswersAll")
onready var category_incorrect_answers_node = get_node("VBoxContainer/HBoxStats/StatsGrid/IncorrectAnswersAll")
onready var category_total_answers_node = get_node("VBoxContainer/HBoxStats/StatsGrid/TotalAnswersAll")
onready var back_node = get_node("VBoxContainer/HBoxControls/Back")

func _ready():
	game_params.init_styles(self)
	var player_id = game_params.get_self_player_id()
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	# Open player stats from its database file
	# see https://stackoverflow.com/questions/9410011/multiple-files-for-a-single-sqlite-database
	db.query("ATTACH DATABASE 'stats.db' AS stats;")
	
	var wins_losses = db.fetch_array("SELECT COUNT(*) as total_games, SUM(CASE WHEN is_win = 1 THEN 1 ELSE 0 END) as wins, SUM(CASE WHEN is_win = 0 THEN 1 ELSE 0 END) as losses FROM stats.sessions")
	var wins_losses_exist = wins_losses and wins_losses.size() > 0
	var total_games = wins_losses[0].total_games if wins_losses_exist else 0
	var wins = wins_losses[0].wins if total_games > 0 else 0
	var losses = wins_losses[0].losses if total_games > 0 else 0
	games_played_node.text = str(total_games)
	wins_node.text = str(wins)
	losses_node.text = str(losses)
	
	var correct_answers_total = 0
	var incorrect_answers_total = 0
	var cats = db.fetch_array_with_args("SELECT category_id, category_name FROM category_texts WHERE language_id = ?", [game_params.language_id])
	for cat in cats:
		var category_id = int(cat.category_id)
		var category_name = str(cat.category_name)
		var name_node = category_name_node.duplicate(0)
		name_node.text = category_name
		var answer_stats = db.fetch_array_with_args("SELECT COUNT(sr.result_id) as cnt, sr.answer_correct FROM stats.results sr, quizzes q WHERE sr.player_id = ? AND sr.quiz_id = q.quiz_id AND q.category_id = ? GROUP BY sr.answer_correct", [player_id, category_id])
		var correct_answers = 0
		var incorrect_answers = 0
		for astat in answer_stats:
			match astat.answer_correct:
				0:
					incorrect_answers = astat.cnt
				1:
					correct_answers = astat.cnt
		correct_answers_total = correct_answers_total + correct_answers
		incorrect_answers_total = incorrect_answers_total + incorrect_answers
		var correct_answers_node = category_correct_answers_node.duplicate(0)
		correct_answers_node.text = str(correct_answers)
		var incorrect_answers_node = category_incorrect_answers_node.duplicate(0)
		incorrect_answers_node.text = str(incorrect_answers)
		var total_answers_node = category_total_answers_node.duplicate(0)
		total_answers_node.text = str(correct_answers + incorrect_answers)
		stats_grid.add_child(name_node)
		stats_grid.add_child(correct_answers_node)
		stats_grid.add_child(incorrect_answers_node)
		stats_grid.add_child(total_answers_node)
	
	category_correct_answers_node.text = str(correct_answers_total)
	category_incorrect_answers_node.text = str(incorrect_answers_total)
	category_total_answers_node.text = str(correct_answers_total + incorrect_answers_total)
	
	# Close database
	db.close()
	back_node.grab_focus()

func _on_Back_pressed():
	return get_tree().change_scene("res://main.tscn")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()