extends Node

signal leaderboard_fetched(leaderboard)
signal leaderboard_rank_retrieved(global_rank, score)
signal lobby_list_fetched(filtered_lobbies_list)

onready var Steam = load("res://lib/godotsteam.gdns").new()

const APP_STEAM_ID = 1040310
const EP2P_SEND_UNRELIABLE = 0
const EP2P_SEND_UNRELIABLE_NO_DELAY = 1
const EP2P_SEND_RELIABLE = 2
#const EP2P_SEND_RELIABLE_WITH_BUFFERING = 3
const MAX_LOBBY_MEMBERS = 2
const TYPE_GLOBAL = 0
const TYPE_GLOBAL_AROUND_USER = 1
const ENTRIES_COUNT_AROUND = 4
const LEADERBOARD_SINGLEPLAYER = "Top Erudites (Singleplayer)"
const LEADERBOARD_MULTIPLAYER = "Top Erudites (Multiplayer)"

const CODE_HANDSHAKE = 42
const CODE_COUNTDOWN = 100
const CODE_QUIZDATA = 110
const CODE_QUIZDATA_ACCEPTED = 115
const CODE_QUIZQUESTION = 120
const CODE_QUIZQUESTION_ACCEPTED = 125
const CODE_QUIZANSWER = 130
const CODE_ALLOW_NEXT = 140
const CODE_LOST = 150
const CODE_TIMESYNC = 160
# Please note that CODE_* constansts should not exceed 256

# Public vars
var user_name = null
var current_reward = 0

# Private vars
var steam_ID = 0
var steam_lobby_ID = 0
var opponent = null
var p2p_packets = {}
var need_score_update = false

func _ready():
	if Steam.restartAppIfNecessary(APP_STEAM_ID):
		return
	if not Steam.steamInit():
		return
	user_name = Steam.getPersonaName()
	steam_ID = Steam.getSteamID()
	Steam.connect("leaderboard_loaded", self, "_on_leaderboard_loaded")
	Steam.connect("leaderboard_entries_loaded", self, "_on_leaderboard_entries_loaded")
	Steam.connect("leaderboard_uploaded", self, "_on_leaderboard_uploaded")
	Steam.connect("lobby_created", self, "_on_lobby_created")
	Steam.connect("lobby_match_list", self, "_on_lobby_match_list")
	Steam.connect("lobby_joined", self, "_on_lobby_joined")
	Steam.connect("game_lobby_join_requested", self, "_on_game_lobby_join_requested")
	Steam.connect("p2p_session_request", self, "_on_p2p_session_request")
	Steam.connect("p2p_session_connect_fail", self, "_on_p2p_session_connect_fail")
	var args = OS.get_cmdline_args()
	var has_lobby_invite = false
	for arg in args:
		if has_lobby_invite:
			connect_to_lobby(int(arg))
			return
		if arg == "+connect_lobby":
			has_lobby_invite = true

func _process(delta):
	if is_steam_running():
		Steam.run_callbacks()
	var packet_size = godotsteam.get_available_P2P_packet_size()
	if packet_size > 0:
		var packet = godotsteam.read_P2P_packet(packet_size)
		if packet.empty():
			print("WARN: empty packet with nonzero packet_size???")
			return
		var key_id = str(packet.steamIDRemote)
		var key_code = str(packet.data[0])
		if not p2p_packets.has(key_id):
			p2p_packets[key_id] = {}
		if not p2p_packets.get(key_id).has(key_code):
			p2p_packets[key_id][key_code] = []
		if packet_size > 1:
			p2p_packets[key_id][key_code].push_back(bytes2var(packet.data.subarray(1, packet_size - 1)))
		else:
			p2p_packets[key_id][key_code].push_back(true) # for packets consisting from code only

func has_packet_with_code(packet_code):
	for pack_dic in p2p_packets.values():
		var key = str(packet_code)
		return pack_dic.has(key) and pack_dic.get(key).size() > 0

func peek_packet_with_code(packet_code):
	if not has_packet_with_code(packet_code):
		return false
	for pack_dic in p2p_packets.values():
		var key = str(packet_code)
		return pack_dic.get(key).pop_front()

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		leave_lobby()
		disconnect_from_opponent()
		get_tree().quit()

func _on_leaderboard_loaded(leaderboard_handle, found):
	Steam.downloadLeaderboardEntries(-ENTRIES_COUNT_AROUND, ENTRIES_COUNT_AROUND, TYPE_GLOBAL_AROUND_USER)
	# async, will emit 'leaderboard_entries_loaded' signal when done

func _on_leaderboard_entries_loaded():
	var entries = Steam.getLeaderboardEntries()
	var leaderboard = []
	var not_in_leaderboard = true
	var current_score = 0
	for entry in entries:
		var leader_entry = {}
		leader_entry["global_rank"] = entry.global_rank
		leader_entry["name"] = Steam.getFriendPersonaName(entry.steamID)
		leader_entry["score"] = entry.score
		leaderboard.append(leader_entry)
		if entry.steamID == steam_ID:
			not_in_leaderboard = false
			emit_signal("leaderboard_rank_retrieved", entry.global_rank, entry.score)
			current_score = entry.score
	
	if current_reward > 0:
		current_score = current_score + current_reward
		current_reward = 0
		Steam.uploadLeaderboardScore(current_score, false)
	
	var notify = not leaderboard.empty()
	if leaderboard.empty():
		# Can be empty at this stage if user is not in the leaderboard yet
		# In this case, let's just fetch top users from the table
		var entry_count = Steam.getLeaderboardEntryCount()
		# Do this only if leaderboard has at least one entry
		if entry_count > 0:
			Steam.downloadLeaderboardEntries(1, 2 * ENTRIES_COUNT_AROUND + 1, TYPE_GLOBAL)
		else:
			notify = true
	if notify:
		emit_signal("leaderboard_fetched", leaderboard)
		if not_in_leaderboard:
			emit_signal("leaderboard_rank_retrieved", 0, 0)

func _on_leaderboard_uploaded(failure, score, score_changed, global_rank_new, global_rank_previous):
	print("Score was uploaded, result = " + str(failure))

func _on_lobby_created(connect, lobby_ID):
	if connect == 0:
		steam_lobby_ID = lobby_ID
		print("Created lobby " + str(steam_lobby_ID))
		Steam.setLobbyData(steam_lobby_ID, "name", user_name)
		var lobby_info = game_params.get_lobby_info()
		Steam.setLobbyData(steam_lobby_ID, "target_quiz_count", lobby_info.target_quiz_count)
		Steam.setLobbyData(steam_lobby_ID, "category_names", lobby_info.category_names)
		Steam.setLobbyData(steam_lobby_ID, "category_ids", lobby_info.category_ids)

func _on_lobby_match_list():
		var lobbies_list = Steam.getLobbiesList()
		var filtered_lobbies_list = []
		for lobby in lobbies_list:
			if get_num_lobby_members(lobby["steamIDLobby"]) < MAX_LOBBY_MEMBERS:
				filtered_lobbies_list.append(lobby)
		emit_signal("lobby_list_fetched", filtered_lobbies_list)

func _on_lobby_joined(lobbyID, permissions, locked, response, connection_failure):
	if connection_failure:
		print("Error joining lobby " + lobbyID)
	else:
		self.steam_lobby_ID = lobbyID
		print("Joined lobby " + str(steam_lobby_ID))
		opponent = find_opponent_in_lobby(lobbyID)
		do_handshake(opponent.steam_ID)

func _on_game_lobby_join_requested(steamIDLobby, steamIDFriend):
	connect_to_lobby(steamIDLobby)

func _on_p2p_session_request(steamIDRemote):
	print("p2p_session_request from user " + str(steamIDRemote))
	var opp = find_opponent_from_ID(steamIDRemote)
	if opp.in_lobby:
		opponent = opp
		var key_id = str(steamIDRemote)
		if p2p_packets.has(key_id):
			# Discard any previous packets from this user
			p2p_packets[key_id] = {}
		Steam.acceptP2PSessionWithUser(steamIDRemote)
		do_handshake(steamIDRemote)

func do_handshake(steamIDRemote):
	var vData = PoolByteArray()
	vData.append(CODE_HANDSHAKE)
	vData.append_array(var2bytes(steam_ID))
	print("Sending handshake to " + str(steamIDRemote))
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_countdown(steamIDRemote, counter):
	var vData = PoolByteArray()
	vData.append(CODE_COUNTDOWN)
	vData.append_array(var2bytes(counter))
	print("Sending countdown to %d: %d" % [steamIDRemote, counter])
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_quizdata(steamIDRemote, quizzes):
	var vData = PoolByteArray()
	vData.append(CODE_QUIZDATA)
	vData.append_array(var2bytes(quizzes))
	print("Sending quizzes array to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_quizdata_accepted(steamIDRemote):
	var vData = PoolByteArray()
	vData.append(CODE_QUIZDATA_ACCEPTED)
	print("Sending quizzes array accept back to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_quizquestion(steamIDRemote, quiz_question):
	var vData = PoolByteArray()
	vData.append(CODE_QUIZQUESTION)
	vData.append_array(var2bytes(quiz_question))
	print("Sending quiz question to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_quizquestion_accepted(steamIDRemote):
	var vData = PoolByteArray()
	vData.append(CODE_QUIZQUESTION_ACCEPTED)
	print("Sending quiz question accept back to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_quizanswer(steamIDRemote, answer_selection, correct_answer_reward):
	var vData = PoolByteArray()
	vData.append(CODE_QUIZANSWER)
	vData.append_array(var2bytes({ "answer_selection" : answer_selection, "correct_answer_reward" : correct_answer_reward }))
	print("Sending quiz answer to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_allow_next(steamIDRemote):
	var vData = PoolByteArray()
	vData.append(CODE_ALLOW_NEXT)
	print("Sending allow next to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_lost(steamIDRemote):
	var vData = PoolByteArray()
	vData.append(CODE_LOST)
	print("Sending lost to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func send_timesync(steamIDRemote, timer):
	var vData = PoolByteArray()
	vData.append(CODE_TIMESYNC)
	vData.append_array(var2bytes(timer))
	print("Sending time sync to %d" % steamIDRemote)
	send_P2P_packet(steamIDRemote, vData, EP2P_SEND_RELIABLE)

func _on_p2p_session_connect_fail(steamIDRemote, p2p_session_error):
	print("p2p_session_connect_fail with user " + str(steamIDRemote) + ": " + str(p2p_session_error))
	# Simulate CODE_LOST from this user
	if not has_packet_with_code(CODE_LOST):
		var key_id = str(steamIDRemote)
		var key_code = str(CODE_LOST)
		if not p2p_packets.has(key_id):
			p2p_packets[key_id] = {}
		if not p2p_packets.get(key_id).has(key_code):
			p2p_packets[key_id][key_code] = []
		p2p_packets[key_id][key_code].push_back(true)

func is_steam_running():
	return Steam.isSteamRunning()

# Achievement stuff
func set_achievement(achievement_name):
	return Steam.setAchievement(achievement_name)

func store_stats():
	return Steam.storeStats()

# Leaderboards stuff
func fetch_leaderboard(leaderboard_name):
	Steam.findLeaderboard(leaderboard_name)

func append_leaderboard_score(leaderboard_name, score):
	current_reward = score
	Steam.findLeaderboard(leaderboard_name)

# Lobby stuff
func activate_invite_dialog():
	Steam.activateGameOverlayInviteDialog(steam_lobby_ID)

func is_lobby_full():
	return Steam.getNumLobbyMembers(steam_lobby_ID) > 1

func set_lobby_ID(lobby_ID):
	steam_lobby_ID = lobby_ID

func connect_steam_signal(signal_name, scene, handler_name):
	return Steam.connect(signal_name, scene, handler_name)

func create_lobby_or_join():
	if steam_lobby_ID == 0:
		Steam.createLobby(game_params.lobby_type, MAX_LOBBY_MEMBERS)
		# async, will emit 'lobby_created' signal when done
		return true
	else:
		Steam.joinLobby(steam_lobby_ID)
		# async, will emit 'lobby_joined' signal when done
		return false

func leave_lobby():
	if steam_lobby_ID != 0:
		print("Left lobby " + str(steam_lobby_ID))
		Steam.leaveLobby(steam_lobby_ID)
		steam_lobby_ID = 0

func disconnect_from_opponent():
	if opponent:
		Steam.closeP2PSessionWithUser(opponent.steam_ID)
		var key = str(opponent.steam_ID)
		if p2p_packets.has(key):
			p2p_packets.get(key).clear()
		opponent = null

func request_lobby_list():
	Steam.addRequestLobbyListDistanceFilter(game_params.LOBBY_DISTANCE_FILTER_FAR)
	Steam.requestLobbyList()
	# async, will emit 'lobby_match_list' signal when done

func request_lobby_data(steamIDLobby):
	return Steam.requestLobbyData(steamIDLobby)
	# async, will emit 'lobby_data_update' signal when done

func request_friends_lobby_list():
	var lobbies_list = Steam.getFriendGameLobbies()
	var filtered_lobbies_list = []
	for lobby in lobbies_list:
		if lobby["id"] == APP_STEAM_ID and get_num_lobby_members(lobby["lobby"]) < MAX_LOBBY_MEMBERS:
			var l = { "steamIDLobby" : lobby["lobby"] }
			filtered_lobbies_list.append(l)
	emit_signal("lobby_list_fetched", filtered_lobbies_list)

func get_num_lobby_members(lobby_ID):
	return Steam.getNumLobbyMembers(lobby_ID)

# This method will work properly only after joining this lobby
func get_lobby_members_data(lobby_ID):
	var result = []
	var lobby_data = Steam.getLobbyMembersData(lobby_ID)
	for lobby_item in lobby_data:
		var steamIDLobbyMember = lobby_item["steamIDLobbyMember"]
		var player_name = Steam.getFriendPersonaName(steamIDLobbyMember)
		var item = {}
		item["steam_ID"] = steamIDLobbyMember
		item["player_name"] = player_name
		item["is_self"] = (steamIDLobbyMember == steam_ID)
		item["owner"] = lobby_item["owner"]
		result.append(item)
	return result

func find_opponent_in_lobby(lobby_ID):
	var members_data = get_lobby_members_data(lobby_ID)
	for data in members_data:
		if not data.is_self and data.steam_ID > 0:
			return {
				"name" : data.player_name,
				"steam_ID" : data.steam_ID,
				"in_lobby" : true,
				"owner" : data.owner
			}
	return null

func find_opponent_from_ID(opponent_steam_ID):
	var opp = find_opponent_in_lobby(steam_lobby_ID)
	if opp and opp.steam_ID == opponent_steam_ID:
		return opp
	return {
		"name" : Steam.getFriendPersonaName(opponent_steam_ID),
		"steam_ID" : opponent_steam_ID,
		"in_lobby" : false,
		"owner" : false
	}

func get_lobby_data(lobbyID, key):
	return Steam.getLobbyData(lobbyID, key)

func get_lobby_member_data(lobbyID, userID, key):
	return Steam.getLobbyMemberData(lobbyID, userID, key)

func set_lobby_member_data(lobbyID, key, value):
	Steam.setLobbyMemberData(lobbyID, key, value)

# P2P stuff
func get_available_P2P_packet_size(channel = 0):
	return Steam.getAvailableP2PPacketSize(channel)

func read_P2P_packet(size, channel = 0):
	return Steam.readP2PPacket(size, channel)

func send_P2P_packet(steamIDRemote, vData, send_type, channel = 0):
	return Steam.sendP2PPacket(steamIDRemote, vData, send_type, channel)

# Overlay and webpages stuff
func open_url(url):
	Steam.activateGameOverlayToWebPage(url)
#	OS.shell_open(url)

func open_store_page(appid):
	Steam.activateGameOverlayToStore(appid)

# Game logic stuff
func get_player_name():
	return godotsteam.user_name if godotsteam.user_name else tr("DEFAULT_PLAYER_NAME")

func get_opponent_name():
	if game_params.opponent_type == game_params.OPPONENT_CPU:
		return tr("PARAMS_OPPONENT_CPU")
	if opponent:
		return opponent.name
	return ""

func set_main_game_params(lobby_ID):
	game_params.target_quiz_count = int(godotsteam.get_lobby_data(lobby_ID, "target_quiz_count"))
	game_params.category_ids_array = game_params.parse_category_ids_from_string(godotsteam.get_lobby_data(lobby_ID, "category_ids"))

func connect_to_lobby(lobby_ID):
	godotsteam.set_lobby_ID(lobby_ID)
	set_main_game_params(lobby_ID)
	return get_tree().change_scene("res://scenes/game_wait.tscn")
