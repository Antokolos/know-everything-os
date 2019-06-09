extends Button

func _on_data_updated(updated_lobby_ID, join_scene, self_lobby_ID):
	if updated_lobby_ID == self_lobby_ID:
		self.visible = true
		if self.is_connected("pressed", join_scene, "_on_lobby_connect_pressed"):
			self.disconnect("pressed", join_scene, "_on_lobby_connect_pressed")
		if self.connect("pressed", join_scene, "_on_lobby_connect_pressed", [self_lobby_ID]) != OK:
			print("Error connecting _on_lobby_connect_pressed for " + str(self_lobby_ID))
