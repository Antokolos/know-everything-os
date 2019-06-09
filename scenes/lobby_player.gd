extends Label

func _on_data_updated(updated_lobby_ID, self_lobby_ID):
	if updated_lobby_ID == self_lobby_ID:
		self.text = godotsteam.get_lobby_data(self_lobby_ID, "name")