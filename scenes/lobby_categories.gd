extends Label

func _on_data_updated(updated_lobby_ID, db, all_cats_size, self_lobby_ID):
	if updated_lobby_ID == self_lobby_ID:
		var quiz_count = tr("GAME_JOIN_QUESTIONS_COUNT") % godotsteam.get_lobby_data(self_lobby_ID, "target_quiz_count")
		var cat_ids = game_params.parse_category_ids_from_string(godotsteam.get_lobby_data(self_lobby_ID, "category_ids"))
		if all_cats_size == cat_ids.size():
			self.text = tr("PARAMS_CATEGORIES_ALL") + quiz_count
		else:
			# Category names in the originating user's language can be obtained via godotsteam.get_lobby_data(self_lobby_ID, "category_names")
			self.text = game_params.get_cat_names(db, cat_ids) + quiz_count