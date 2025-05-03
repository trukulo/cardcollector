extends Node

var booster_pack: Array = []
var rarity_order = {"D": 0, "C": 1, "B": 2, "A": 3, "S": 4, "X": 5}
var effect_probabilities = {
	"Silver": 3.5,     # 5%
	"Gold": 3.0,       # 2%
	"Holo": 2.5,       # 0.5%
	"Full Art": 2.0,  # 10%
	"Full Silver": 1.5,  # 5%
	"Full Gold": 1.0,    # 2%
	"Full Holo": 0.5     # 0.5%
}
var current_card_displayed = null
var current_set_id = 1
var cards_revealed = 0
var reveal_timer: Timer
var revealed_cards := []

# Booster type functions
func is_prime(num: int) -> bool:
	if num == 1:
		return true
	if num <= 1:
		return false
	if num <= 3:
		return true
	if num % 2 == 0 or num % 3 == 0:
		return false

	var i = 5
	while i * i <= num:
		if num % i == 0 or num % (i + 2) == 0:
			return false
		i += 6

	return true

func is_even(num: int) -> bool:
	return num % 2 == 0

func is_odd(num: int) -> bool:
	return num % 2 != 0

func is_triple(num: int) -> bool:
	return num % 3 == 0

func _ready():
	Global.load_data()
	revealed_cards = []
	if Global.unlock < 5:
		$ButtonReveal.disabled = true
		$ButtonReveal.text = "Reveal (L)"
	current_set_id = Global.selected_set
	generate_booster_pack(current_set_id)
	for i in range(booster_pack.size()):
		revealed_cards.append(false)
	initialize_face_down_cards()

func is_card_new(id_set: String, effect: String) -> bool:
	if not Global.collection.has(id_set):
		return true
	if effect == "":
		return Global.collection[id_set]["cards"].size() == 0
	else:
		for card in Global.collection[id_set]["cards"]:
			if card["effect"] == effect:
				return false
		return true

func update_collection_label():
	if has_node("Collection"):
		var collection_label = get_node("Collection")
		collection_label.text = "Set " + str(current_set_id)
		print("Collection status: " + collection_label.text)

func generate_booster_pack(set_id: int) -> void:
	booster_pack = []
	var cards_by_rarity = {"D": [], "C": [], "B": [], "A": [], "S": [], "X": []}

	# 1. Group cards by rarity for the selected set
	for card in Global.cards.values():
		if card["set"] == set_id:
			var rarity = card["rarity"]
			if cards_by_rarity.has(rarity):
				cards_by_rarity[rarity].append(card)

	# 2. Shuffle each rarity group
	for rarity in cards_by_rarity.keys():
		cards_by_rarity[rarity].shuffle()

	# Get the booster type and filter cards accordingly
	var booster_type := ""
	if Global.boostertype != "":
		booster_type = Global.boostertype
	if booster_type.is_empty():
		booster_type = "Evens" if randf() < 0.5 else "Odds"

	# 3. Add common cards (D) - 5 cards
	add_cards_to_booster(filter_cards_by_type(cards_by_rarity["D"], booster_type), 5)

	# 4. Add uncommon cards (C) - 2 cards
	add_cards_to_booster(filter_cards_by_type(cards_by_rarity["C"], booster_type), 2)

	# 5. Prepare rare pool (B, A, S, X) with weights
	var rare_pool = []
	for card in filter_cards_by_type(cards_by_rarity["B"], booster_type):
		rare_pool.append({"card": card, "weight": 100})
	for card in filter_cards_by_type(cards_by_rarity["A"], booster_type):
		rare_pool.append({"card": card, "weight": 50})
	for card in filter_cards_by_type(cards_by_rarity["S"], booster_type):
		rare_pool.append({"card": card, "weight": 5})
	for card in filter_cards_by_type(cards_by_rarity["X"], booster_type):
		rare_pool.append({"card": card, "weight": 1})
	rare_pool.shuffle()

	# 6. Add 2 rare cards (weighted random)
	if rare_pool.size() > 0:
		for i in range(2):
			var selected_card = weighted_random_selection(rare_pool)
			if selected_card:
				var card_copy = selected_card.duplicate()
				apply_card_properties(card_copy)
				booster_pack.append(card_copy)

	# 7. Sort and debug
	booster_pack.sort_custom(Callable(self, "_sort_by_rarity"))
	print("Booster Pack: Generated with " + str(booster_pack.size()) + " cards (Type: " + booster_type + ")")

# Filter cards based on booster type
func filter_cards_by_type(cards: Array, booster_type: String) -> Array:
	# If there are no cards or too few cards, return the original array to avoid empty boosters
	if cards.size() < 3:
		return cards

	var filtered_cards = []
	for card in cards:
		var card_number = card["id"]
		var valid = false

		match booster_type:
			"Primes":
				valid = is_prime(card_number)
			"Evens":
				valid = is_even(card_number)
			"Odds":
				valid = is_odd(card_number)
			"Triples":
				valid = is_triple(card_number)
			_:  # Default case
				valid = true  # Include all cards

		if valid:
			filtered_cards.append(card)

	# If filter results in too few cards, return original array
	if filtered_cards.size() < 2:
		return cards

	return filtered_cards

# Apply random effects and grading to a card
func apply_card_properties(card: Dictionary) -> void:
	# Use assign_card_effect to potentially add an effect
	var effect = assign_card_effect()
	if effect != "":
		card["effect"] = effect

	# Get a random grading value from Global
	card["grading"] = Global.get_random_grading()

	# Set default protection
	card["protection"] = 0

func save_cards_to_collection():
	for card in booster_pack:
		var id_set = card["id_set"]
		var effect = card.get("effect", "")
		var grading = card.get("grading", Global.get_random_grading())
		var protection = card.get("protection", 0)
		Global.add_to_collection(id_set, 1, effect, 0, grading, protection)
	Global.save_data()
	update_collection_label()

func add_cards_to_booster(cards: Array, count: int) -> void:
	var cards_to_add = min(count, cards.size())
	for i in range(cards_to_add):
		var card_copy = cards[i].duplicate()
		apply_card_properties(card_copy)
		booster_pack.append(card_copy)

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

func _sort_by_rarity(card_a, card_b) -> bool:
	return rarity_order[card_a["rarity"]] < rarity_order[card_b["rarity"]]

func initialize_face_down_cards():
	# Initialize all 9 cards in the new structure
	for i in range(9):
		var container_idx = i / 3 + 1
		var card_idx = i % 3 + 1 + (container_idx - 1) * 3
		var card_path = "VBoxContainer/CardContainer" + str(container_idx) + "/Card" + str(card_idx)

		if has_node(card_path):
			var card_node = get_node(card_path)
			if card_node.has_node("Panel"):
				var panel = card_node.get_node("Panel")
				panel.pivot_offset = Vector2(panel.size.x / 2, panel.size.y / 2)
				panel.scale = Vector2(1, 1)
			if card_node.has_node("Panel/Picture"):
				var texture_rect = card_node.get_node("Panel/Picture")
				texture_rect.texture = load("res://gui/backcard.jpg")
				card_node.get_node("Panel/Picture").position.y = 5
			if card_node.has_node("Panel/Info"):
				card_node.get_node("Panel/Info").visible = false

		# Hide price labels
		var price_container_idx = (i / 3) + 1
		var price_idx = i % 3 + 1 + (price_container_idx - 1) * 3
		var price_path = "VBoxContainer/PriceContainer" + str(price_container_idx) + "/Price" + str(price_idx)
		if has_node(price_path):
			get_node(price_path).text= ""

func reveal_card(index: int):
	var container_idx = index / 3 + 1
	var card_idx = index % 3 + 1 + (container_idx - 1) * 3
	var card_path = "VBoxContainer/CardContainer" + str(container_idx) + "/Card" + str(card_idx)

	if has_node(card_path):
		var card_node = get_node(card_path)
		var card = booster_pack[index]
		var tween = create_tween()
		tween.tween_interval(0.10)
		tween.tween_property(card_node, "scale:x", 0.1, 0.075)
		tween.tween_callback(func():
			if card_node.has_node("Panel/Picture"):
				var texture_rect = card_node.get_node("Panel/Picture")
				var image_path = card["image"]
				if ResourceLoader.exists(image_path):
					texture_rect.texture = load(image_path)
			if card_node.has_node("Panel/Info"):
				card_node.get_node("Panel/Info").visible = true
			_populate_card(card_node, card)
		)
		tween.tween_property(card_node, "scale:x", 1.0, 0.075)
		tween.tween_interval(0.10)
		tween.tween_callback(func():
			var price_container_idx = (index / 3) + 1
			var price_idx = index % 3 + 1 + (price_container_idx - 1) * 3
			var price_path = "VBoxContainer/PriceContainer" + str(price_container_idx) + "/Price" + str(price_idx)

			if has_node(price_path):
				var price_label = get_node(price_path)
				price_label.visible = true
				var id_set = card["id_set"]
				var effect = card.get("effect", "")
				var base_price = Global.prices.get(id_set, 0.0)

				# Get the card's actual grading
				var card_grading = card.get("grading", 1.0)

				# Calculate effect modifier
				var effect_modifier = 1.0
				if effect != "":
					effect_modifier = get_effect_multiplier(effect)

				# Calculate price using grading and effect
				var price = base_price * effect_modifier
				price *= 0.2 * (1.3 ** (card_grading - 6))  # Tuned base (1.7)
				price = int(max(1, round(price/2)))

				# Display in the label
				var new_prefix = ""
				if is_card_new(id_set, effect):
					new_prefix = "NEW - "
				if effect != "":
					price_label.text = "%s%s\n¥%d" % [new_prefix, effect, price]
				else:
					price_label.text = "%s¥%d" % [new_prefix, price]

			# Save after the last card is revealed and labeled
			if index == 8:
				save_cards_to_collection()
				update_collection_label()

			_check_all_revealed()
		)

func assign_card_effect() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_value = rng.randf() * 100.0
	var cumulative_probability = 0.0

	for effect in effect_probabilities.keys():
		cumulative_probability += effect_probabilities[effect]
		if random_value <= cumulative_probability:
			return effect
	return ""

func _on_button_ok_pressed() -> void:
	Global.save_data()
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
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = str(card_data.get("name", "Unknown")).to_upper()
	if card_node.has_node("Panel/Info/number"):
		var number_label = card_node.get_node("Panel/Info/number")
		number_label.text = str(card_data.get("id", 0))
	if card_node.has_node("Panel/Info/red"):
		var red_label = card_node.get_node("Panel/Info/red")
		red_label.text = str(card_data.get("red", 0))

	if card_node.has_node("Panel/Info/blue"):
		var blue_label = card_node.get_node("Panel/Info/blue")
		blue_label.text = str(card_data.get("blue", 0))

	if card_node.has_node("Panel/Info/yellow"):
		var yellow_label = card_node.get_node("Panel/Info/yellow")
		yellow_label.text = str(card_data.get("yellow", 0))

	if card_node.has_node("Panel/Info/set"):
		card_node.get_node("Panel/Info/set").visible = false
	if card_node.has_node("Panel/Info/rarity"):
		card_node.get_node("Panel/Info/rarity").visible = false
	if card_node.has_node("Panel/Picture"):
		var texture_rect = card_node.get_node("Panel/Picture")
		var image_path = card_data["image"] if card_data.has("image") else ""
		if image_path != "" and ResourceLoader.exists(image_path):
			texture_rect.texture = load(image_path)
		else:
			print("Warning: Image not found:", image_path)
	if card_node.has_node("Panel/Info/Overlay"):
		var overlay = card_node.get_node("Panel/Info/Overlay")
		overlay.material = null
	if card_node.has_method("set_effect"):
		card_node.set_effect(card_data.get("effect", ""))

# Button handler functions unchanged - just showing one as an example
func _on_button_1_pressed():
	if not revealed_cards[0]:
		reveal_card(0)
		revealed_cards[0] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(0)

func _on_button_2_pressed():
	if not revealed_cards[1]:
		reveal_card(1)
		revealed_cards[1] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(1)

func _on_button_3_pressed():
	if not revealed_cards[2]:
		reveal_card(2)
		revealed_cards[2] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(2)

func _on_button_4_pressed():
	if not revealed_cards[3]:
		reveal_card(3)
		revealed_cards[3] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(3)

func _on_button_5_pressed():
	if not revealed_cards[4]:
		reveal_card(4)
		revealed_cards[4] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(4)

func _on_button_6_pressed():
	if not revealed_cards[5]:
		reveal_card(5)
		revealed_cards[5] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(5)

func _on_button_7_pressed():
	if not revealed_cards[6]:
		reveal_card(6)
		revealed_cards[6] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(6)

func _on_button_8_pressed():
	if not revealed_cards[7]:
		reveal_card(7)
		revealed_cards[7] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(7)

func _on_button_9_pressed():
	if not revealed_cards[8]:
		reveal_card(8)
		revealed_cards[8] = true
		$ButtonReveal.disabled = true
	else:
		show_full_card(8)

func _on_button_reveal_pressed() -> void:
	# Reveal all cards
	for i in range(9):
		if not revealed_cards[i]:
			reveal_card(i)
			revealed_cards[i] = true
		$ButtonReveal.disabled = true

	_check_all_revealed()

func _show_effects() -> void:
	for i in range(booster_pack.size()):
		var container_idx = i / 3 + 1
		var price_idx = i % 3 + 1 + (container_idx - 1) * 3
		var price_path = "VBoxContainer/PriceContainer" + str(container_idx) + "/Price" + str(price_idx)

		if has_node(price_path):
			var price_label = get_node(price_path)
			var effect = booster_pack[i].get("effect", "")
			price_label.text = effect if effect != "" else "No Effect"
			price_label.visible = true

func _on_button_hide_pressed() -> void:
	$FullCard.visible = false
	$VBoxContainer.visible = true

func show_full_card(index: int):
	var card_data = booster_pack[index]
	if $FullCard.has_node("Panel/Picture"):
		$FullCard.get_node("Panel/Picture").texture = load(card_data["image"])
	if $FullCard.has_node("Panel/Info/name"):
		$FullCard.get_node("Panel/Info/name").text = card_data.get("name", "Unknown")
	if $FullCard.has_node("Panel/Info/number"):
		$FullCard.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
	if $FullCard.has_node("Panel/Info/effect"):
		$FullCard.get_node("Panel/Info/effect").text = card_data.get("effect", "No Effect")
	if $FullCard.has_node("Panel/Info/red"):
		$FullCard.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
	if $FullCard.has_node("Panel/Info/blue"):
		$FullCard.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
	if $FullCard.has_node("Panel/Info/yellow"):
		$FullCard.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))
	# Ensure effect is visually applied
	if $FullCard.has_method("set_effect"):
		$FullCard.set_effect(card_data.get("effect", ""))
	elif $FullCard.has_node("Panel") and $FullCard.get_node("Panel").has_method("set_effect"):
		$FullCard.get_node("Panel").set_effect(card_data.get("effect", ""))
	$FullCard.visible = true
	$VBoxContainer.visible = false

func _check_all_revealed():
	var all_revealed = true
	for revealed in revealed_cards:
		if not revealed:
			all_revealed = false
			break

	if all_revealed:
		# Change button from "Reveal" to "Again (¥XXX)" with the correct cost
		$ButtonReveal.disabled = false
		if Global.unlock < 5:
			$ButtonReveal.disabled = true
			$ButtonReveal.text = "Reveal (L)"
		else:
			# Determine the cost based on the booster type
			var booster_cost = 1000  # Default cost
			match Global.boostertype:
				"Primes":
					booster_cost = 800
				"Triples":
					booster_cost = 900
				"Evens":
					booster_cost = 1100
				"Odds":
					booster_cost = 1000

			$ButtonReveal.disabled = false
			$ButtonReveal.text = "Again (¥%d)" % booster_cost

		# Change button's functionality to open a new pack instead of revealing cards
		if $ButtonReveal.is_connected("pressed", Callable(self, "_on_button_reveal_pressed")):
			$ButtonReveal.disconnect("pressed", Callable(self, "_on_button_reveal_pressed"))
		if not $ButtonReveal.is_connected("pressed", Callable(self, "_on_button_again_pressed")):
			$ButtonReveal.connect("pressed", Callable(self, "_on_button_again_pressed"))

	$ButtonOk.disabled = not all_revealed

func _on_button_again_pressed() -> void:
	# Determine the cost based on the booster type
	var booster_cost = 1000  # Default cost
	match Global.boostertype:
		"Primes":
			booster_cost = 800
		"Triples":
			booster_cost = 900
		"Evens":
			booster_cost = 1100
		"Odds":
			booster_cost = 1000

	# Check if player has enough money
	if Global.money >= booster_cost:
		# Deduct money
		Global.money -= booster_cost
		Global.money_spent += booster_cost
		Global.save_data()

		# Reset card state
		revealed_cards = []
		for i in range(9):
			revealed_cards.append(false)

		# Generate new booster pack
		generate_booster_pack(current_set_id)

		# Reset UI
		initialize_face_down_cards()

		# Reset card effects for all cards
		for container_idx in range(1, 4):
			for card_idx in range(1, 4):
				var actual_card_idx = (container_idx - 1) * 3 + card_idx
				var card_path = "VBoxContainer/CardContainer" + str(container_idx) + "/Card" + str(actual_card_idx)

				if has_node(card_path):
					var card_node = get_node(card_path)
					if card_node.has_method("set_effect"):
						card_node.set_effect("")
					elif card_node.has_node("Panel") and card_node.get_node("Panel").has_method("set_effect"):
						card_node.get_node("Panel").set_effect("")
					if card_node.has_node("Panel/Info/Overlay"):
						var overlay = card_node.get_node("Panel/Info/Overlay")
						overlay.material = null
					if card_node.has_node("Panel/Picture"):
						card_node.get_node("Panel/Picture").position.y = 0

		# Reset button
		$ButtonReveal.text = "Reveal"
		if $ButtonReveal.is_connected("pressed", Callable(self, "_on_button_again_pressed")):
			$ButtonReveal.disconnect("pressed", Callable(self, "_on_button_again_pressed"))
		if not $ButtonReveal.is_connected("pressed", Callable(self, "_on_button_reveal_pressed")):
			$ButtonReveal.connect("pressed", Callable(self, "_on_button_reveal_pressed"))

		# Hide all price labels
		for container_idx in range(1, 4):
			for price_idx in range(1, 4):
				var actual_price_idx = (container_idx - 1) * 3 + price_idx
				var price_path = "VBoxContainer/PriceContainer" + str(container_idx) + "/Price" + str(actual_price_idx)

				if has_node(price_path):
					get_node(price_path).text = ""

		# Disable Ok button until all cards are revealed again
		$ButtonOk.disabled = true
	else:
		# Show "Not enough money" message
		$NotMoney.visible = true
		await get_tree().create_timer(1).timeout
		$NotMoney.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if Global.unlock >= 5:
			_on_button_reveal_pressed()
