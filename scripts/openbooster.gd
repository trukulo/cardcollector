extends Node

var booster_pack: Array = []
var rarity_order = {"D": 0, "C": 1, "B": 2, "A": 3, "S": 4, "X": 5}
var effect_probabilities = {
	"Full Art": 10.0,  # 10%
	"Silver": 5.0,     # 5%
	"Gold": 2.0,       # 2%
	"Holo": 0.5,       # 0.5%
	"Full Silver": 5.0,  # 5%
	"Full Gold": 2.0,    # 2%
	"Full Holo": 0.5     # 0.5%
}
var current_card_displayed = null
var current_set_id = 1
var cards_revealed = 0
var reveal_timer: Timer

func _ready():
	Global.load_data()
	current_set_id = Global.selected_set
	generate_booster_pack(current_set_id)
	initialize_face_down_cards()
	reveal_timer = Timer.new()
	add_child(reveal_timer)
	reveal_timer.wait_time = 0.5
	reveal_timer.one_shot = true
	reveal_timer.connect("timeout", _on_reveal_timer_timeout)
	start_next_reveal()
	# Show current set at the top
	if has_node("Collection2"):
		$Collection2.text = "Set: " + str(current_set_id)

func is_card_new(id_set: String, effect: String) -> bool:
	if not Global.collection.has(id_set):
		return true
	var entry = Global.collection[id_set]
	if effect == "":
		return entry.get("amount", 0) == 0
	else:
		return entry.get("effects", {}).get(effect, 0) == 0

func update_collection_label():
	if has_node("Collection"):
		var collection_label = get_node("Collection")
		var total_cards_in_set = 0
		var owned_cards_in_set = 0
		collection_label.text = "Set " + str(current_set_id)
		print("Collection status: " + collection_label.text)

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
	if Global.info:
		for card in booster_pack:
			card["effect"] = assign_card_effect()
			update_card_price(card)
	else:
		for card in booster_pack:
			card["effect"] = ""
			var id_set = card["id_set"]
			card["price"] = Global.prices.get(id_set, 0.0)
	booster_pack.sort_custom(Callable(self, "_sort_by_rarity"))
	print("Booster Pack: Generado con " + str(booster_pack.size()) + " cartas")
	for card in booster_pack:
		var id_set = card["id_set"]
		var amount = Global.get_amount(id_set)
		print("Carta: " + id_set + " - Rareza: " + card["rarity"] + " - Efecto: " + card.get("effect", "none") + " - Precio: ¥" + str(Global.prices[id_set]) + " - En colección: " + str(amount))

func save_cards_to_collection():
	for card in booster_pack:
		var id_set = card["id_set"]
		var effect = card.get("effect", "")
		Global.add_to_collection(id_set, 1, effect, 0)
	Global.save_data()
	print("Booster Pack: Todas las cartas guardadas y datos almacenados")
	update_collection_label()

func add_cards_to_booster(cards: Array, count: int) -> void:
	for i in range(min(count, cards.size())):
		booster_pack.append(cards[i])

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
	if has_node("CardContainer"):
		var card_container = get_node("CardContainer")
		for i in range(5):
			var card_node_name = "Card" + str(i + 1)
			if card_container.has_node(card_node_name):
				var card_node = card_container.get_node(card_node_name)
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
				var price_label_name = "Price" + str(i + 1)
				if has_node(price_label_name):
					get_node(price_label_name).visible = false

func _on_reveal_timer_timeout():
	start_next_reveal()

func reveal_card(index: int):
	if has_node("CardContainer"):
		var card_container = get_node("CardContainer")
		var card_node_name = "Card" + str(index + 1)
		if card_container.has_node(card_node_name):
			var card_node = card_container.get_node(card_node_name)
			var card = booster_pack[index]
			var tween = create_tween()
			tween.tween_interval(0.5)
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
			tween.tween_interval(0.25)
			tween.tween_callback(func():
				var price_label_name = "Price" + str(index + 1)
				if has_node(price_label_name):
					var price_label = get_node(price_label_name)
					price_label.visible = true
					var id_set = card["id_set"]
					var effect = card.get("effect", "")
					var price = Global.prices.get(id_set, 0.0)
					var new_prefix = ""
					if is_card_new(id_set, effect):
						new_prefix = "NEW\n"
					if effect != "":
						price_label.text = "%s%s\n¥%d" % [new_prefix, effect, price]
					else:
						price_label.text = "%s¥%d" % [new_prefix, price]
				# Save after the last card is revealed and labeled
				if index == 4:
					save_cards_to_collection()
					update_collection_label()
			)

func start_next_reveal():
	if cards_revealed < 5:
		reveal_card(cards_revealed)
		cards_revealed += 1
		reveal_timer.start()

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
	get_tree().change_scene_to_file("res://scenes/choose_booster.tscn")

func get_effect_multiplier(effect: String) -> float:
	match effect:
		"Silver":
			return 2  # x2
		"Gold":
			return 3  # x3
		"Holo":
			return 4  # x4
		"Full Art":
			return 5  # x5
		"Full Silver":
			return 6  # x6
		"Full Gold":
			return 8  # x8
		"Full Holo":
			return 10  # x10
		_:
			return 1  # No multiplier for other effects

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
		red_label.add_theme_color_override("font_color", Color8(135, 39, 39))
	if card_node.has_node("Panel/Info/blue"):
		var blue_label = card_node.get_node("Panel/Info/blue")
		blue_label.text = str(card_data.get("blue", 0))
		blue_label.add_theme_color_override("font_color", Color8(59, 90, 109))
	if card_node.has_node("Panel/Info/yellow"):
		var yellow_label = card_node.get_node("Panel/Info/yellow")
		yellow_label.text = str(card_data.get("yellow", 0))
		yellow_label.add_theme_color_override("font_color", Color8(197, 197, 56))
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
