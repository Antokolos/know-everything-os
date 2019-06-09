extends Control

# SQLite module
const SQLite = preload("res://lib/gdsqlite.gdns")

onready var language = get_node("Panel/VBoxContainer/HBoxLanguage/Language")
onready var category = get_node("Panel/VBoxContainer/HBoxCategory/Category")

onready var answer_correct_states = [
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer1/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer2/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer3/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer4/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer5/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer6/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer7/CheckBoxAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer8/CheckBoxAnswer")
]

onready var answer_texts = [
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer1/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer2/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer3/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer4/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer5/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer6/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer7/EditAnswer"),
get_node("Panel/VBoxContainer/HBoxAnswers/GridContainer/HBoxContainer8/EditAnswer")
]

onready var quiz_info_label = get_node("Panel/VBoxContainer/QuizInfoLabel")
onready var quiz_text_edit = get_node("Panel/VBoxContainer/QuizTextEdit")
onready var back_node = get_node("Panel/VBoxContainer/HBoxControls/HBoxContainer/ButtonBack")

var language_id
var category_id
var quizzes = []
var current_quiz_idx = 0
var add_new = false

func _ready():
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	var result = null
	var i = 0
	
	result = db.fetch_array("SELECT * FROM languages ORDER BY language_id")
	for lang in result:
		language.add_item(lang.language_name_native, i)
		language.set_item_metadata(i, lang.language_id)
		i = i + 1
	language_id = language.get_item_metadata(0)
	
	i = 0
	result = db.fetch_array("SELECT * FROM categories ORDER BY category_id")
	for cat in result:
		category.add_item(cat.category_name_hint, i)
		category.set_item_metadata(i, cat.category_id)
		i = i + 1
	category_id = category.get_item_metadata(0)
	
	update_quizzes(db)
	update_fields(db)
	
	# Close database
	db.close()
	back_node.grab_focus()

func update_quizzes(db):
	add_new = false
	current_quiz_idx = 0
	quizzes = db.fetch_array_with_args("SELECT quiz_id, answer_group_id FROM quizzes WHERE category_id = ?", [category_id])

func update_fields(db):
	if not quizzes or quizzes.empty():
		quiz_info_label.text = "No quizzes found!"
		quiz_text_edit.text = ""
		for ci in range(0, 8):
			answer_correct_states[ci].pressed = false
			answer_texts[ci].text = ""
		return
	
	var quiz_id = quizzes[current_quiz_idx].quiz_id
	quiz_info_label.text = "Quiz Id = " + str(quiz_id) + "; Quiz " + str(current_quiz_idx + 1) + " of " + str(quizzes.size())
	var quiz_text_data = db.fetch_array_with_args("SELECT quiz_text FROM quiz_texts WHERE quiz_id = ? AND language_id = ?", [quiz_id, language_id])
	quiz_text_edit.text = "" if quiz_text_data.empty() else StringUtil.Decrypt(quiz_text_data[0].quiz_text)
	
	var answer_group_id = quizzes[current_quiz_idx].answer_group_id
	var answers = db.fetch_array_with_args("SELECT a.correct, at.answer_text FROM answers a, answer_texts at WHERE a.answer_group_id = ? AND at.language_id = ? AND a.answer_id = at.answer_id ORDER BY a.answer_id", [answer_group_id, language_id])
	var ai = 0
	for answer in answers:
		answer_correct_states[ai].pressed = answer.correct == 1
		answer_texts[ai].text = StringUtil.Decrypt(answer.answer_text)
		ai = ai + 1
	for ci in range(ai, 8):
		answer_correct_states[ci].pressed = false
		answer_texts[ci].text = ""

func _on_ButtonPrev_pressed():
	if current_quiz_idx > 0:
		add_new = false
		current_quiz_idx = current_quiz_idx - 1
		
		# Create gdsqlite instance
		var db = SQLite.new()
		
		# Open database
		if (!db.open("res://everything.db")):
			print("Cannot open database.")
			return
		
		update_fields(db)
		
		# Close database
		db.close()

func _on_ButtonNext_pressed():
	if current_quiz_idx < quizzes.size() - 1:
		add_new = false
		current_quiz_idx = current_quiz_idx + 1
		
		# Create gdsqlite instance
		var db = SQLite.new()
		
		# Open database
		if (!db.open("res://everything.db")):
			print("Cannot open database.")
			return
		
		update_fields(db)
		
		# Close database
		db.close()

func _on_ButtonSave_pressed():
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	if add_new:
		var cat = category.get_item_text(category.get_selected_id())
		var answer_group_hint = cat + " answer " + str(quizzes.size() + 1)
		
		db.query_with_args("INSERT INTO answer_groups (answer_group_hint) VALUES (?);", [answer_group_hint])
		var answer_group_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
		db.query_with_args("INSERT INTO quizzes (category_id, answer_group_id) VALUES (?, ?);", [category_id, answer_group_id])
		var quiz_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
		db.query_with_args("INSERT INTO quiz_texts (quiz_id, language_id, quiz_text) VALUES (?, ?, ?);", [quiz_id, language_id, StringUtil.Encrypt(quiz_text_edit.text)])
		for ai in range(0, 8):
			if answer_texts[ai].text.length() > 0:
				db.query_with_args("INSERT INTO answers (answer_group_id, correct) VALUES (?, ?);", [answer_group_id, 1 if answer_correct_states[ai].pressed else 0])
				var answer_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
				db.query_with_args("INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (?, ?, ?);", [answer_id, language_id, StringUtil.Encrypt(answer_texts[ai].text)])
		
		current_quiz_idx = quizzes.size()
		quizzes.push_back({"quiz_id" : quiz_id, "answer_group_id" : answer_group_id})
		quiz_info_label.text = "Quiz Id = " + str(quiz_id) + "; Quiz " + str(current_quiz_idx + 1) + " of " + str(quizzes.size())
	else:
		var quiz = quizzes[current_quiz_idx]
		var quiz_text_data = db.fetch_array_with_args("SELECT quiz_text_id FROM quiz_texts WHERE quiz_id = ? AND language_id = ?", [quiz.quiz_id, language_id])
		
		if quiz_text_data.size() > 0:
			db.query_with_args("UPDATE quiz_texts SET quiz_text = ? WHERE quiz_text_id = ?", [StringUtil.Encrypt(quiz_text_edit.text), quiz_text_data[0].quiz_text_id])
		else:
			db.query_with_args("INSERT INTO quiz_texts (quiz_id, language_id, quiz_text) VALUES (?, ?, ?);", [quiz.quiz_id, language_id, StringUtil.Encrypt(quiz_text_edit.text)])
		
		var answers = db.fetch_array_with_args("SELECT answer_id FROM answers WHERE answer_group_id = ? ORDER BY answer_id", [quiz.answer_group_id])
		var i = 0
		for ai in range(0, 8):
			if answer_texts[ai].text.length() > 0:
				var answer_id
				if i < answers.size():
					db.query_with_args("UPDATE answers SET correct = ? WHERE answer_id = ?", [1 if answer_correct_states[ai].pressed else 0, answers[i].answer_id])
					answer_id = answers[i].answer_id
				else:
					db.query_with_args("INSERT INTO answers (answer_group_id, correct) VALUES (?, ?);", [quiz.answer_group_id, 1 if answer_correct_states[ai].pressed else 0])
					answer_id = db.fetch_array("SELECT last_insert_rowid() as rowid;")[0].rowid
				
				var textdata = db.fetch_array_with_args("SELECT answer_text_id FROM answer_texts WHERE answer_id = ? AND language_id = ?", [answer_id, language_id])
				if textdata.size() > 0:
					db.query_with_args("UPDATE answer_texts SET answer_text = ? WHERE answer_text_id = ?", [StringUtil.Encrypt(answer_texts[ai].text), textdata[0].answer_text_id])
				else:
					db.query_with_args("INSERT INTO answer_texts (answer_id, language_id, answer_text) VALUES (?, ?, ?);", [answer_id, language_id, StringUtil.Encrypt(answer_texts[ai].text)])
				
				i = i + 1
			else:
				if i < answers.size():
					# If answer text for the current language was nonexistent at the start of editing, do nothing
					var existent = db.fetch_array_with_args("SELECT answer_text_id FROM answer_texts WHERE answer_id = ? AND language_id = ?", [answers[i].answer_id, language_id])
					if existent.size() > 0:
						db.query_with_args("DELETE from answer_texts WHERE answer_id = ?", [answers[i].answer_id])
						db.query_with_args("DELETE from answers WHERE answer_id = ?", [answers[i].answer_id])
						i = i + 1
	
	# Close database
	db.close()
	add_new = false

func _on_ButtonAdd_pressed():
	add_new = true
	quiz_text_edit.text = ""
	for ai in range(0, 8):
		answer_correct_states[ai].pressed = false
		answer_texts[ai].text = ""
	quiz_info_label.text = "Please enter quiz data and press 'Save'" 

func _on_Language_item_selected(ID):
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	language_id = language.get_item_metadata(ID)
	update_fields(db)
	
	# Close database
	db.close()

func _on_Category_item_selected(ID):
	# Create gdsqlite instance
	var db = SQLite.new()
	
	# Open database
	if (!db.open("res://everything.db")):
		print("Cannot open database.")
		return
	
	category_id = category.get_item_metadata(ID)
	update_quizzes(db)
	update_fields(db)
	
	# Close database
	db.close()

func _on_Button_pressed():
	return get_tree().change_scene("res://main.tscn")
