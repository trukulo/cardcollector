extends Control

var random_set = -1  # Set aleatorio seleccionado
var sequence = []  # Secuencia que el jugador tiene que repetir
var player_sequence = []  # Secuencia que el jugador está ingresando
var current_level = 1  # Nivel actual (número de cartas en la secuencia)
var max_level = 9  # Nivel máximo (máximo número de cartas en la secuencia)
var is_showing_sequence = false  # Indica si se está mostrando la secuencia
var is_player_turn = false  # Indica si es el turno del jugador
var available_cards = []  # Índice de las cartas disponibles (0-8)
var card_data = []  # Almacena los datos de las cartas
var can_click = false  # Controla si el jugador puede hacer clic en las cartas
var game_active := true

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

	# Actualizar el contador de nivel
	update_level_text()

	# Inicializar las cartas disponibles (ahora son 9 cartas)
	available_cards = range(9)  # 0-8
	
	# Seleccionar 9 cartas aleatorias del set
	card_data = get_random_cards_from_set(random_set, 9)

	# Inicializar las cartas en los slots
	initialize_cards()
	
	# Comenzar el juego después de una pequeña pausa
	await get_tree().create_timer(1.0).timeout
	start_next_level()

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

# Inicializa las cartas en los slots (ahora para 9 cartas)
func initialize_cards() -> void:
	for i in range(9):  # Ahora son 9 cartas
		# Determinar en qué VBoxContainer está y qué número de slot es dentro de ese container
		var container_index = int(i / 3) + 1  # VBoxContainer1 a VBoxContainer3
		var slot_index = i + 1  # Slot1 a Slot9
		
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

# Actualiza el texto del nivel actual
func update_level_text() -> void:
	if $Attempts:
		$Attempts.text = "Repeat %d card%s" % [current_level, "s" if current_level > 1 else ""]

# Comienza el siguiente nivel
func start_next_level() -> void:
	player_sequence.clear()
	is_player_turn = false
	can_click = false
	update_level_text()
	
	# Añadir una nueva carta a la secuencia
	if current_level > sequence.size():
		sequence.append(available_cards[randi() % available_cards.size()])
	
	# Mostrar la secuencia al jugador
	is_showing_sequence = true
	show_sequence()

# Muestra la secuencia al jugador
func show_sequence() -> void:
	# Deshabilitar los botones durante la demostración
	can_click = false
	
	# Mostrar cada carta en la secuencia con un pequeño retraso entre ellas
	for i in range(sequence.size()):
		await get_tree().create_timer(0.5).timeout  # Espera antes de mostrar la siguiente carta
		
		var card_index = sequence[i]
		# Determinar en qué VBoxContainer está y qué número de slot es
		var container_index = int(card_index / 3) + 1  # VBoxContainer1 a VBoxContainer3
		var slot_index = card_index + 1  # Slot1 a Slot9
		
		var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]
		if has_node(card_node_path):
			var card_node = get_node(card_node_path)
			flash_card(card_node, card_data[card_index])
	
	# Esperar un poco después de mostrar la secuencia completa
	await get_tree().create_timer(0.7).timeout
	
	# Ahora es el turno del jugador
	is_showing_sequence = false
	is_player_turn = true
	can_click = true

# Realiza la animación de flash para una carta (mostrar y ocultar)
func flash_card(card_node: Node, card_data: Dictionary) -> void:
	# Mostrar la carta
	flip_card(card_node, card_data)
	
	# Ocultar la carta después de un tiempo
	await get_tree().create_timer(0.5).timeout
	flip_to_reverse(card_node)

# Evento al pulsar una carta
func _on_card_pressed(card_index: int) -> void:
	if is_showing_sequence or not is_player_turn or not can_click:
		return  # No permitir interacción durante la demostración
	
	# Determinar en qué VBoxContainer está y qué número de slot es
	var container_index = int(card_index / 3) + 1  # VBoxContainer1 a VBoxContainer3
	var slot_index = card_index + 1  # Slot1 a Slot9
	
	var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]
	if has_node(card_node_path):
		var card_node = get_node(card_node_path)
		
		# Mostrar brevemente la carta
		flip_card(card_node, card_data[card_index])
		await get_tree().create_timer(0.3).timeout
		flip_to_reverse(card_node)
		
		# Añadir la carta a la secuencia del jugador
		player_sequence.append(card_index)
		
		# Comprobar si la secuencia es correcta hasta el momento
		if player_sequence.size() <= sequence.size():
			if player_sequence[player_sequence.size() - 1] != sequence[player_sequence.size() - 1]:
				# Secuencia incorrecta
				game_over()
				return
		
		# Comprobar si el jugador ha completado la secuencia actual
		if player_sequence.size() == sequence.size():
			# El jugador ha completado correctamente la secuencia
			await get_tree().create_timer(0.5).timeout
			check_level_completion()

# Comprueba si el jugador ha completado el nivel actual
func check_level_completion() -> void:
	# Comprobar si el jugador ha alcanzado el nivel máximo
	if current_level >= max_level:
		# Victoria total
		player_wins(true)
	else:
		# Avanzar al siguiente nivel
		current_level += 1
		start_next_level()

# Función para cuando el jugador gana
func player_wins(complete_game: bool, reward: int = 0) -> void:
	game_active = false
	if complete_game:
		reward = 900  # Victoria completa (9 niveles): 500 + (4 * 100) = 900
	
	Global.money += reward  # Añadir recompensa de dinero
	Global.save_data()
	
	if $Win:
		if complete_game:
			# Victoria completa (9 niveles)
			$Win.text = "PERFECT!\n¥" + str(reward)
		else:
			$Win.text = "WIN\n¥" + str(reward)
		$Win.visible = true
	
	if complete_game:
		hide_ui_elements()  # Ocultar elementos de la UI al ganar completamente
		await get_tree().create_timer(3.0).timeout  # Esperar 3 segundos
		reset_scene()

# Función para cuando el jugador pierde
func game_over() -> void:
	game_active = false
	can_click = false
	is_player_turn = false
	
	# Si el jugador ha completado al menos 5 niveles, recibe una recompensa
	if current_level >= 5:
		var reward = 100 + (current_level - 5) * 100
		Global.money += reward
		Global.save_data()
		if $Win:
			$Win.text = "WIN\n¥" + str(reward)
	else:
		if $Win:
			$Win.text = "Game\nOver"
	
	if $Win:
		$Win.visible = true
	
	# Mostrar la secuencia correcta
	await get_tree().create_timer(1.0).timeout
	show_correct_sequence()
	
	# Esperar antes de reiniciar
	await get_tree().create_timer(3.0).timeout
	reset_scene()

# Muestra la secuencia correcta completa
func show_correct_sequence() -> void:
	for i in range(sequence.size()):
		if not game_active:
			return
		await get_tree().create_timer(0.5).timeout
		
		var card_index = sequence[i]
		# Determinar en qué VBoxContainer está y qué número de slot es
		var container_index = int(card_index / 3) + 1
		var slot_index = card_index + 1
		
		var card_node_path = "HBoxContainer/VBoxContainer%d/Slot%d" % [container_index, slot_index]
		if has_node(card_node_path):
			var card_node = get_node(card_node_path)
			
			# Destacar la carta correcta
			if i < player_sequence.size():
				# El jugador acertó esta carta
				flip_card(card_node, card_data[card_index])
			else:
				# El jugador no llegó a esta carta o se equivocó
				var tween = create_tween()
				tween.tween_property(card_node, "modulate", Color(1, 0.5, 0.5), 0.2)  # Tinte rojizo
				flip_card(card_node, card_data[card_index])
				await get_tree().create_timer(0.5).timeout
				tween = create_tween()
				tween.tween_property(card_node, "modulate", Color(1, 1, 1), 0.2)  # Volver al color normal
			
			await get_tree().create_timer(0.3).timeout
			flip_to_reverse(card_node)

# Realiza la animación de flip para una carta
func flip_card(card_node: Node, card_data: Dictionary) -> void:
	if not game_active:
		return

	var tween = create_tween()

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
				info_panel.get_node("Overlay").visible = false
	)

	# Segunda mitad del flip (escala hacia 1 en X)
	tween.tween_property(card_node, "scale:x", 1.0, 0.075)

# Realiza la animación de flip para volver al reverso
func flip_to_reverse(card_node: Node) -> void:
	if not game_active:
		return

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

# Reinicia la escena
func reset_scene() -> void:
	get_tree().reload_current_scene()

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