extends Control

var selected_cards = []  # Almacena las 16 cartas seleccionadas (8 duplicadas y mezcladas)
var revealed_cards = {}  # Almacena el estado de las cartas reveladas
var flipped_cards = []  # Almacena las dos cartas giradas actualmente
var random_set = -1  # Set aleatorio seleccionado
var attempts = 8  # Intentos iniciales
var matched_pairs = 0  # Contador de parejas correctas

func _ready() -> void:
	# Seleccionar un set aleatorio
	random_set = get_random_set()
	if random_set == -1:
		print("No hay sets disponibles.")
		return

	# Mostrar la imagen del set en PicBooster
	if $PicBooster:
		$PicBooster.texture = load("res://cards/%d/1.jpg" % random_set)

	# Mostrar el nombre del set en BoosterTemplate/set.text
	if $BoosterTemplate/set:
		$BoosterTemplate/set.text = "Set: %d" % random_set

	# Inicializar el contador de intentos
	if $Attempts:
		$Attempts.text = "Attempts: %d" % attempts

	# Seleccionar 8 cartas aleatorias del set
	var random_cards = get_random_cards_from_set(random_set, 8)

	# Duplicar y mezclar las cartas
	selected_cards = duplicate_and_shuffle_cards(random_cards)

	# Inicializar las cartas en los slots
	initialize_cards()

	if Global.info == false:
		$BoosterTemplate.visible = false

# Obtiene un set aleatorio disponible
func get_random_set() -> int:
	var available_sets = Global.available_sets.keys().filter(func(set_id): return Global.available_sets[set_id])
	if available_sets.size() == 0:
		return -1
	return available_sets[randi() % available_sets.size()]

# Obtiene un número específico de cartas aleatorias de un set
func get_random_cards_from_set(set_id: int, count: int) -> Array:
	var cards_in_set = Global.cards.values().filter(func(card): return card["set"] == set_id)
	cards_in_set.shuffle()
	return cards_in_set.slice(0, count)

# Duplica y mezcla las cartas seleccionadas
func duplicate_and_shuffle_cards(cards: Array) -> Array:
	var duplicated_cards = cards.duplicate()
	duplicated_cards.append_array(cards)  # Duplicar las cartas
	duplicated_cards.shuffle()  # Mezclar las cartas
	return duplicated_cards

# Inicializa las cartas en los slots
func initialize_cards() -> void:
	for i in range(selected_cards.size()):
		# Calcular el índice del slot global (1-16)
		var global_slot_index = i + 1

		# Determinar en qué VBoxContainer está y qué número de slot es dentro de ese container
		var container_index = int((global_slot_index - 1) / 4) + 1  # VBoxContainer1 a VBoxContainer4
		var slot_index = global_slot_index  # Slot1 a Slot16 (numeración continua)

		var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]

		if has_node(card_node_path):
			var card_node = get_node(card_node_path)
			initialize_card(card_node, i)
		else:
			print("No se encontró el nodo: %s" % card_node_path)

# Inicializa una carta en un slot específico
func initialize_card(card_node: Node, card_index: int) -> void:
	# Configurar la carta como reverso
	if card_node.has_node("Button"):
		var button = card_node.get_node("Button")
		button.connect("pressed", Callable(self, "_on_card_pressed").bind(card_index))  # Conectar el botón al evento
	if card_node.has_node("Panel/Picture"):
		var picture = card_node.get_node("Panel/Picture")
		picture.texture = load("res://gui/backcard.jpg")  # Mostrar la imagen de reverso
		picture.position.y = 0  # Asegurar que la posición Y sea 0
	if card_node.has_node("Panel/Info"):
		var info_panel = card_node.get_node("Panel/Info")
		info_panel.visible = false  # Ocultar la información
		if info_panel.has_node("Overlay"):
			info_panel.get_node("Overlay").visible = false  # Asegurarse de que el overlay esté oculto

# Evento al pulsar una carta
func _on_card_pressed(card_index: int) -> void:
	if revealed_cards.has(card_index) and revealed_cards[card_index]:
		return  # Si ya está revelada, no hacer nada

	if flipped_cards.size() >= 2:
		return  # No permitir girar más de dos cartas a la vez

	revealed_cards[card_index] = true  # Marcar la carta como revelada
	var card_data = selected_cards[card_index]

	# Calcular el índice del slot global (1-16)
	var global_slot_index = card_index + 1

	# Determinar en qué VBoxContainer está y qué número de slot es
	var container_index = int((global_slot_index - 1) / 4) + 1  # VBoxContainer1 a VBoxContainer4
	var slot_index = global_slot_index  # Slot1 a Slot16 (numeración continua)

	var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]

	if has_node(card_node_path):
		var card_node = get_node(card_node_path)
		flip_card(card_node, card_data)  # Usar la animación de flip
		reveal_card(card_node, card_data)  # Llamar explícitamente a reveal_card
		flipped_cards.append({"node": card_node, "data": card_data, "index": card_index})

	# Si hay dos cartas giradas, comprobar si son iguales
	if flipped_cards.size() == 2:
		check_flipped_cards()

# Revela una carta y muestra su información
func reveal_card(card_node: Node, card_data: Dictionary) -> void:
	if card_node.has_node("Panel/Picture"):
		var picture = card_node.get_node("Panel/Picture")
		picture.texture = load(card_data["image"])  # Mostrar la imagen de la carta
		picture.position.y = 0  # Asegurar que la posición Y sea 0
	if card_node.has_node("Panel/Info"):
		var info_panel = card_node.get_node("Panel/Info")
		if Global.info == true:
			info_panel.visible = true  # Mostrar la información
		if info_panel.has_node("name"):
			info_panel.get_node("name").text = card_data.get("name", "Unknown")
		if info_panel.has_node("number"):
			info_panel.get_node("number").text = str(card_data.get("id", 0))
		if info_panel.has_node("red"):
			info_panel.get_node("red").text = str(card_data.get("red", 0))
		if info_panel.has_node("blue"):
			info_panel.get_node("blue").text = str(card_data.get("blue", 0))
		if info_panel.has_node("yellow"):
			info_panel.get_node("yellow").text = str(card_data.get("yellow", 0))
		if info_panel.has_node("Overlay"):
			info_panel.get_node("Overlay").visible = false  # Asegurarse de que el overlay esté oculto
	print("Card name:", card_data.get("name", "Unknown"))

# Realiza la animación de flip para una carta
func flip_card(card_node: Node, card_data: Dictionary) -> void:
	var tween = create_tween()
	$Flipcard.play()
	# Primera mitad del flip (escala hacia 0 en X)
	tween.tween_property(card_node, "scale:x", 0.1, 0.075)

	# Cambiar la imagen en el medio del flip
	tween.tween_callback(func():
		if card_node.has_node("Panel/Picture"):
			var picture = card_node.get_node("Panel/Picture")
			picture.texture = load(card_data["image"])  # Mostrar la imagen de la carta
		if card_node.has_node("Panel/Info"):
			var info_panel = card_node.get_node("Panel/Info")
			if Global.info == true:
				info_panel.visible = false  # Mostrar la información
	)

	# Segunda mitad del flip (escala hacia 1 en X)
	tween.tween_property(card_node, "scale:x", 1.0, 0.075)

# Realiza la animación de flip para volver al reverso
func flip_to_reverse(card_node: Node) -> void:
	var tween = create_tween()

	# Primera mitad del flip (escala hacia 0 en X)
	tween.tween_property(card_node, "scale:x", 0.1, 0.075)

	# Cambiar a la imagen de reverso en el medio del flip
	tween.tween_callback(func():
		if card_node.has_node("Panel/Picture"):
			var picture = card_node.get_node("Panel/Picture")
			picture.texture = load("res://gui/backcard.jpg")  # Mostrar la imagen de reverso
		if card_node.has_node("Panel/Info"):
			var info_panel = card_node.get_node("Panel/Info")
			info_panel.visible = false  # Ocultar la información
	)

	# Segunda mitad del flip (escala hacia 1 en X)
	tween.tween_property(card_node, "scale:x", 1.0, 0.075)

# Comprueba si las dos cartas giradas son iguales
func check_flipped_cards() -> void:
	if flipped_cards[0]["data"]["id"] == flipped_cards[1]["data"]["id"]:
		# Son iguales, realizar animación de shake y luego ocultarlas
		await play_shake_animation(flipped_cards)
		for flipped_card in flipped_cards:
			var card_node = flipped_card["node"]
			hide_card(card_node)  # Ocultar la carta (sin eliminarla)
			revealed_cards.erase(flipped_card["index"])  # Eliminar del estado de cartas reveladas
		$Plop.play()
		matched_pairs += 1  # Incrementar el contador de parejas correctas

		# Verificar si todas las parejas están correctas
		if matched_pairs == 8:
			Global.money += 750  # Recompensa de dinero
			Global.save_data()
			if $Win:
				$Win.text = "Winner!\n¥750"  # Mostrar mensaje de victoria
				$Win.visible = true
				$Fullprize.play()
			hide_ui_elements()  # Ocultar elementos de la UI al ganar
			await get_tree().create_timer(2.0).timeout  # Esperar 2 segundos
			reset_scene()
	else:
		# No son iguales, volver a mostrar el reverso después de 2 segundos
		attempts -= 1  # Reducir intentos
		if $Attempts:
			$Attempts.text = "Attempts: %d" % attempts

		# Si los intentos llegan a 0, mostrar todas las cartas y reiniciar
		if attempts <= 0:
			if $Win:
				$Gameover.play()
				$Win.text = "Game\nOver"  # Mostrar mensaje de derrota
				$Win.visible = true
			await flip_all_remaining_cards()  # Realizar la animación de flip para todas las cartas
			await get_tree().create_timer(5.0).timeout  # Esperar 5 segundos
			reset_scene()
		else:
			await get_tree().create_timer(2.0).timeout
			for flipped_card in flipped_cards:
				var card_node = flipped_card["node"]
				flip_to_reverse(card_node)  # Usar la animación de flip para volver al reverso
				revealed_cards.erase(flipped_card["index"])  # Permitir volver a girar la carta

	flipped_cards.clear()  # Vaciar la lista de cartas giradas

# Oculta una carta al desaparecer (sin eliminarla)
func hide_card(card_node: Node) -> void:
	card_node.visible = false  # Ocultar la carta

# Muestra todas las cartas
func show_all_cards() -> void:
	for i in range(selected_cards.size()):
		# Calcular el índice del slot global (1-16)
		var global_slot_index = i + 1

		# Determinar en qué VBoxContainer está y qué número de slot es
		var container_index = int((global_slot_index - 1) / 4) + 1  # VBoxContainer1 a VBoxContainer4
		var slot_index = global_slot_index  # Slot1 a Slot16 (numeración continua)

		var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]
		if has_node(card_node_path):
			var card_node = get_node(card_node_path)
			var card_data = selected_cards[i]
			reveal_card(card_node, card_data)

# Realiza la animación de flip para todas las cartas restantes
func flip_all_remaining_cards() -> void:
	for i in range(selected_cards.size()):
		# Calcular el índice del slot global (1-16)
		var global_slot_index = i + 1

		# Determinar en qué VBoxContainer está y qué número de slot es
		var container_index = int((global_slot_index - 1) / 4) + 1  # VBoxContainer1 a VBoxContainer4
		var slot_index = global_slot_index  # Slot1 a Slot16 (numeración continua)

		var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]
		if has_node(card_node_path):
			var card_node = get_node(card_node_path)
			if card_node.visible:  # Solo realizar el flip si la carta está visible
				var card_data = selected_cards[i]
				flip_card(card_node, card_data)  # Realizar la animación de flip

# Reinicia la escena
func reset_scene() -> void:
	get_tree().reload_current_scene()

# Reproduce una animación de shake para las cartas correctas
func play_shake_animation(cards: Array) -> void:
	for i in range(20):  # Realizar 20 movimientos (doble de duración)
		await get_tree().create_timer(0.1).timeout  # Esperar 0.1 segundos entre movimientos
		for flipped_card in cards:
			var card_node = flipped_card["node"]
			if card_node:
				card_node.position.x += 50 if i % 2 == 0 else -50  # Mover de lado a lado
	for flipped_card in cards:
		var card_node = flipped_card["node"]
		if card_node:
			card_node.position.x = 0  # Volver a la posición original

# Maneja el evento del botón "Home"
func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Oculta elementos de la UI al finalizar el juego
func hide_ui_elements() -> void:
	if $PicBooster:
		$PicBooster.visible = false  # Ocultar PicBooster
	if $ButtonHome:
		$ButtonHome.visible = false  # Ocultar ButtonHome
	if $Attempts:
		$Attempts.visible = false  # Ocultar Attempts
	if $BoosterTemplate:
		$BoosterTemplate.visible = false  # Ocultar BoosterTemplate
