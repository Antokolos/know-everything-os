extends TextureRect

const FETCH_QUIZZES_QUERY_TEMPLATE = "SELECT l.language_code, ct.category_name, q.quiz_id, q.answer_group_id FROM quizzes q, category_texts ct, languages l WHERE q.category_id in (%s) AND ct.category_id = q.category_id AND l.language_id = ct.language_id AND ct.language_id = ? ORDER BY RANDOM() LIMIT ?"

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")
const PROCESS_THRESHOLD_SECONDS = 0.1
const TIMEOUT_COLORS = [
Color(1, 0, 0),
Color(1, 0.22, 0),
Color(1, 0.44, 0),
Color(1, 0.66, 0),
Color(1, 0.88, 0),
Color(0.88, 1, 0),
Color(0.66, 1, 0),
Color(0.44, 1, 0),
Color(0.22, 1, 0),
Color(0.11, 1, 0),
Color(0, 1, 0)
]

onready var player_name_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/LabelPlayerName")
onready var opponent_lives_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives")
onready var opponent_name_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/LabelOpponentName")
onready var category_node = get_node("Panel/VBoxContainer/HBoxConfirm/Panel/category")
onready var quiz_number_node = get_node("Panel/VBoxContainer/HBoxConfirm/Panel2/quiz_number")
onready var text_panel_node = get_node("Panel/VBoxContainer/HBoxQuestion/TextPanel")
onready var inner_text_panel_node = text_panel_node.get_node("Panel")
onready var quiz_node = inner_text_panel_node.get_node("QuizText")
onready var media_panel_node = get_node("Panel/VBoxContainer/HBoxQuestion/MediaPanel")
onready var media_node = media_panel_node.get_node("Panel/TextureRect")
onready var confirm_button = get_node("Panel/VBoxContainer/HBoxConfirm/Confirm")
onready var next_button = get_node("Panel/VBoxContainer/HBoxConfirm/Next")
onready var quit_button = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxInfo/HBoxScore/HBoxQuit/VBoxQuit/ButtonQuit")
onready var player_wrong = get_node("PlayerWrong")
onready var player_correct = get_node("PlayerCorrect")
onready var score_label_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxInfo/HBoxScore/PlayerScoreLabel")
onready var opponent_score_label_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxInfo/HBoxScore/OpponentScoreLabel")
onready var timer_progress_node = get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxInfo/HBoxTimer")
onready var label_reward_node = timer_progress_node.get_node("LabelReward")
onready var timer_progress_bar_node = timer_progress_node.get_node("ProgressBar")
onready var answer_panel_1_node = get_node("Panel/VBoxContainer/HBoxAnswers1/Panel")
onready var answer_panel_2_node = get_node("Panel/VBoxContainer/HBoxAnswers1/Panel2")
onready var answer_panel_3_node = get_node("Panel/VBoxContainer/HBoxAnswers2/Panel")
onready var answer_panel_4_node = get_node("Panel/VBoxContainer/HBoxAnswers2/Panel2")

onready var answer_nodes = [
answer_panel_1_node.get_node("Panel/VBoxContainer/Answer1"),
answer_panel_2_node.get_node("Panel/VBoxContainer/Answer2"),
answer_panel_3_node.get_node("Panel/VBoxContainer/Answer3"),
answer_panel_4_node.get_node("Panel/VBoxContainer/Answer4")
]

onready var gamepad_hints = [
answer_panel_1_node.get_node("Panel/VBoxContainer/HBoxContainer/LabelGamepadHint"),
answer_panel_2_node.get_node("Panel/VBoxContainer/HBoxContainer/LabelGamepadHint"),
answer_panel_3_node.get_node("Panel/VBoxContainer/HBoxContainer/LabelGamepadHint"),
answer_panel_4_node.get_node("Panel/VBoxContainer/HBoxContainer/LabelGamepadHint")
]

onready var life_nodes = [
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/HBoxLives/Life1"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/HBoxLives/Life2"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/HBoxLives/Life3"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/HBoxLives/Life4"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxPlayerLives/HBoxLives/Life5")
]
var lifes_idx = game_params.TOTAL_LIVES - 1
var score = 0

onready var opponent_life_nodes = [
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/HBoxLives/Life1"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/HBoxLives/Life2"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/HBoxLives/Life3"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/HBoxLives/Life4"),
get_node("Panel/VBoxContainer/PanelLives/HBoxLives/VBoxOpponentLives/HBoxLives/Life5")
]
var opponent_lifes_idx = 0
var opponent_score = 0

onready var life_empty = load("res://styles/life_empty.tres")
onready var answer_selected = load("res://styles/dark_answer_selected.tres") if game_params.game_theme == game_params.GAME_THEME_DARK else load("res://styles/light_answer_selected.tres")
onready var answer_inner = load("res://styles/dark_inner.tres") if game_params.game_theme == game_params.GAME_THEME_DARK else load("res://styles/light_inner.tres")
onready var answer_correct = load("res://styles/answer_correct.tres")
onready var answer_missed = load("res://styles/answer_missed.tres")
onready var answer_error = load("res://styles/answer_error.tres")
onready var style_opponent_has_answer = load("res://styles/answer_missed.tres")

# Setup parameters
var language_id
var need_next_button = false

# Gameplay parameters
var session_id = 0
var quizzes = []
var current_quiz_idx = 0
var current_quiz_question = {}
var opponent_ready = false
var player_id = -1
var opponent_player_id = -1
var answer_accepted = false
var opponent_answer_present = false
var opponent_answer_accepted = false
var answer_ids = [0, 0, 0, 0]
var answer_selection = [false, false, false, false]
var opponent_answer_selection = [false, false, false, false] # will be updated in has_opponent_answer()
var correct_answers = [false, false, false, false]
var cpu_opponent_progress_threshold = 0
var answer_result_timeout = 0
var correct_answer_reward = game_params.CORRECT_ANSWER_REWARD_MIN
var opponent_correct_answer_reward = game_params.CORRECT_ANSWER_REWARD_MAX
var allow_next = true
var opponent_lost = false
var last_synced_time = game_params.QUESTION_TIMER_MAX_VALUE

func _ready():
	game_params.init_styles(self)
	player_name_node.text = godotsteam.get_player_name()
	opponent_name_node.text = godotsteam.get_opponent_name()
	opponent_lives_node.visible = has_opponent()
	
	player_id = game_params.get_self_player_id()
	if has_cpu_opponent():
		opponent_player_id = game_params.get_CPU_player_id()
	elif has_human_opponent() and godotsteam.opponent:
		opponent_player_id = game_params.add_or_update_player(godotsteam.opponent.steam_ID, godotsteam.get_opponent_name())
	
	score_label_node.text = str(score)
	opponent_score_label_node.visible = has_opponent()
	opponent_score_label_node.text = str(opponent_score)
	quiz_node.text = tr("GAME_LOADING")
	timer_progress_node.visible = has_opponent()
	opponent_ready = not has_human_opponent()
	godotsteam.leave_lobby() # We are leaving the lobby and starting the game
	apply_game_theme()
	inner_text_panel_node.set("custom_styles/panel", answer_inner)
	self.language_id = game_params.language_id
	# Register event to monitor if joystick connected or disconnected
	if not Input.connect("joy_connection_changed",self,"_on_joy_connection_changed"):
		print("Cannot connect joy_connection_changed signal")

# Returns true if connected joypads are present, false otherwise
func has_joypads():
	return Input.get_connected_joypads().size() > 0

func _on_joy_connection_changed(device_id, is_connected):
	show_gamepad_hints(has_joypads())
	rebuild_confirm_button_text()
	rebuild_next_button_text()

func show_gamepad_hints(visible):
	for gamepad_hint in gamepad_hints:
		gamepad_hint.visible = visible

func apply_game_theme():
	var is_dark = game_params.game_theme == game_params.GAME_THEME_DARK
	var outer_theme = load("res://styles/dark_outer.tres") if is_dark else load("res://styles/light_outer.tres")
	var font_color = Color(1, 1, 1) if is_dark else Color(0, 0, 0)
	text_panel_node.set("custom_styles/panel", outer_theme)
	quiz_node.set("custom_colors/font_color", font_color)
	media_panel_node.set("custom_styles/panel", outer_theme)
	answer_panel_1_node.set("custom_styles/panel", outer_theme)
	answer_panel_2_node.set("custom_styles/panel", outer_theme)
	answer_panel_3_node.set("custom_styles/panel", outer_theme)
	answer_panel_4_node.set("custom_styles/panel", outer_theme)
	for answer_node in answer_nodes:
		answer_node.set("custom_colors/font_color", font_color)
		var label_player = answer_node.get_parent().get_node("HBoxContainer/LabelPlayer")
		label_player.set("custom_colors/font_color", font_color)
		var label_opponent = answer_node.get_parent().get_node("HBoxContainer/LabelOpponent")
		label_opponent.set("custom_colors/font_color", font_color)

func get_correct_answer_reward():
	return ceil(game_params.CORRECT_ANSWER_REWARD_MAX * (timer_progress_bar_node.value / game_params.QUESTION_TIMER_MAX_VALUE))

func get_timeout_color():
	var idx = floor((TIMEOUT_COLORS.size() - 1) * (timer_progress_bar_node.value / game_params.QUESTION_TIMER_MAX_VALUE))
	return TIMEOUT_COLORS[idx]

func process_input():
	if Input.is_action_just_pressed("upper_left"):
		var ev = InputEventMouseButton.new()
		ev.pressed = true
		_on_Answer1_gui_input(ev)
	if Input.is_action_just_pressed("upper_right"):
		var ev = InputEventMouseButton.new()
		ev.pressed = true
		_on_Answer2_gui_input(ev)
	if Input.is_action_just_pressed("lower_left"):
		var ev = InputEventMouseButton.new()
		ev.pressed = true
		_on_Answer3_gui_input(ev)
	if Input.is_action_just_pressed("lower_right"):
		var ev = InputEventMouseButton.new()
		ev.pressed = true
		_on_Answer4_gui_input(ev)
	if Input.is_action_just_pressed("ui_accept"):
		_on_Confirm_pressed()
	if need_next_button and answer_accepted and Input.is_action_just_pressed("ui_select"):
		_on_Next_pressed()
	if Input.is_action_just_pressed("input_select"):
		_on_ButtonQuit_pressed()

func process_timer_changes(delta):
	if has_human_opponent() and godotsteam.has_packet_with_code(godotsteam.CODE_TIMESYNC):
		var opponent_time = godotsteam.peek_packet_with_code(godotsteam.CODE_TIMESYNC)
		if opponent_time < timer_progress_bar_node.value:
			timer_progress_bar_node.value = opponent_time
			timer_progress_bar_node.set_self_modulate(get_timeout_color())
	else:
		timer_progress_bar_node.value = timer_progress_bar_node.value - delta * game_params.QUESTION_TIMER_SPEED
		if last_synced_time - timer_progress_bar_node.value > game_params.QUESTION_TIMER_SPEED:
			last_synced_time = timer_progress_bar_node.value
			timer_progress_bar_node.set_self_modulate(get_timeout_color())
			if has_human_opponent() and godotsteam.opponent and not (answer_accepted and opponent_answer_accepted):
				godotsteam.send_timesync(godotsteam.opponent.steam_ID, last_synced_time)

func _process(delta):
	if not opponent_lost:
		opponent_lost = has_human_opponent() and godotsteam.peek_packet_with_code(godotsteam.CODE_LOST)
	if not quizzes.empty():
		process_input()
		opponent_name_node.set("custom_styles/normal", style_opponent_has_answer if has_opponent_answer() else null)
		# Show opponent answer, if any, only when player's answer is already accepted
		if answer_accepted and has_opponent_answer():
			if not opponent_answer_accepted:
				check_opponent_answer()
				return
		
		if has_opponent():
			var question_activated = current_quiz_question.empty()
			if question_activated:
				process_timer_changes(delta)
			var reward = get_correct_answer_reward()
			label_reward_node.text = str(reward)
			if not answer_accepted:
				correct_answer_reward = reward
				if timer_progress_bar_node.value <= 0:
					_on_Confirm_pressed()
					return
		
		if answer_result_timeout > 0:
			answer_result_timeout = answer_result_timeout - delta * game_params.ANSWER_RESULT_TIMEOUT_SPEED
			return
		if opponent_lost:
			win()
			return
		if not allow_next:
			if has_human_opponent() and godotsteam.peek_packet_with_code(godotsteam.CODE_ALLOW_NEXT):
				allow_next = true
				answer_result_timeout = 0
			else:
				return
		if has_human_opponent() and not opponent_ready:
			opponent_ready = godotsteam.peek_packet_with_code(godotsteam.CODE_QUIZDATA_ACCEPTED)
			return
		next_question()
		return
	
	if has_human_opponent() and godotsteam.opponent and godotsteam.opponent.owner:
		# Waiting for quizzes array from lobby owner...
		if godotsteam.has_packet_with_code(godotsteam.CODE_QUIZDATA):
			quizzes = godotsteam.peek_packet_with_code(godotsteam.CODE_QUIZDATA)
			opponent_ready = true
			var steamIDRemote = godotsteam.opponent.steam_ID
			godotsteam.send_quizdata_accepted(steamIDRemote)
			append_session_row(quizzes.size())
	else:
		quizzes = fetch_quizzes_db()
		if has_human_opponent() and godotsteam.opponent:
			var steamIDRemote = godotsteam.opponent.steam_ID
			godotsteam.send_quizdata(steamIDRemote, quizzes)
		append_session_row(quizzes.size())

func has_cpu_opponent():
	return game_params.opponent_type == game_params.OPPONENT_CPU

func has_human_opponent():
	return game_params.opponent_type == game_params.OPPONENT_HUMAN

func has_opponent():
	return game_params.opponent_type != game_params.OPPONENT_NONE

func has_opponent_answer():
	if opponent_answer_present:
		return true
	if has_cpu_opponent():
		if cpu_opponent_progress_threshold > timer_progress_bar_node.value:
			opponent_answer_selection = get_cpu_opponent_answer_selection()
			opponent_correct_answer_reward = get_correct_answer_reward()
			opponent_answer_present = true
			return true
	elif has_human_opponent():
		var has_answer = godotsteam.has_packet_with_code(godotsteam.CODE_QUIZANSWER)
		if not has_answer:
			return false
		var quiz_answer = godotsteam.peek_packet_with_code(godotsteam.CODE_QUIZANSWER)
		opponent_answer_selection = quiz_answer.answer_selection
		opponent_correct_answer_reward = quiz_answer.correct_answer_reward
		opponent_answer_present = true
		return true
	return false

func get_cpu_opponent_answer_selection():
	var result = []
	# Make the answer wrong with some probability
	randomize()
	var pstart = game_params.CPU_OPPONENT_CORRECT_ANSWER_PROBABILITY_START
	var lifes = game_params.TOTAL_LIVES
	var p = pstart + opponent_lifes_idx * ((1.0 - pstart) / lifes)
	if rand_range(0.0, 1.0) < p:
		for a in correct_answers:
			result.push_back(a)
	else:
		while true:
			var wrong_answers = [false, false, false, false]
			wrong_answers[randi() % wrong_answers.size()] = true
			# Make sure that wrong answer is truly wrong
			for i in range(0, correct_answers.size()):
				if correct_answers[i] != wrong_answers[i]:
					return wrong_answers
	return result

func check_opponent_answer():
	var has_errors = check_and_highlight_answers(true, opponent_answer_selection, false)
	if has_errors:
		opponent_life_nodes[opponent_lifes_idx].set("custom_styles/panel", life_empty)
		opponent_lifes_idx = opponent_lifes_idx + 1
	else:
		opponent_score = opponent_score + opponent_correct_answer_reward
		opponent_score_label_node.text = str(opponent_score)
	answer_result_timeout = game_params.ANSWER_RESULT_TIMEOUT_MAX_VALUE
	opponent_answer_accepted = true
	return not has_errors

func append_session_row(quiz_count):
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return
	
	# Note that initial value for is_win is 0, it should be changed to 1 if the player actually wins
	# Note that initial value for is_opponent_win is 0, it should be changed to 1 if the opponent actually wins
	db.query_with_args("INSERT INTO sessions (timestamp, quiz_count, lives, is_win, is_opponent_win) VALUES (strftime('%s','now'), ?, ?, 0, 0);", [quiz_count, game_params.TOTAL_LIVES])
	session_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
	game_params.last_session_id = session_id
	
	# Close stats database
	db.close()

func fetch_quizzes_db():
	var q
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	current_quiz_idx = 0
	var query = FETCH_QUIZZES_QUERY_TEMPLATE % game_params.get_category_ids_as_parameter_string()
	q = db.fetch_array_with_args(query, game_params.get_quizzes_query_parameters())
	if not q:
		print("Error fetching quizzes from database!")
	
	# Close database
	db.close()
	return q

func assign_media(mediafile):
	if mediafile:
		media_panel_node.visible = true
		var image = Image.new()
		image.load(mediafile.path + "/" + mediafile.file)
		var texture = ImageTexture.new()
		texture.create_from_image(image)
		media_node.texture = texture
	else:
		media_node.texture = null
		media_panel_node.visible = false

func find_media_files(language_code, quiz_id, is_full):
	var dirpath = game_params.abspath("media/quiz/" + str(quiz_id))
	if is_full:
		var dirpath_full = dirpath + "/full/"
		var mediafiles_full = game_params.list_files_in_directory(dirpath_full, ["png", "svg"], false)
		if not mediafiles_full.empty():
			return mediafiles_full
	return game_params.list_files_in_directory(dirpath, ["png", "svg"], false)

func find_media(language_code, quiz_id, is_full):
	var mediafiles = find_media_files(language_code, quiz_id, is_full)
	var lang_suffix_template = "_" + language_code + ".%s"
	var lang_suffix_template_default = "_en.%s"
	var default_media = null
	for mediafile in mediafiles:
		if game_params.ends_with_one_of(mediafile.file, lang_suffix_template, ["png", "svg"]):
			return mediafile
		if game_params.ends_with_one_of(mediafile.file, lang_suffix_template_default, ["png", "svg"]):
			default_media = mediafile
	return default_media

func fetch_quiz_question_db():
	var quiz_question = {}
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return quiz_question
	
	var quiz_id = quizzes[current_quiz_idx].quiz_id
	quiz_question["quiz_text_data"] = db.fetch_array_with_args("SELECT quiz_text FROM quiz_texts WHERE quiz_id = ? AND language_id = ?", [quiz_id, language_id])
	var answer_group_id = quizzes[current_quiz_idx].answer_group_id
	quiz_question["answers"] = db.fetch_array_with_args("SELECT a.answer_id, a.correct, at.answer_text FROM answers a, answer_texts at WHERE a.answer_group_id = ? AND at.language_id = ? AND a.answer_id = at.answer_id ORDER BY RANDOM()", [answer_group_id, language_id])

	# Close database
	db.close()
	
	return quiz_question

func refetch_quiz_question_db(opponent_quiz_question):
	var quiz_question = {}
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return quiz_question
	
	var quiz_id = quizzes[current_quiz_idx].quiz_id
	quiz_question["quiz_text_data"] = db.fetch_array_with_args("SELECT quiz_text, quiz_id FROM quiz_texts WHERE quiz_id = ? AND language_id = ?", [quiz_id, language_id])
	if not quiz_question["quiz_text_data"] or quiz_question["quiz_text_data"].empty():
		quiz_question["quiz_text_data"] = opponent_quiz_question["quiz_text_data"]
	
	var answers = []
	for opponent_answer in opponent_quiz_question["answers"]:
		var answer_arr = db.fetch_array_with_args("SELECT a.answer_id, a.correct, at.answer_text FROM answers a, answer_texts at WHERE a.answer_id = ? AND at.language_id = ? AND a.answer_id = at.answer_id", [opponent_answer.answer_id, language_id])
		var answer = answer_arr[0] if answer_arr and not answer_arr.empty() else opponent_answer
		answers.push_back(answer)
	quiz_question["answers"] = answers

	# Close database
	db.close()
	
	return quiz_question

func next_question():
	if current_quiz_idx > 0:
		if not answer_accepted:
			return false
		if has_opponent() and not opponent_answer_accepted:
			return false
		if answer_result_timeout > 0:
			return false
	
	if lifes_idx < 0:
		lose()
		return false
	
	if opponent_lifes_idx >= game_params.TOTAL_LIVES:
		win()
		return false
	
	if current_quiz_idx >= quizzes.size():
		if score > opponent_score:
			win()
		elif score < opponent_score:
			lose()
		elif opponent_lifes_idx < game_params.TOTAL_LIVES - 1 - lifes_idx:
			lose()
		else:
			# Both players wins
			set_opponent_win()
			win()
		return false
	
	if has_human_opponent() and godotsteam.opponent and godotsteam.opponent.owner:
		if godotsteam.has_packet_with_code(godotsteam.CODE_QUIZQUESTION):
			current_quiz_question = refetch_quiz_question_db(godotsteam.peek_packet_with_code(godotsteam.CODE_QUIZQUESTION))
			godotsteam.send_quizquestion_accepted(godotsteam.opponent.steam_ID)
			next_question_fill()
			return true
	else:
		if current_quiz_question.empty():
			current_quiz_question = fetch_quiz_question_db()
			if has_human_opponent() and godotsteam.opponent and not godotsteam.opponent.owner:
				godotsteam.send_quizquestion(godotsteam.opponent.steam_ID, current_quiz_question)
		if not has_human_opponent() or (godotsteam.peek_packet_with_code(godotsteam.CODE_QUIZQUESTION_ACCEPTED)):
			next_question_fill()
			return true
	return false

func clear_current_answers():
	var ai = 0
	for answer_node in answer_nodes:
		clear_answer(ai)
		if has_opponent():
			opponent_answer_selection[ai] = false
		inscribe_name(answer_node, true, true)
		inscribe_name(answer_node, false, true)
		ai = ai + 1

func next_question_fill():
	if current_quiz_question.empty():
		return
	
	log_current_answers()
	clear_current_answers()
	show_gamepad_hints(has_joypads())
	
	var quiz_text_data = current_quiz_question.quiz_text_data
	var answers = current_quiz_question.answers
	var quiz_id = quizzes[current_quiz_idx].quiz_id
	var category_name = quizzes[current_quiz_idx].category_name
	category_node.text = category_name
	quiz_number_node.text = "%d / %d" % [current_quiz_idx + 1, quizzes.size()]
	var language_code = quizzes[current_quiz_idx].language_code
	assign_media(find_media(language_code, quiz_id, false))
	quiz_node.text = "" if quiz_text_data.empty() else StringUtil.Decrypt(quiz_text_data[0].quiz_text)
	var ai = 0
	var is_multiselect = false
	var has_correct = false
	for answer in answers:
		answer_ids[ai] = answer.answer_id
		correct_answers[ai] = answer.correct == 1
		if correct_answers[ai]:
			if has_correct:
				is_multiselect = true
			has_correct = true
		answer_nodes[ai].text = StringUtil.Decrypt(answer.answer_text)
		ai = ai + 1
	if is_multiselect:
		quiz_node.text = quiz_node.text + " " + tr("GAME_ALL_THAT_APPLY")
	current_quiz_idx = current_quiz_idx + 1
	answer_accepted = false
	opponent_answer_present = false
	opponent_answer_accepted = false
	if has_opponent():
		correct_answer_reward = game_params.CORRECT_ANSWER_REWARD_MAX
		opponent_correct_answer_reward = game_params.CORRECT_ANSWER_REWARD_MAX
	confirm_button.hide()
	next_button.hide()
	if has_opponent():
		if has_cpu_opponent():
			randomize()
			cpu_opponent_progress_threshold = int(rand_range(game_params.CPU_OPPONENT_THRESHOLD_MIN_VALUE, game_params.CPU_OPPONENT_THRESHOLD_MAX_VALUE))
		timer_progress_bar_node.value = game_params.QUESTION_TIMER_MAX_VALUE
		timer_progress_bar_node.set_self_modulate(get_timeout_color())
		last_synced_time = game_params.QUESTION_TIMER_MAX_VALUE
	
	current_quiz_question.clear()

func highlight_answer(answer_node, style):
	answer_node.get_parent().get_parent().set("custom_styles/panel", style)

func clear_answer(idx):
	highlight_answer(answer_nodes[idx], answer_inner)
	answer_selection[idx] = false

func select_answer(idx):
	highlight_answer(answer_nodes[idx], answer_selected)
	answer_selection[idx] = true

func rebuild_confirm_button_text():
	confirm_button.text = ("[A] " if has_joypads() else "") + tr("GAME_CONFIRM")

func toggle_answer(idx):
	if answer_selection[idx]:
		clear_answer(idx)
		var has_selection = false
		for a in answer_selection:
			has_selection = has_selection or a
		if not has_selection:
			confirm_button.hide()
	else:
		select_answer(idx)
		var correct_answers_count = 0
		for a in correct_answers:
			if a:
				correct_answers_count = correct_answers_count + 1
		if correct_answers_count > 1:
			confirm_button.show()
			rebuild_confirm_button_text()
		else:
			# Make automatic confirm if there is only one correct answer
			_on_Confirm_pressed()

func _on_Answer1_gui_input(ev):
	if answer_accepted or answer_nodes[0].text.empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		toggle_answer(0)

func _on_Answer2_gui_input(ev):
	if answer_accepted or answer_nodes[1].text.empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		toggle_answer(1)

func _on_Answer3_gui_input(ev):
	if answer_accepted or answer_nodes[2].text.empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		toggle_answer(2)

func _on_Answer4_gui_input(ev):
	if answer_accepted or answer_nodes[3].text.empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		toggle_answer(3)

func log_current_answers():
	if current_quiz_idx <= 0:
		return
	
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return

	log_current_answer(db, player_id, answer_selection, correct_answer_reward)
	if has_opponent():
		log_current_answer(db, opponent_player_id, opponent_answer_selection, opponent_correct_answer_reward)
	
	# Close stats database
	db.close()

func is_answer_correct(answer_selection_array):
	var correct = true
	for ai in range(0, correct_answers.size()):
		correct = correct and (answer_selection_array[ai] == correct_answers[ai])
	return correct

func log_current_answer(db, player_id, answer_selection_array, reward):
	var correct = is_answer_correct(answer_selection_array)
	var quiz_id = quizzes[current_quiz_idx - 1].quiz_id
	db.query_with_args("INSERT INTO results (session_id, player_id, timestamp, quiz_id, answer_correct, reward) VALUES (?, ?, strftime('%s','now'), ?, ?, ?)", [session_id, player_id, quiz_id, 1 if correct else 0, reward])
	var result_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
	
	var ai = 0
	for answer_id in answer_ids:
		if answer_selection_array[ai]:
			db.query_with_args("INSERT INTO selections (result_id, answer_id) VALUES (?, ?)", [result_id, answer_id])
		ai = ai + 1

func inscribe_name(answer_node, is_opponent, clear):
	var label_parent = answer_node.get_parent()
	if is_opponent:
		label_parent.get_node("HBoxContainer/LabelOpponent").text = "" if clear else godotsteam.get_opponent_name()
	else:
		label_parent.get_node("HBoxContainer/LabelPlayer").text = "" if clear else godotsteam.get_player_name()

func check_and_highlight_answers(is_opponent, answer_selection_array, show_missed):
	var ai = 0
	var has_errors = false
	for answer_node in answer_nodes:
		if answer_selection_array[ai]:
			inscribe_name(answer_node, is_opponent, false)
		if correct_answers[ai] and answer_selection_array[ai]:
			highlight_answer(answer_node, answer_correct)
		elif answer_selection_array[ai] or correct_answers[ai]:
			#var style = answer_missed if correct_answers[ai] else answer_error # To highlight correct but missed answers with yellow
			var style = answer_correct if correct_answers[ai] else answer_error
			if show_missed or not correct_answers[ai]:
				highlight_answer(answer_node, style)
			has_errors = true
		ai = ai + 1
	return has_errors

func do_answer_result_animation():
	var ai = 0
	var modulate = $AnswerAnimationPlayer.get_animation("modulate")
	for answer_node in answer_nodes:
		modulate.track_set_enabled(ai, answer_selection[ai] or opponent_answer_selection[ai])
		ai = ai + 1
	$AnswerAnimationPlayer.play("modulate")

func rebuild_next_button_text():
	next_button.text = ("[Y] " if has_joypads() else "") + tr("GAME_NEXT")

func _on_Confirm_pressed():
	if answer_accepted:
		return
	
	if has_cpu_opponent() and not has_opponent_answer():
		var min_value = timer_progress_bar_node.value - game_params.CPU_OPPONENT_MAX_PLAYER_DIFF
		cpu_opponent_progress_threshold = int(rand_range(min_value if min_value > 0 else 0, timer_progress_bar_node.value))
	
	if has_human_opponent() and godotsteam.opponent:
		godotsteam.send_quizanswer(godotsteam.opponent.steam_ID, answer_selection, get_correct_answer_reward())
	
	var quiz_id = quizzes[current_quiz_idx - 1].quiz_id
	var language_code = quizzes[current_quiz_idx - 1].language_code
	assign_media(find_media(language_code, quiz_id, true))
	var has_errors = check_and_highlight_answers(false, answer_selection, true)
	if game_params.answer_result_animation:
		do_answer_result_animation()
	if has_errors:
		life_nodes[lifes_idx].set("custom_styles/panel", life_empty)
		lifes_idx = lifes_idx - 1
		player_wrong.play()
	else:
		score = score + correct_answer_reward
		score_label_node.text = str(score)
		player_correct.play()
	answer_accepted = true
	confirm_button.hide()
	if need_next_button:
		next_button.show()
		rebuild_next_button_text()
	
	answer_result_timeout = game_params.ANSWER_RESULT_TIMEOUT_MAX_VALUE
	allow_next = not need_next_button
	show_gamepad_hints(false)

func set_win():
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return
	
	db.query_with_args("UPDATE sessions SET is_win = 1 WHERE session_id = ?;", [game_params.last_session_id])
	
	# Close stats database
	db.close()

func set_opponent_win():
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open stats database
	if (!db.open("res://stats.db")):
		print("Cannot open stats database.")
		return
	
	db.query_with_args("UPDATE sessions SET is_opponent_win = 1 WHERE session_id = ?;", [game_params.last_session_id])
	
	# Close stats database
	db.close()

func win():
	set_process(false)
	log_current_answers()
	set_win()
	match game_params.target_quiz_count:
		game_params.QUIZ_COUNT_LOW:
			if has_human_opponent():
				godotsteam.set_achievement("EXPERT")
		game_params.QUIZ_COUNT_NORMAL:
			if has_cpu_opponent():
				godotsteam.set_achievement("INTELLECTUAL")
			elif not has_opponent():
				godotsteam.set_achievement("SCHOLAR")
		game_params.QUIZ_COUNT_HIGH:
			if has_human_opponent():
				godotsteam.set_achievement("ERUDITE")
			elif has_cpu_opponent():
				godotsteam.set_achievement("GAME_MASTER")
			else:
				godotsteam.set_achievement("WINNER")
	if game_params.category_ids_array.size() == 1:
		match game_params.category_ids_array[0]:
			1: # Astronomy
				godotsteam.set_achievement("ASTRONOMER")
			2: # Mathematics
				godotsteam.set_achievement("MATEMATICIAN")
			3: # Literature
				godotsteam.set_achievement("PHILOLOGIST")
			4: # Russian literature
				godotsteam.set_achievement("HUMANITARIAN")
			5: # Cuisine
				godotsteam.set_achievement("CHEF")
	if lifes_idx == game_params.TOTAL_LIVES - 1:
		godotsteam.set_achievement("GURU")
	godotsteam.store_stats()
	return get_tree().change_scene("res://scenes/screen_results.tscn")

func lose():
	set_process(false)
	log_current_answers()
	set_opponent_win()
	if has_human_opponent() and godotsteam.opponent:
		godotsteam.send_lost(godotsteam.opponent.steam_ID)
	return get_tree().change_scene("res://scenes/screen_results.tscn")

func _on_Next_pressed():
	allow_next = true
	answer_result_timeout = 0
	if godotsteam.opponent:
		godotsteam.send_allow_next(godotsteam.opponent.steam_ID)

func _on_ButtonQuit_pressed():
	lose()
