extends Control

const CARDS_PER_PAGE = 10

const EFFECT_TYPES = [
	"", "Full Art", "Gold", "Silver", "Holo", "Full Silver", "Full Gold", "Full Holo"
]

const FULL_CARD_EFFECTS = [
	"", "Silver", "Gold", "Holo", "Full Art", "Full Silver", "Full Gold", "Full Holo"
]

var current_set_id: int = 1
var current_page: int = 0
var total_pages: int = 0
var cards_in_set: Array = []

func _ready():
	Global.load_data()
	load_set(current_set_id)
	for i in range(CARDS_PER_PAGE):
		var card_path = get_card_path(i)
		if has_node(card_path + "/Button"):
			var btn = get_node(card_path + "/Button")
			if not btn.is_connected("pressed", Callable(self, "_on_card_button_pressed")):
				btn.connect("pressed", Callable(self, "_on_card_button_pressed").bind(i))
	# Connect HideFull button to close the popup
	if has_node("HideFull"):
		var btn = get_node("HideFull")
		if not btn.is_connected("pressed", Callable(self, "_on_hide_full_pressed")):
			btn.connect("pressed", Callable(self, "_on_hide_full_pressed"))

	if Global.info == false:
		$BoosterTemplate.visible = false
		$FullCards.scale = Vector2(0.90, 0.90)

func load_set(set_id: int):
	cards_in_set = Global.cards.values().filter(func(card):
		return card["set"] == set_id
	)
	cards_in_set.sort_custom(Callable(self, "_sort_by_id"))
	total_pages = ceil(float(cards_in_set.size()) / CARDS_PER_PAGE)
	current_page = 0
	var set_folder = "res://cards/" + str(set_id)
	var image_path = set_folder + "/0.jpg"
	if ResourceLoader.exists(image_path):
		$Booster.texture = load(image_path)
	else:
		print("Error: Booster pack image not found for set", set_id)
	$BoosterTemplate/set.text = "Set #" + str(set_id)
	update_page()

func update_booster_pack_image(set_id: int):
	var set_folder = "res://cards/" + str(set_id)
	var image_path = set_folder + "/0.jpg"
	if ResourceLoader.exists(image_path):
		$Set.texture = load(image_path)
	else:
		print("Error: Booster pack image not found for set", set_id)

func update_page():
	var start_index = current_page * CARDS_PER_PAGE
	var end_index = min(start_index + CARDS_PER_PAGE, cards_in_set.size())
	for i in range(CARDS_PER_PAGE):
		var card_path = get_card_path(i)
		if has_node(card_path):
			var card_node = get_node(card_path)
			if i + start_index < end_index:
				var card_data = cards_in_set[i + start_index]
				if card_node.has_node("Panel/Info/name"):
					card_node.get_node("Panel/Info/name").text = card_data.get("name", "Unknown").to_upper()
				if card_node.has_node("Panel/Info/number"):
					card_node.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
				if card_node.has_node("Panel/Info/red"):
					card_node.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
				if card_node.has_node("Panel/Info/blue"):
					card_node.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
				if card_node.has_node("Panel/Info/yellow"):
					card_node.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))
				if card_node.has_node("Panel/Picture"):
					var image_path = card_data.get("image", "")
					if ResourceLoader.exists(image_path):
						card_node.get_node("Panel/Picture").texture = load(image_path)
					else:
						card_node.get_node("Panel/Picture").texture = null
						print("Warning: Image not found:", image_path)
					var id_set = card_data.get("id_set", card_data.get("id", ""))
					var owned = is_any_effect_owned_for_card(id_set)
					card_node.get_node("Panel/Picture").modulate = Color(1, 1, 1) if owned else Color(0.2, 0.2, 0.2)
				else:
					print("Warning: Panel/Picture node not found in card node:", card_path)
				if card_node.has_method("update_card_appearance"):
					card_node.update_card_appearance()
				card_node.visible = true
			else:
				card_node.visible = false

func is_any_effect_owned_for_card(id_set: String) -> bool:
	if not Global.collection.has(id_set):
		return false
	var entry = Global.collection[id_set]
	if entry.get("amount", 0) > 0:
		return true
	if entry.has("effects"):
		for effect in entry["effects"].keys():
			if entry["effects"][effect] > 0:
				return true
	return false

func get_card_path(index: int) -> String:
	if index < 5:
		return "VBoxContainer/HBoxContainer/Card%d" % (index + 1)
	else:
		return "VBoxContainer/HBoxContainer2/Card%d" % (index - 4)

func get_full_card_path(index: int) -> String:
	if index < 4:
		return "FullCards/HBoxContainer/Card%d" % (index + 1)
	else:
		return "FullCards/HBoxContainer2/Card%d" % (index - 4 +5)

func is_effect_owned_for_card(id_set: String, effect: String) -> bool:
	if not Global.collection.has(id_set):
		return false
	var entry = Global.collection[id_set]
	if effect == "":
		return entry.get("amount", 0) > 0 and entry.get("deck", 0) == 0
	elif effect == "Full Art":
		return entry.has("effects") and entry["effects"].get("Full Art", 0) > 0 and entry.get("deck", 0) == 0
	else:
		return entry.has("effects") and entry["effects"].get(effect, 0) > 0 and entry.get("deck", 0) == 0

func _on_card_button_pressed(card_index):
	var start_index = current_page * CARDS_PER_PAGE
	var actual_index = start_index + card_index
	if actual_index >= cards_in_set.size():
		return
	var card_data = cards_in_set[actual_index]
	var id_set = card_data.get("id_set", card_data.get("id", ""))
	if not is_any_effect_owned_for_card(id_set):
		return
	# Show only the effects you own, hide others
	for i in range(8):
		var effect = FULL_CARD_EFFECTS[i]
		var full_card_path = get_full_card_path(i)
		if has_node(full_card_path):
			var full_card = get_node(full_card_path)
			var owned = is_effect_owned_for_card(id_set, effect)
			full_card.visible = owned
			if owned:
				if full_card.has_method("set_effect"):
					full_card.set_effect(effect)
				if full_card.has_node("Panel/Info/name"):
					full_card.get_node("Panel/Info/name").text = card_data.get("name", "Unknown").to_upper()
				if full_card.has_node("Panel/Info/number"):
					full_card.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
				if full_card.has_node("Panel/Info/red"):
					full_card.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
				if full_card.has_node("Panel/Info/blue"):
					full_card.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
				if full_card.has_node("Panel/Info/yellow"):
					full_card.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))
				if full_card.has_node("Panel/Picture"):
					var image_path = card_data.get("image", "")
					if ResourceLoader.exists(image_path):
						full_card.get_node("Panel/Picture").texture = load(image_path)
					else:
						full_card.get_node("Panel/Picture").texture = null
				if full_card.has_method("update_card_appearance"):
					full_card.update_card_appearance()
	# Hide any extra slots (if you have more than 8 in the scene)
	for i in range(8, 13):
		var full_card_path = get_full_card_path(i)
		if has_node(full_card_path):
			get_node(full_card_path).visible = false
	# Show FullCards and HideFull buttons
	if has_node("FullCards"):
		get_node("FullCards").visible = true
		get_node("VBoxContainer").visible = false
	if has_node("HideFull"):
		get_node("HideFull").visible = true

func _on_hide_full_pressed():
	if has_node("FullCards"):
		get_node("FullCards").visible = false
		get_node("VBoxContainer").visible = true
	if has_node("HideFull"):
		get_node("HideFull").visible = false

func _on_full_card_button_pressed():
	# Deprecated: not used anymore
	pass

func _on_button_left_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		update_page()
	else:
		print("Already on the first page")

func _on_button_right_pressed() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		update_page()
	else:
		print("Already on the last page")

func _on_set_left_pressed() -> void:
	current_set_id -= 1
	if current_set_id < 1:
		current_set_id = Global.set_editions.size()
	load_set(current_set_id)

func _on_set_right_pressed() -> void:
	current_set_id += 1
	if current_set_id > Global.set_editions.size():
		current_set_id = 1
	load_set(current_set_id)

func _sort_by_id(card_a: Dictionary, card_b: Dictionary) -> bool:
	return card_a["id"] < card_b["id"]

func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
