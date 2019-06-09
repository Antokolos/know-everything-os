extends TextureRect

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")
const COLOR_WIN = Color(0, 1, 0)
const COLOR_LOSE = Color(1, 0, 0)

onready var stats_grid_node = get_node("VBoxContainer/HBoxStats/VBoxStats/StatsGrid")
onready var player_grid_node = get_node("VBoxContainer/HBoxStats/VBoxStats/StatsGrid/PlayerGrid")
onready var opponent_grid_node = get_node("VBoxContainer/HBoxStats/VBoxStats/StatsGrid/OpponentGrid")
onready var player_name_node = stats_grid_node.get_node("PlayerName")
onready var opponent_name_node = stats_grid_node.get_node("OpponentName")
onready var correct_answers_quantity_node = player_grid_node.get_node("CorrectAnswersQuantity")
onready var opponent_correct_answers_quantity_node = opponent_grid_node.get_node("OpponentCorrectAnswersQuantity")
onready var correct_answers_value_node = player_grid_node.get_node("CorrectAnswersValue")
onready var opponent_correct_answers_value_node = opponent_grid_node.get_node("OpponentCorrectAnswersValue")
onready var remaining_lives_quantity_node = player_grid_node.get_node("RemainingLivesQuantity")
onready var opponent_remaining_lives_quantity_node = opponent_grid_node.get_node("OpponentRemainingLivesQuantity")
onready var remaining_lives_value_node = player_grid_node.get_node("RemainingLivesValue")
onready var opponent_remaining_lives_value_node = opponent_grid_node.get_node("OpponentRemainingLivesValue")
onready var total_value_node = player_grid_node.get_node("TotalValue")
onready var opponent_total_value_node = opponent_grid_node.get_node("OpponentTotalValue")
onready var win_node = player_grid_node.get_node("WinQuantity")
onready var opponent_win_node = opponent_grid_node.get_node("OpponentWinQuantity")
onready var win_value_node = player_grid_node.get_node("WinValue")
onready var opponent_win_value_node = opponent_grid_node.get_node("OpponentWinValue")
onready var next_node = get_node("VBoxContainer/HBoxControls/Next")

onready var firework = preload("res://firework.tscn")

func _ready():
	game_params.init_styles(self)
	player_name_node.text = godotsteam.get_player_name()
	opponent_name_node.text = godotsteam.get_opponent_name()
	var player_id = game_params.get_self_player_id()
	var cpu_player_id = game_params.get_CPU_player_id()
	var stats = game_params.get_last_session_stats()
	
	if stats["is_win"]:
		add_child(firework.instance())
		add_child(firework.instance())
		add_child(firework.instance())
		win_node.text = tr("RES_WIN_YES")
		win_node.set("custom_colors/font_color", COLOR_WIN)
		$PlayerWin.play()
	else:
		win_node.text = tr("RES_WIN_NO")
		win_node.set("custom_colors/font_color", COLOR_LOSE)
		$PlayerLose.play()
	
	var player_total = 0
	var is_opponent_human = false
	for id in stats["by_player"].keys():
		var stat = stats["by_player"][id]
		if id == player_id:
			player_total = game_params.get_victory_reward(stat["total_reward"]) if stats["is_win"] else 0
			win_value_node.text = str(player_total)
			correct_answers_quantity_node.text = str(stat["correct_answers"])
			player_total = player_total + stat["total_reward"]
			correct_answers_value_node.text = str(stat["total_reward"])
			remaining_lives_quantity_node.text = str(stat["remaining_lives"])
			total_value_node.text = str(player_total)
		else:
			is_opponent_human = (id != cpu_player_id)
			stats_grid_node.columns = 3
			opponent_name_node.visible = true
			opponent_grid_node.visible = true
			var total = game_params.get_victory_reward(stat["total_reward"]) if stats["is_opponent_win"] else 0
			opponent_win_value_node.text = str(total)
			opponent_correct_answers_quantity_node.text = str(stat["correct_answers"])
			total = total + stat["total_reward"]
			opponent_correct_answers_value_node.text = str(stat["total_reward"])
			opponent_remaining_lives_quantity_node.text = str(stat["remaining_lives"])
			opponent_total_value_node.text = str(total)
			if stats["is_opponent_win"]:
				opponent_win_node.text = tr("RES_WIN_YES")
				opponent_win_node.set("custom_colors/font_color", COLOR_WIN)
			else:
				opponent_win_node.text = tr("RES_WIN_NO")
				opponent_win_node.set("custom_colors/font_color", COLOR_LOSE)
	
	godotsteam.append_leaderboard_score(
		godotsteam.LEADERBOARD_MULTIPLAYER if is_opponent_human else godotsteam.LEADERBOARD_SINGLEPLAYER,
		player_total
	)
	next_node.grab_focus()

func _on_Next_pressed():
	godotsteam.disconnect_from_opponent()
	return get_tree().change_scene("res://main.tscn")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Next_pressed()