extends TextureRect

onready var rank_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/HBoxGridHeader/GridContainer/Rank")
onready var player_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/HBoxGridHeader/GridContainer/Player")
onready var score_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/HBoxGridHeader/GridContainer/Score")
onready var statsgrid_single_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/HBoxGrid/ScrollContainer/StatsGrid")
onready var statsgrid_multi_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxMultiplayer/HBoxGrid/ScrollContainer/StatsGrid")
onready var message_wait_container_node = get_node("VBoxContainer/HBoxContainer")
onready var leaderboard_single_url_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/LeaderboardSingleUrl")
onready var leaderboard_multi_url_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxMultiplayer/LeaderboardMultiUrl")
onready var header_single_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxSingleplayer/HeaderLabel")
onready var header_multi_node = get_node("VBoxContainer/HBoxLeaderboards/VBoxMultiplayer/HeaderLabel")
onready var back_node = get_node("VBoxContainer/HBoxControls/Back")

func _ready():
	game_params.init_styles(self)
	if godotsteam.connect("leaderboard_fetched", self, "rebuild_single") == OK:
		godotsteam.fetch_leaderboard(godotsteam.LEADERBOARD_SINGLEPLAYER)
	header_single_node.text = godotsteam.LEADERBOARD_SINGLEPLAYER
	leaderboard_single_url_node.push_align(HALIGN_CENTER)
	leaderboard_single_url_node.push_meta(0)
	leaderboard_single_url_node.append_bbcode(tr("LEADERBOARDS_OPEN_FULL_LEADERBOARD"))
	leaderboard_single_url_node.pop()
	leaderboard_single_url_node.pop()
	header_multi_node.text = godotsteam.LEADERBOARD_MULTIPLAYER
	leaderboard_multi_url_node.push_align(HALIGN_CENTER)
	leaderboard_multi_url_node.push_meta(0)
	leaderboard_multi_url_node.append_bbcode(tr("LEADERBOARDS_OPEN_FULL_LEADERBOARD"))
	leaderboard_multi_url_node.pop()
	leaderboard_multi_url_node.pop()
	back_node.grab_focus()

func rebuild_single(leaderboard):
	godotsteam.disconnect("leaderboard_fetched", self, "rebuild_single")
	rebuild(leaderboard, leaderboard_single_url_node, statsgrid_single_node)
	if godotsteam.connect("leaderboard_fetched", self, "rebuild_multi") == OK:
		godotsteam.fetch_leaderboard(godotsteam.LEADERBOARD_MULTIPLAYER)

func rebuild_multi(leaderboard):
	godotsteam.disconnect("leaderboard_fetched", self, "rebuild_multi")
	rebuild(leaderboard, leaderboard_multi_url_node, statsgrid_multi_node)

func rebuild(leaderboard, leaderboard_url_node, statsgrid_node):
	message_wait_container_node.visible = false
	leaderboard_url_node.visible = true
	for entry in leaderboard:
		var labelRank = rank_node.duplicate(0)
		labelRank.text = str(entry.global_rank)
		var labelPlayer = player_node.duplicate(0)
		labelPlayer.text = str(entry.name)
		var labelScore = score_node.duplicate(0)
		labelScore.text = str(entry.score)
		statsgrid_node.add_child(labelRank)
		statsgrid_node.add_child(labelPlayer)
		statsgrid_node.add_child(labelScore)

func _on_Back_pressed():
	return get_tree().change_scene("res://main.tscn")

func _on_LeaderboardSingleUrl_meta_clicked(meta):
	godotsteam.open_url("https://steamcommunity.com/stats/1040310/leaderboards/3365810")

func _on_LeaderboardMultiUrl_meta_clicked(meta):
	godotsteam.open_url("https://steamcommunity.com/stats/1040310/leaderboards/3365812")

func _input(event):
	if game_params.is_event_cancel_action(event):
		_on_Back_pressed()