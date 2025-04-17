#openbooster.gd
extends Node

var booster_pack: Array = []
var rarity_order = {"D": 0, "C": 1, "B": 2, "A": 3, "S": 4, "X": 5}

# Define effect probabilities
var effect_probabilities = {
	"Full Art": 10.0,  # 10%
	"Silver": 5.0,     # 5%
	"Gold": 2.0,       # 2%
	"Holo": 0.5,       # 0.5%
	"Full Silver": 5.0,  # 5%
	"Full Gold": 2.0,    # 2%
	"Full Holo": 0.5     # 0.5%
}

# Current displayed card info
var current_card_displayed = null
var current_set_id = 1

# Add these variables at the top
var cards_revealed = 0
var reveal_timer: Timer

func _ready():
	Global.load_data()
	current_set_id = Global.selected_set
	
	generate_booster_pack(current_set_id)
	initialize_face_down_cards()
	
	# Setup timer first
	reveal_timer = Timer.new()
	add_child(reveal_timer)
	reveal_timer.wait_time = 0.5
	reveal_timer.one_shot = true
	reveal_timer.connect("timeout", _on_reveal_timer_timeout)
	
	# Start reveal process
	start_next_reveal()
	
	# REMOVED save_cards_to_collection() from here
	$Collection2.text = Global.get_collection_rarity_summary()

# Update the collection label with set statistics
func update_collection_label():
	if has_node("Collection"):
		var collection_label = get_node("Collection")
		
		# Count total cards in the set
		var total_cards_in_set = 0
		var owned_cards_in_set = 0
		
		for card in Global.cards.values():
			if card["set"] == current_set_id:
				total_cards_in_set += 1
				# Check if the player owns this card
				var id_set = card["id_set"]
				if Global.get_amount(id_set) > 0:
					owned_cards_in_set += 1
		
		collection_label.text = "Set " + str(current_set_id) + ": " + str(owned_cards_in_set) + "/" + str(total_cards_in_set)
		print("Collection status: " + collection_label.text)

# Función para generar el booster pack
func generate_booster_pack(set_id: int) -> void:
	booster_pack = []
	var cards_by_rarity = {"D": [], "C": [], "B": [], "A": [], "S": [], "X": []}
	
	for card in Global.cards.values():
		if card["set"] == set_id:
			var rarity = card["rarity"]
			if cards_by_rarity.has(rarity):
				cards_by_rarity[rarity].append(card)
	
	for rarity in cards_by_rarity.keys():
		cards_by_rarity[rarity].shuffle()
	
	# Distribución: 3 cartas D, 1 carta C y 1 cartas de mayor rareza
	add_cards_to_booster(cards_by_rarity["D"], 3)
	add_cards_to_booster(cards_by_rarity["C"], 1)
	
	var rare_pool = []
	for card in cards_by_rarity["B"]:
		rare_pool.append({"card": card, "weight": 50})
	for card in cards_by_rarity["A"]:
		rare_pool.append({"card": card, "weight": 30})
	for card in cards_by_rarity["S"]:
		rare_pool.append({"card": card, "weight": 15})
	for card in cards_by_rarity["X"]:
		rare_pool.append({"card": card, "weight": 5})
	rare_pool.shuffle()
	
	for i in range(1):
		if rare_pool.size() > 0:
			var selected_card = weighted_random_selection(rare_pool)
			if selected_card:
				booster_pack.append(selected_card)
				for j in range(rare_pool.size() - 1, -1, -1):
					if rare_pool[j]["card"] == selected_card:
						rare_pool.remove_at(j)
	
	# Assign effects to cards and update their prices only if Global.info is true
	if Global.info:
		for card in booster_pack:
			card["effect"] = assign_card_effect()
			update_card_price(card)  # Update the card's price based on its effect
	else:
		# If Global.info is false, ensure no effect is assigned and prices remain unchanged
		for card in booster_pack:
			card["effect"] = ""  # No effect
			# Optionally, reset the price to the base price if needed
			var id_set = card["id_set"]
			card["price"] = Global.prices.get(id_set, 0.0)

	booster_pack.sort_custom(Callable(self, "_sort_by_rarity"))
	
	print("Booster Pack: Generado con " + str(booster_pack.size()) + " cartas")
	for card in booster_pack:
		var id_set = card["id_set"]
		var amount = Global.get_amount(id_set)
		print("Carta: " + id_set + " - Rareza: " + card["rarity"] + " - Efecto: " + card.get("effect", "none") + " - Precio: $" + str(Global.prices[id_set]) + " - En colección: " + str(amount))

# Guarda las cartas del booster pack en la colección del jugador
func save_cards_to_collection():
	for card in booster_pack:
		var id_set = card["id_set"]
		var effect = card.get("effect", "")
		# Explicitly pass effect parameter
		Global.add_to_collection(id_set, 1, 0, effect)  # <-- Effect flows here
	
	Global.save_data()
	print("Booster Pack: Todas las cartas guardadas y datos almacenados")
	update_collection_label()

# Ayuda a añadir cartas al booster pack
func add_cards_to_booster(cards: Array, count: int) -> void:
	for i in range(min(count, cards.size())):
		booster_pack.append(cards[i])

# Selección aleatoria ponderada
func weighted_random_selection(pool: Array):
	if pool.size() == 0:
		return null
		
	var total_weight = 0
	for item in pool:
		total_weight += item["weight"]
	
	if total_weight <= 0:
		return pool[randi() % pool.size()]["card"]
	
	var random_value = randf() * total_weight
	var current_weight = 0
	for item in pool:
		current_weight += item["weight"]
		if random_value <= current_weight:
			return item["card"]
	return pool[pool.size() - 1]["card"]

# Función de ordenación de cartas (de D a X)
func _sort_by_rarity(card_a, card_b) -> bool:
	return rarity_order[card_a["rarity"]] < rarity_order[card_b["rarity"]]

# Add new function to initialize cards face down
func initialize_face_down_cards():
	if has_node("CardContainer"):
		var card_container = get_node("CardContainer")
		for i in range(5):  # For all 5 cards
			var card_node_name = "Card" + str(i + 1)
			if card_container.has_node(card_node_name):
				var card_node = card_container.get_node(card_node_name)
				
				 # Get the Panel node which contains the actual card
				if card_node.has_node("Panel"):
					var panel = card_node.get_node("Panel")
					# Set pivot to center of the Panel
					panel.pivot_offset = Vector2(panel.size.x / 2, panel.size.y / 2)
					panel.scale = Vector2(1, 1)  # Reset scale
				
				# Set backcard image to the Panel/Picture node
				if card_node.has_node("Panel/Picture"):
					var texture_rect = card_node.get_node("Panel/Picture")
					texture_rect.texture = load("res://gui/backcard.jpg")
					card_node.get_node("Panel/Picture").position.y = 5

				if card_node.has_node("Panel/Info"):
					card_node.get_node("Panel/Info").visible = false
				# Hide price label
				var price_label_name = "Price" + str(i + 1)
				if has_node(price_label_name):
					get_node(price_label_name).visible = false

# Add reveal timer callback
func _on_reveal_timer_timeout():
	start_next_reveal()

# Check if a card+effect combination exists in collection
func is_duplicate_with_effect(id_set: String, effect: String) -> bool:
	if not Global.collection.has(id_set):
		return false  # Card doesn't exist at all
	
	var entry = Global.collection[id_set]
	
	if effect == "":
		# Check if base version exists (no effects)
		return entry["amount"] > 0
	else:
		# Check if this exact effect variant exists
		return entry["effects"].get(effect, 0) > 0

# Add function to reveal a specific card
func reveal_card(index: int):
	if has_node("CardContainer"):
		var card_container = get_node("CardContainer")
		var card_node_name = "Card" + str(index + 1)
		if card_container.has_node(card_node_name):
			var card_node = card_container.get_node(card_node_name)
			var card = booster_pack[index]
			
			# Create flip animation
			var tween = create_tween()
			
			# Add initial delay before starting the flip
			tween.tween_interval(0.5)
			
				# First half of flip (scale down)
			tween.tween_property(card_node, "scale:x", 0.1, 0.075)
			
			# At the middle of the flip, change the card face
			tween.tween_callback(func():
				# Show the actual card image
				if card_node.has_node("Panel/Picture"):
					var texture_rect = card_node.get_node("Panel/Picture")
					var image_path = card["image"]
					if ResourceLoader.exists(image_path):
						texture_rect.texture = load(image_path)
				
				# Show the info panel
				if card_node.has_node("Panel/Info"):
					card_node.get_node("Panel/Info").visible = true

				# Update card info
				_populate_card(card_node, card)
			)
			
			# Second half of flip (scale up)
			tween.tween_property(card_node, "scale:x", 1.0, 0.075)
			
			# Add a shorter delay after the flip (changed from 0.5 to 0.25)
			tween.tween_interval(0.25)  # Reduced from 0.5 to 0.25 seconds
			
			# After delay, show price
			tween.tween_callback(func():
				# Show price label
				var price_label_name = "Price" + str(index + 1)
				if has_node(price_label_name):
					var price_label = get_node(price_label_name)
					price_label.visible = true
					var id_set = card["id_set"]
					var effect = card.get("effect", "")
					
					# Check if duplicate with same effect
					var is_duplicate = is_duplicate_with_effect(id_set, effect)
					var price = Global.prices.get(id_set, 0.0)
					
					if effect != "":
						if is_duplicate:
							price_label.text = "Duplicated\n%s - $%.2f" % [effect, price]
						else:
							price_label.text = "%s - $%.2f" % [effect, price]
					else:
						if is_duplicate:
							price_label.text = "Duplicated\n$%.2f" % price
						else:
							price_label.text = "$%.2f" % price
			)
			
func start_next_reveal():
	if cards_revealed < 5:
		reveal_card(cards_revealed)
		cards_revealed += 1
		reveal_timer.start()
	else:
		# ONLY SAVE AFTER ALL CARDS ARE REVEALED
		save_cards_to_collection()
		update_collection_label()

# Assign an effect to a card based on probabilities
func assign_card_effect() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_value = rng.randf() * 100.0  # Generate a random number between 0 and 100
	var cumulative_probability = 0.0
	for effect in effect_probabilities.keys():
		cumulative_probability += effect_probabilities[effect]
		if random_value <= cumulative_probability:
			return effect
	# Default to "none" if no effect is assigned
	return ""

# Function to change the scene
func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/choose_booster.tscn")

func get_effect_multiplier(effect: String) -> float:
	match effect:
		"Silver":
			return 2.0  # x2
		"Gold":
			return 3.0  # x3
		"Holo":
			return 4.0  # x4
		"Full Art":
			return 5.0  # x5
		"Full Silver":
			return 6.0  # x6
		"Full Gold":
			return 8.0  # x8
		"Full Holo":
			return 10.0  # x10
		_:
			return 1.0  # No multiplier for other effects

func update_card_price(card: Dictionary) -> void:
	var id_set = card["id_set"]
	var base_price = Global.prices.get(id_set, 0.0)
	var effect = card.get("effect", "None")
	var multiplier = get_effect_multiplier(effect)
	var updated_price = base_price * multiplier
	Global.prices[id_set] = round(updated_price * 100) / 100  # Round to 2 decimal places

func _populate_card(card_node: Node, card_data: Dictionary) -> void:
	# Set the card name in all caps
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = card_data.get("name", "Unknown").to_upper()

	# Set the card number
	if card_node.has_node("Panel/Info/number"):
		var number_label = card_node.get_node("Panel/Info/number")
		number_label.text = str(card_data.get("id", 0))  # Use the "id" field for the card number

	# Set other card stats (red, blue, yellow)
	if card_node.has_node("Panel/Info/red"):
		var red_label = card_node.get_node("Panel/Info/red")
		red_label.text = str(card_data.get("red", 0))
		red_label.add_theme_color_override("font_color", Color8(135, 39, 39))  # Red: #872727

	if card_node.has_node("Panel/Info/blue"):
		var blue_label = card_node.get_node("Panel/Info/blue")
		blue_label.text = str(card_data.get("blue", 0))
		blue_label.add_theme_color_override("font_color", Color8(59, 90, 109))  # Blue: #3b5a6d

	if card_node.has_node("Panel/Info/yellow"):
		var yellow_label = card_node.get_node("Panel/Info/yellow")
		yellow_label.text = str(card_data.get("yellow", 0))
		yellow_label.add_theme_color_override("font_color", Color8(197, 197, 56))  # Yellow: #c5c538

	# Hide set and rarity nodes
	if card_node.has_node("Panel/Info/set"):
		card_node.get_node("Panel/Info/set").visible = false
	if card_node.has_node("Panel/Info/rarity"):
		card_node.get_node("Panel/Info/rarity").visible = false

	# Set the card image
	if card_node.has_node("Panel/Picture"):
		var texture_rect = card_node.get_node("Panel/Picture")
		var image_path = card_data["image"]
		if ResourceLoader.exists(image_path):
			texture_rect.texture = load(image_path)
		else:
			print("Warning: Image not found:", image_path)

	# Remove any effect from the overlay
	if card_node.has_node("Panel/Info/Overlay"):
		var overlay = card_node.get_node("Panel/Info/Overlay")
		overlay.material = null  # Ensure no material or effect is applied

	# Set the effect and update card appearance
	if card_node.has_method("set_effect"):
		card_node.set_effect(card_data.get("effect", ""))
