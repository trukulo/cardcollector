extends Control

func _ready():
	$Souls.text = "Souls: " + str(Global.souls)
	if $Card.has_node("Panel/Picture"):
		$Card.get_node("Panel/Picture").texture = load("res://gui/backcard.jpg")
	# Hide overlays or effects if any
	if $Card.has_method("set_effect"):
		$Card.set_effect("")  # Remove any effect overlay
	if $Card.has_node("Panel/Info"):
		$Card.get_node("Panel/Info").visible = false
	if $Card.has_node("Panel/Picture"):
		$Card.get_node("Panel/Picture").position.y = 0

func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _sacrifice_for_card(souls_cost):
	if $Card.has_node("Panel/Info"):
		$Card.get_node("Panel/Info").visible = true
	$Panel.visible = true

	if Global.souls < souls_cost:
		return  # Not enough souls

	Global.souls -= souls_cost
	$Souls.text = "Souls: " + str(Global.souls)

	# Make Panel visible when sacrificing souls
	if $Card.has_node("Panel"):
		$Card.get_node("Panel").visible = true

	# Calculate rarity boost based on souls spent
	# The more souls spent, the better chances for rare cards
	var rarity_boost = calculate_rarity_boost(souls_cost)

	# Build the rarity pool with adjusted weights based on souls spent
	var cards_by_rarity = {
		"D": [],
		"C": [],
		"B": [],
		"A": [],
		"S": [],
		"X": []
	}
	for card in Global.cards.values():
		var rarity = card.get("rarity", "D")
		if cards_by_rarity.has(rarity):
			cards_by_rarity[rarity].append(card)

	# Base weights
	var base_weights = {
		"D": 1000,
		"C": 300,
		"B": 150,
		"A": 20,
		"S": 10,
		"X": 1
	}

	# Apply rarity boost to weights
	var adjusted_weights = apply_rarity_boost(base_weights, rarity_boost)

	var rare_pool = []
	for rarity in cards_by_rarity.keys():
		for card in cards_by_rarity[rarity]:
			rare_pool.append({"card": card, "weight": adjusted_weights[rarity]})
	rare_pool.shuffle()

	# Weighted random selection
	var total_weight = 0
	for entry in rare_pool:
		total_weight += entry["weight"]
	var pick = randf() * total_weight
	var chosen_card = null
	for entry in rare_pool:
		pick -= entry["weight"]
		if pick < 0:
			chosen_card = entry["card"]
			break

	# Base effect probabilities
	var base_effect_probabilities = {
		"Silver": 3.5,
		"Gold": 3.0,
		"Holo": 2.5,
		"Full Art": 2.0,
		"Full Silver": 1.5,
		"Full Gold": 1.0,
		"Full Holo": 0.5
	}

	# Apply effect boost based on souls spent
	var effect_boost = calculate_effect_boost(souls_cost)
	var adjusted_effect_probabilities = apply_effect_boost(base_effect_probabilities, effect_boost)

	# Create the effect pool with the adjusted probabilities
	var effect_pool = [""]  # Basic effect always present
	var effect_pool_size = 1000  # Total tickets in the pool
	var basic_effect_count = effect_pool_size

	for effect in adjusted_effect_probabilities.keys():
		var effect_count = int(adjusted_effect_probabilities[effect] * 10)
		for i in range(effect_count):
			effect_pool.append(effect)
		basic_effect_count -= effect_count

	# Fill the rest with basic effects (no special effect)
	for i in range(basic_effect_count):
		effect_pool.append("")

	var chosen_effect = effect_pool[randi() % effect_pool.size()]

	# Get random grading from Global
	var grading = Global.get_random_grading()

	# Calculate price based on card's base price, effect and grading
	var id_set = chosen_card.get("id_set", chosen_card.get("id", ""))
	var base_price = Global.prices.get(id_set, 0.0)
	var effect_multiplier = get_effect_multiplier(chosen_effect)

	# Calculate price using the formula from your booster pack code
	var price = base_price * effect_multiplier
	price *= 0.2 * (2.7 ** (grading - 6))  # Using your exponential grading formula
	price = int(max(1, round(price/2)))

	# Show the card in $Card
	if $Card.has_node("Panel/Picture"):
		var image_path = chosen_card.get("image", "")
		if ResourceLoader.exists(image_path):
			$Card.get_node("Panel/Picture").texture = load(image_path)
		else:
			$Card.get_node("Panel/Picture").texture = null

	if $Card.has_method("set_effect"):
		$Card.set_effect(chosen_effect)

	chosen_card["effect"] = chosen_effect
	_populate_card($Card, chosen_card)

	# Display card details directly in Panel/Price
	var card_set = chosen_card.get("set", "Unknown")
	var card_rarity = chosen_card.get("rarity", "D")
	var effect_text = chosen_effect if chosen_effect != "" else "None"

	var details = "Grading: " + str(grading) + "\n"
	details += "Set: " + str(card_set) + "\n"
	details += "Rarity: " + card_rarity + "\n"
	details += "Effect: " + effect_text + "\n"
	details += "Price: ¥" + str(price)
	$Panel/Price.text = details

	# Add to collection
	var new_card = {
		"effect": chosen_effect,
		"protection": 0,
		"grading": grading
	}

	if not Global.collection.has(id_set):
		Global.collection[id_set] = {"cards": []}
	Global.collection[id_set]["cards"].append(new_card)
	Global.save_data()

# Get effect multiplier using the same formula as in your booster pack code
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

# Calculate rarity boost factor based on souls spent - IMPROVED
func calculate_rarity_boost(souls_cost):
	# Make boost even steeper while maintaining low values for smaller soul costs
	return pow(souls_cost / 3.0, 1.4)

# Apply rarity boost to base weights - IMPROVED
func apply_rarity_boost(base_weights, boost_factor):
	var adjusted_weights = {}

	# More dramatic shifts for the highest soul costs
	adjusted_weights["D"] = max(base_weights["D"] * (1.0 - 0.05 * boost_factor), base_weights["D"] * 0.1)
	adjusted_weights["C"] = max(base_weights["C"] * (1.0 - 0.04 * boost_factor), base_weights["C"] * 0.15)
	adjusted_weights["B"] = max(base_weights["B"] * (1.0 - 0.02 * boost_factor), base_weights["B"] * 0.2)
	adjusted_weights["A"] = base_weights["A"] * (1.0 + 0.5 * boost_factor)
	adjusted_weights["S"] = base_weights["S"] * (1.0 + 1.0 * boost_factor)
	adjusted_weights["X"] = base_weights["X"] * (1.0 + 10.0 * boost_factor)

	return adjusted_weights

# Calculate effect boost factor based on souls spent
func calculate_effect_boost(souls_cost):
	# Similar exponential boost for effects
	return pow(souls_cost / 3.0, 1.3)

# Apply effect boost to base effect probabilities
func apply_effect_boost(base_probabilities, boost_factor):
	var adjusted_probabilities = {}

	# Boost each effect probability based on the boost factor
	for effect in base_probabilities.keys():
		# Higher tier effects get a larger boost
		var tier_multiplier = 1.0
		if effect.begins_with("Full"):
			tier_multiplier = 2.0
		elif effect in ["Gold", "Holo"]:
			tier_multiplier = 1.5

		# Calculate adjusted probability (cap at 15% for any effect)
		adjusted_probabilities[effect] = min(base_probabilities[effect] * (1.0 + boost_factor * tier_multiplier * 0.3), 15.0)

	return adjusted_probabilities

func _populate_card(card_node: Node, card_data: Dictionary) -> void:
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = str(card_data.get("name", "Unknown")).to_upper()
	if card_node.has_node("Panel/Info/number"):
		card_node.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
	if card_node.has_node("Panel/Info/red"):
		card_node.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
	if card_node.has_node("Panel/Info/blue"):
		card_node.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
	if card_node.has_node("Panel/Info/yellow"):
		card_node.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))
	if card_node.has_node("Panel/Info/set"):
		card_node.get_node("Panel/Info/set").visible = false
	if card_node.has_node("Panel/Info/rarity"):
		card_node.get_node("Panel/Info/rarity").visible = false
	if card_node.has_node("Panel/Picture"):
		var image_path = card_data.get("image", "")
		if image_path != "" and ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
	if card_node.has_method("set_effect"):
		card_node.set_effect(card_data.get("effect", ""))

func _on_souls_3_pressed() -> void:
	if Global.souls < 3:
		$NotMoney.visible = true
		return
	else:
		_sacrifice_for_card(3)

func _on_souls_7_pressed() -> void:
	if Global.souls < 7:
		$NotMoney.visible = true
		return
	else:
		_sacrifice_for_card(7)

func _on_souls_13_pressed() -> void:
	if Global.souls < 13:
		$NotMoney.visible = true
		return
	else:
		_sacrifice_for_card(13)

func _on_souls_23_pressed() -> void:
	if Global.souls < 23:
		$NotMoney.visible = true
		return
	else:
		_sacrifice_for_card(23)

func _on_souls_31_pressed() -> void:
	if Global.souls < 31:
		$NotMoney.visible = true
		return
	else:
		_sacrifice_for_card(31)
