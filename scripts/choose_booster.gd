extends Control

func _ready():
	# Cargar el set seleccionado al iniciar
	Global.load_data()  # Asegurarnos de que los datos estén actualizados
	update_open_booster_button()
	update_collection_labels()
	if Global.info == false:
		$BoosterTemplate.visible = false

func update_collection_labels():
	# Update set collection status
	if has_node("Collection"):
		var total_cards_in_set = 0
		var owned_cards_in_set = 0

		for card in Global.cards.values():
			if card["set"] == Global.selected_set:
				total_cards_in_set += 1
				var id_set = card["id_set"]
				if Global.get_amount(id_set) > 0:
					owned_cards_in_set += 1

func _on_button_right_pressed() -> void:
	# Incrementar el set seleccionado
	Global.selected_set += 1
	if Global.selected_set > Global.set_editions.size():
		Global.selected_set = 1  # Volver al primer set si se supera el límite
	Global.save_data()  # Guardar el set seleccionado junto con los demás datos
	update_open_booster_button()
	update_collection_labels()

func _on_button_left_pressed() -> void:
	# Decrementar el set seleccionado
	Global.selected_set -= 1
	if Global.selected_set < 1:
		Global.selected_set = Global.set_editions.size()  # Ir al último set si se baja del límite
	Global.save_data()  # Guardar el set seleccionado junto con los demás datos
	update_open_booster_button()
	update_collection_labels()

func update_open_booster_button():
	# Actualizar la textura del botón con la imagen del set seleccionado
	var set_folder = "res://cards/" + str(Global.selected_set)
	var image_path = set_folder + "/0.jpg"
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		# Set all button states to use the same texture
		$ButtonOpenBooster.texture_normal = texture
		$ButtonOpenBooster.texture_hover = texture
		$ButtonOpenBooster.texture_pressed = texture
		$ButtonOpenBooster.texture_disabled = texture  # Added disabled state
		$ButtonOpenBooster.texture_focused = texture   # Added focused state

		# Update the set number in BoosterTemplate/set
		if has_node("BoosterTemplate/set"):
			$BoosterTemplate/set.text = "Set " + str(Global.selected_set)
	else:
		print("Error: No se encontró la imagen para el set " + str(Global.selected_set))

func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_open_booster_pressed() -> void:
	# Cambiar a la escena de abrir sobre
	if Global.money >= 500:
		Global.money -= 500  # Restar el costo del sobre
		Global.save_data()  # Guardar el dinero restante
		get_tree().change_scene_to_file("res://scenes/openbooster.tscn")
	else:
		print("No tienes suficiente dinero para abrir un sobre.")
		# Aquí podrías mostrar un mensaje al usuario si lo deseas
		$NotMoney.visible = true
		await get_tree().create_timer(1.0).timeout
		$NotMoney.visible = false
