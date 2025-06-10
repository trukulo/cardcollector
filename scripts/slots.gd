extends Control

var random_set = -1  # Set aleatorio seleccionado
var card_data = []  # Almacena los datos de las cartas
var available_cards = []  # Índice de las cartas disponibles
var spinning = false  # Indica si los rodillos están girando
var reels = []  # Almacena los resultados de los rodillos
var money_won = 0  # Dinero ganado en la ronda actual
var spin_cost = 50  # Costo por tirada
var game_active := true
var card_counts = {}  # Declaramos card_counts como variable de clase

# Referencias a los nodos de los rodillos
@onready var reel1 = $ReelsContainer/Reel1
@onready var reel2 = $ReelsContainer/Reel2
@onready var reel3 = $ReelsContainer/Reel3

# Verifica que los nodos onready estén correctamente inicializados
func _ready() -> void:
	# Verificar que los nodos de rodillos existen
	if !is_instance_valid(reel1) or !is_instance_valid(reel2) or !is_instance_valid(reel3):
		print(tr("Error: One or more reel nodes are not properly initialized"))
		# Intentar encontrar los nodos manualmente si es posible
		if !is_instance_valid(reel1) and has_node("ReelsContainer/Reel1"):
			reel1 = get_node("ReelsContainer/Reel1")
			reel1.Card.Info.visible = false
		if !is_instance_valid(reel2) and has_node("ReelsContainer/Reel2"):
			reel2 = get_node("ReelsContainer/Reel2")
			reel2.Card.Info.visible = false
		if !is_instance_valid(reel3) and has_node("ReelsContainer/Reel3"):
			reel3 = get_node("ReelsContainer/Reel3")
			reel3.Card.Info.visible = false

	# Seleccionar un set aleatorio
	random_set = get_random_set()
	if random_set == -1:
		print(tr("No hay sets disponibles."))
		return

	# Mostrar la imagen del set en el header
	if has_node("SetImage"):
		$SetImage.texture = load("res://cards/%d/1.jpg" % random_set)

	# After selecting the set (random_set)
	if has_node("BoosterTemplate/set"):
		get_node("BoosterTemplate/set").text = "Set: %d" % random_set

	# Actualizar el contador de dinero
	update_money_display()

	# Inicializar las cartas disponibles
	available_cards = range(50)  # 0-49

	# Seleccionar cartas aleatorias del set
	card_data = get_random_cards_from_set(random_set, 50)

	# Inicializar los rodillos
	initialize_reels()

	# El botón de girar ya está conectado en el editor, no necesitamos conectarlo aquí
	# La función conectada en el editor probablemente es "_on_spin_button_pressed"
	# Verificamos que el botón existe
	if has_node("SpinButton"):
		print(tr("SpinButton found in scene"))
	else:
		print(tr("Error: SpinButton node not found"))

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

# Inicializa los rodillos del slot machine
func initialize_reels() -> void:
	# Configurar cada rodillo con una carta aleatoria
	reels = [
		randi() % available_cards.size(),
		randi() % available_cards.size(),
		randi() % available_cards.size()
	]

	# Mostrar las cartas iniciales
	update_reel_display()

# Actualiza la visualización de los rodillos
func update_reel_display() -> void:
	var reel_nodes = [reel1, reel2, reel3]

	for i in range(3):

		var card_index = reels[i]
		var reel_node = reel_nodes[i]

		# Verificar que el nodo no sea nulo
		if reel_node == null:
			print(tr("Error: reel_node %d is null") % i)
			continue

		# Verificar que el índice es válido
		if card_index >= card_data.size() or card_index < 0:
			print(tr("Error: Invalid card_index %d") % card_index)
			continue

		if reel_node.has_node("Card/Panel/Picture"):
			var picture = reel_node.get_node("Card/Panel/Picture")
			reel_node.get_node("Card/Panel/Info").visible = false
			if picture and card_data[card_index].has("image"):
				picture.texture = load(card_data[card_index]["image"])

		if reel_node.has_node("Card/Panel/Info"):
			var info_panel = reel_node.get_node("Card/Panel/Info")
			reel_node.get_node("Card/Panel/Info").visible = false

# Actualiza el display de dinero
func update_money_display() -> void:
	$Header/MoneyDisplay.text = "Money: ¥" + str(Global.money)

func _on_spin_button_pressed() -> void:
	print(tr("Spin button pressed"))  # Debug print
	if spinning or Global.money < spin_cost:
		print(tr("Cannot spin: spinning=%s, money=%d") % [str(spinning), Global.money])  # Debug print
		return

	# Reducir el dinero por la tirada
	Global.money -= spin_cost
	update_money_display()

	# Comenzar la animación de giro
	spinning = true
	$SpinButton.disabled = true

	# Animar los rodillos
	spin_reels()

# Realiza la animación de giro de los rodillos
func spin_reels() -> void:
	print(tr("Starting spin animation"))  # Debug print
	var spin_duration = 2.0
	var reel_nodes = [reel1, reel2, reel3]

	# Verificar que todos los nodos necesarios estén disponibles
	for i in range(3):
		if reel_nodes[i] == null:
			print(tr("Error: reel_node %d is null during spin") % i)
			spinning = false
			$SpinButton.disabled = false
			return

	# Crear efecto visual de giro rápido
	for i in range(10):
		$Plop.play()

		await get_tree().create_timer(0.1).timeout

		for j in range(3):
			var reel_node = reel_nodes[j]
			var temp_card_index = randi() % available_cards.size()

			if reel_node != null and reel_node.has_node("Card/Panel/Picture"):
				var picture = reel_node.get_node("Card/Panel/Picture")
				reel_node.get_node("Card/Panel/Info").visible = false

				if picture != null and temp_card_index < card_data.size():
					picture.texture = load(card_data[temp_card_index]["image"])



	# Generar y mostrar los resultados finales
	reels = [
		randi() % available_cards.size(),
		randi() % available_cards.size(),
		randi() % available_cards.size()
	]

	# Mostrar los resultados uno por uno
	for i in range(3):
		await get_tree().create_timer(0.5).timeout
		var reel_node = reel_nodes[i]
		var card_index = reels[i]

		if reel_node != null and card_index < card_data.size():
			flip_card_animation(reel_node, card_data[card_index])

	# Verificar si ganó
	await get_tree().create_timer(0.5).timeout
	check_win()

	# Finalizar el giro
	spinning = false
	$SpinButton.disabled = false
	print(tr("Spin completed"))  # Debug print

# Crea una animación de flip para una carta
func flip_card_animation(reel_node: Node, card_info: Dictionary) -> void:
	$Flipcard.play()
	if reel_node == null:
		print(tr("Error: Cannot flip a null reel_node"))
		return

	if !reel_node.has_node("Card"):
		print(tr("Error: reel_node does not have a Card child"))
		return

	var card = reel_node.get_node("Card")
	if card == null:
		print(tr("Error: Card node is null"))
		return

	var tween = create_tween()
	if tween == null:
		print(tr("Error: Failed to create tween"))
		return

	# Primera mitad del flip (escala hacia 0 en X)
	tween.tween_property(card, "scale:x", 0.1, 0.15)

	# Cambiar la imagen en el medio del flip
	tween.tween_callback(func():
		if card == null:
			print(tr("Error: Card reference became null during animation"))
			return

		if card.has_node("Panel/Picture"):
			var picture = card.get_node("Panel/Picture")
			if picture != null and card_info.has("image"):
				picture.texture = load(card_info["image"])
		if card.has_node("Panel/Info"):
			var info_panel = card.get_node("Panel/Info")
	)

	# Segunda mitad del flip (escala hacia 1 en X)
	tween.tween_property(card, "scale:x", 1.0, 0.15)

# Verifica si el jugador ganó
func check_win() -> void:
	money_won = 0

	# Contar ocurrencias de cada carta
	card_counts = {}  # Usamos la variable de clase ya definida
	for reel in reels:
		if not card_counts.has(reel):
			card_counts[reel] = 0
		card_counts[reel] += 1

	# Verificar los posibles premios
	var highest_count = 0
	for count in card_counts.values():
		highest_count = max(highest_count, count)

	if highest_count == 3:
		# Tres cartas iguales
		$Fullprize.play()
		money_won = 2500
		show_win_animation(3)
		update_money_display()
	elif highest_count == 2:
		# Dos cartas iguales
		$Smallprize.play()
		money_won = 1000
		show_win_animation(2)
		update_money_display()

	# Añadir el dinero ganado
	if money_won > 0:
		Global.money += money_won
		update_money_display()

	Global.save_data()
	
# Muestra la animación de victoria
func show_win_animation(match_count: int) -> void:
	if !has_node("WinDisplay"):
		print(tr("Error: WinDisplay node not found"))
		return

	if !is_instance_valid($WinDisplay):
		print(tr("Error: WinDisplay node is invalid"))
		return

	$WinDisplay.text = "WIN!\n¥" + str(money_won)
	$WinDisplay.visible = true

	# Crear efecto de parpadeo para las cartas ganadoras
	var matching_card = -1
	for card in card_counts.keys():
		if card_counts[card] == match_count:
			matching_card = card
			break

	if matching_card != -1:
		var reel_nodes = [reel1, reel2, reel3]
		for i in range(3):
			# Verificar que los índices sean válidos
			if i >= reels.size() or !is_instance_valid(reel_nodes[i]):
				continue

			if reels[i] == matching_card:
				if reel_nodes[i].has_node("Card"):
					var card_node = reel_nodes[i].get_node("Card")
					if is_instance_valid(card_node):
						highlight_winning_card(card_node)

	# Ocultar el mensaje después de unos segundos
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid($WinDisplay):
		$WinDisplay.visible = false

# Resalta una carta ganadora
func highlight_winning_card(card_node: Node) -> void:
	if !is_instance_valid(card_node):
		print(tr("Error: Cannot highlight an invalid card node"))
		return

	var tween = create_tween()
	if tween == null:
		print(tr("Error: Failed to create tween for highlighting"))
		return

	# Ciclo de parpadeo
	for i in range(3):
		tween.tween_property(card_node, "modulate", Color(1.5, 1.5, 0.5), 0.2)  # Amarillo brillante
		tween.tween_property(card_node, "modulate", Color(1, 1, 1), 0.2)

# Maneja el evento del botón "Home"
# NOTA: Si este también está conectado en el editor, asegúrate de que el nombre coincida
func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
