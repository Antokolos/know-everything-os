extends TextureRect

const READY = "READY_VALUE"
const NOT_READY = "NOT_READY_VALUE"

onready var invite_button_node = get_node("VBoxContainer/HBoxActions/Invite")
onready var start_button_node = get_node("VBoxContainer/HBoxActions/Start")
onready var ready_button_node = get_node("VBoxContainer/HBoxActions/Ready")
onready var start_timer_node = get_node("StartTimer")
onready var opponent_info_node = get_node("VBoxContainer/HBoxOpponentInfo/OpponentInfoLabel")
onready var opponent_ready_node = get_node("VBoxContainer/HBoxOpponentInfo/OpponentReadyLabel")
onready var message_node = get_node("VBoxContainer/HBoxMessage/MessageLabel")
onready var back_node = get_node("VBoxContainer/HBoxActions/Back")

const TIMER_TICKS_MAX = 3
var timer_ticks_left = TIMER_TICKS_MAX

func _ready():
	game_params.opponent_type = game_params.OPPONENT_HUMAN
	game_params.init_styles(self)
	if godotsteam.connect_steam_signal("lobby_data_update", self, "_on_lobby_data_update") == OK:
		invite_button_node.visible = godotsteam.create_lobby_or_join()
		start_button_node.visible = invite_button_node.visible
	back_node.grab_focus()

func _process(delta):
	if not godotsteam.opponent or not godotsteam.opponent.in_lobby:
		start_button_node.disabled = true
		opponent_info_node.text = ""
		opponent_ready_node.text = tr("GAME_WAIT_NOT_READY_MESSAGE")
		message_node.text = tr("GAME_WAIT_WAITING")
		return
	if godotsteam.has_packet_with_code(godotsteam.CODE_HANDSHAKE):
		var opponent_ID = godotsteam.peek_packet_with_code(godotsteam.CODE_HANDSHAKE)
		print("Received handshake from %d!" % opponent_ID)
		if opponent_ID == godotsteam.opponent.steam_ID:
			_on_lobby_data_update(true, godotsteam.steam_lobby_ID, opponent_ID)
			opponent_info_node.text = godotsteam.opponent.name
			message_node.text = tr("GAME_WAIT_CONNECTED")
	elif godotsteam.has_packet_with_code(godotsteam.CODE_COUNTDOWN):
		ready_button_node.disabled = true # It's a final countdown... :)
		var counter = godotsteam.peek_packet_with_code(godotsteam.CODE_COUNTDOWN)
		message_node.text = tr("GAME_WAIT_STARTING") % counter
		if counter == 1:
			timer_ticks_left = 0 # Starting the game on last timeout
			start_timer_node.start()

func _on_lobby_data_update(success, steamIDLobby, steamIDMember):
	invite_button_node.disabled = godotsteam.is_lobby_full()
	if steamIDMember != steamIDLobby:
		var self_ready = godotsteam.get_lobby_member_data(steamIDLobby, godotsteam.steam_ID, "ready")
		var opponent_ready = null
		if godotsteam.opponent:
			opponent_ready = godotsteam.get_lobby_member_data(steamIDLobby, godotsteam.opponent.steam_ID, "ready")
			if opponent_ready == READY:
				opponent_ready_node.text = tr("GAME_WAIT_READY_MESSAGE")
			else:
				opponent_ready_node.text = tr("GAME_WAIT_NOT_READY_MESSAGE")
		start_button_node.disabled = opponent_ready != READY or self_ready != READY
	else:
		godotsteam.set_main_game_params(steamIDLobby) # Update main game params if needed

func _on_Back_pressed():
	start_timer_node.stop()
	godotsteam.leave_lobby()
	return get_tree().change_scene("res://main.tscn")

func _on_Ready_pressed():
	godotsteam.set_lobby_member_data(godotsteam.steam_lobby_ID, "ready", READY if ready_button_node.pressed else NOT_READY)

func _on_StartTimer_timeout():
	if timer_ticks_left > 0:
		message_node.text = tr("GAME_WAIT_STARTING") % timer_ticks_left
		godotsteam.send_countdown(godotsteam.opponent.steam_ID, timer_ticks_left)
		timer_ticks_left = timer_ticks_left - 1
		return false
	else:
		start_timer_node.stop()
		return get_tree().change_scene("res://scenes/game.tscn") == OK

func _on_Start_pressed():
	start_button_node.disabled = true
	ready_button_node.disabled = true
	start_timer_node.start()

func _on_Invite_pressed():
	godotsteam.activate_invite_dialog()

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()
