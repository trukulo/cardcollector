extends Control

const CARDS_PER_PAGE = 10

enum SortMode { NONE, PRICE_UP, PRICE_DOWN, RARITY_UP, RARITY_DOWN, NAME_UP, NAME_DOWN, NUMBER_UP, NUMBER_DOWN }
var sort_modes = [
	SortMode.NONE, SortMode.PRICE_UP, SortMode.PRICE_DOWN, SortMode.RARITY_UP, SortMode.RARITY_DOWN,
	SortMode.NAME_UP, SortMode.NAME_DOWN, SortMode.NUMBER_UP, SortMode.NUMBER_DOWN
]
var sort_mode: int = SortMode.NONE
var rarity_order = {"D": 0, "C": 1, "B": 2, "A": 3, "S": 4, "X": 5}

var card_keys := [] # Now an array of dictionaries: [{id_set, effect}]
var current_page := 0
var total_pages := 0
var current_set := 0  # 0 = all sets, otherwise set number
var set_ids := []
var card_node_paths = [
	"VBoxContainer/HBoxContainer/Card1", "VBoxContainer/HBoxContainer/Card2", "VBoxContainer/HBoxContainer/Card3",
	"VBoxContainer/HBoxContainer/Card4", "VBoxContainer/HBoxContainer/Card5",
	"VBoxContainer/HBoxContainer2/Card1", "VBoxContainer/HBoxContainer2/Card2", "VBoxContainer/HBoxContainer2/Card3",
	"VBoxContainer/HBoxContainer2/Card4", "VBoxContainer/HBoxContainer2/Card5"
]
var showing_duplicates_only := false

# To remember which card is being shown in FullCard for selling
var fullcard_id_set: Variant = null
var fullcard_effect: String = ""

var pending_sell_id_set: Variant = null
var pending_sell_effect: String = ""
var confirm_dialog: ConfirmationDialog = null

func _ready():
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to sell this card?"
	confirm_dialog.get_ok_button().text = "Sell"
	confirm_dialog.get_cancel_button().text = "Cancel"
	confirm_dialog.connect("confirmed", Callable(self, "_on_confirm_sell"))
	add_child(confirm_dialog)
	Global.load_data()
	set_ids = [0] + Global.set_editions.keys()
	set_ids.sort()
	current_set = 0
	update_set_label()
	update_card_keys()
	current_page = 0
	populate_cards()
	# Print debug info for prices
	print("DEBUG: First 10 Global.prices entries:")
	var count = 0
	for k in Global.prices.keys():
		print("  ", k, ":", Global.prices[k])
		count += 1
		if count >= 10:
			break
	# Connect set navigation buttons if not connected in the editor
	if has_node("Sets/SetLeft"):
		get_node("Sets/SetLeft").connect("pressed", Callable(self, "_on_set_left_pressed"))
	if has_node("Sets/SetRight"):
		get_node("Sets/SetRight").connect("pressed", Callable(self, "_on_set_right_pressed"))
	# Connect sort navigation buttons
	if has_node("Sort/SortLeft"):
		get_node("Sort/SortLeft").connect("pressed", Callable(self, "_on_sort_left_pressed"))
	if has_node("Sort/SortRight"):
		get_node("Sort/SortRight").connect("pressed", Callable(self, "_on_sort_right_pressed"))
	update_sort_label()
	# Connect card button signals
	for i in range(CARDS_PER_PAGE):
		if has_node(card_node_paths[i] + "/Button"):
			var btn = get_node(card_node_paths[i] + "/Button")
			if not btn.is_connected("pressed", Callable(self, "_on_card_button_pressed")):
				btn.connect("pressed", Callable(self, "_on_card_button_pressed").bind(i))
	# Connect FullCard close button
	if has_node("FullCard/Button"):
		var btn = get_node("FullCard/Button")
		if not btn.is_connected("pressed", Callable(self, "_on_full_card_button_pressed")):
			btn.connect("pressed", Callable(self, "_on_full_card_button_pressed"))
	# Connect dupe button
	if has_node("ButtonDupe"):
		var btn = get_node("ButtonDupe")
		if not btn.is_connected("pressed", Callable(self, "_on_button_dupe_pressed")):
			btn.connect("pressed", Callable(self, "_on_button_dupe_pressed"))
		btn.text = "Duplicates Only"
	# Connect sell button
	if has_node("ButtonSell"):
		var btn = get_node("ButtonSell")
		btn.connect("pressed", Callable(self, "_on_button_sell_pressed"))
		btn.visible = false

# Sorting label update
func update_sort_label():
	if has_node("Sort/Sort"):
		var label = get_node("Sort/Sort")
		match sort_mode:
			SortMode.NONE:
				label.text = "No Sort"
			SortMode.PRICE_UP:
				label.text = "Price Asc"
			SortMode.PRICE_DOWN:
				label.text = "Price Desc"
			SortMode.RARITY_UP:
				label.text = "Rarity Asc"
			SortMode.RARITY_DOWN:
				label.text = "Rarity Desc"
			SortMode.NAME_UP:
				label.text = "Name Asc"
			SortMode.NAME_DOWN:
				label.text = "Name Desc"
			SortMode.NUMBER_UP:
				label.text = "Number Asc"
			SortMode.NUMBER_DOWN:
				label.text = "Number Desc"

# Sorting button handlers
func _on_sort_left_pressed():
	var idx = sort_modes.find(sort_mode)
	if idx > 0:
		sort_mode = sort_modes[idx - 1]
	else:
		sort_mode = sort_modes[-1]
	update_sort_label()
	update_card_keys()
	populate_cards()

func _on_sort_right_pressed():
	var idx = sort_modes.find(sort_mode)
	if idx < sort_modes.size() - 1:
		sort_mode = sort_modes[idx + 1]
	else:
		sort_mode = sort_modes[0]
	update_sort_label()
	update_card_keys()
	populate_cards()

# Exact multiplier logic from openbooster.gd
func get_effect_multiplier(effect: String) -> float:
	match effect:
		"Silver":
			return 2.0
		"Gold":
			return 3.0
		"Holo":
			return 4.0
		"Full Art":
			return 5.0
		"Full Silver":
			return 6.0
		"Full Gold":
			return 8.0
		"Full Holo":
			return 10.0
		_:
			return 1.0

func get_card_price(id_set, effect):
	var price = null
	if Global.prices.has(id_set):
		price = Global.prices[id_set]
		print("DEBUG: Found base price for id_set %s: %s" % [str(id_set), str(price)])
	else:
		print("DEBUG: No base price found for id_set %s" % str(id_set))
	if price != null:
		var multiplier = get_effect_multiplier(effect)
		print("DEBUG: Using multiplier for effect %s: %s" % [str(effect), str(multiplier)])
		price *= multiplier
	return price

func update_card_keys():
	card_keys = []
	for id_set in Global.collection.keys():
		var entry = Global.collection[id_set]
		var card_data = Global.cards.get(id_set, null)
		if card_data == null:
			continue
		if current_set != 0 and card_data.get("set", 0) != current_set:
			continue
		# Normal copies
		var amount = entry.get("amount", 0)
		# Count effects
		var effect_count = 0
		if entry.has("effects"):
			for effect in entry["effects"].keys():
				effect_count += entry["effects"][effect]
		var total_owned = amount + effect_count
		var is_duplicate = total_owned > 1
		if showing_duplicates_only and not is_duplicate:
			continue
		# Add normal copies (effect == "")
		if showing_duplicates_only:
			if amount > 1:
				for i in range(amount - 1): # skip first
					card_keys.append({"id_set": id_set, "effect": ""})
		else:
			for i in range(amount):
				card_keys.append({"id_set": id_set, "effect": ""})
		# Add each owned effect (and their count)
		if entry.has("effects"):
			for effect in entry["effects"].keys():
				var effect_amount = entry["effects"][effect]
				if showing_duplicates_only:
					if effect_amount > 1:
						for j in range(effect_amount - 1): # skip first
							card_keys.append({"id_set": id_set, "effect": effect})
				else:
					for j in range(effect_amount):
						card_keys.append({"id_set": id_set, "effect": effect})
	# --- Sorting logic ---
	match sort_mode:
		SortMode.PRICE_UP:
			card_keys.sort_custom(func(a, b):
				return get_card_price(a["id_set"], a["effect"]) < get_card_price(b["id_set"], b["effect"]))
		SortMode.PRICE_DOWN:
			card_keys.sort_custom(func(a, b):
				return get_card_price(a["id_set"], a["effect"]) > get_card_price(b["id_set"], b["effect"]))
		SortMode.RARITY_UP:
			card_keys.sort_custom(func(a, b):
				var r1 = Global.cards.get(a["id_set"], {}).get("rarity", "")
				var r2 = Global.cards.get(b["id_set"], {}).get("rarity", "")
				return rarity_order.get(r1, 99) < rarity_order.get(r2, 99)
			)
		SortMode.RARITY_DOWN:
			card_keys.sort_custom(func(a, b):
				var r1 = Global.cards.get(a["id_set"], {}).get("rarity", "")
				var r2 = Global.cards.get(b["id_set"], {}).get("rarity", "")
				return rarity_order.get(r1, 99) > rarity_order.get(r2, 99)
			)
		SortMode.NAME_UP:
			card_keys.sort_custom(func(a, b):
				var n1 = Global.cards.get(a["id_set"], {}).get("name", "")
				var n2 = Global.cards.get(b["id_set"], {}).get("name", "")
				return n1.to_lower() < n2.to_lower()
			)
		SortMode.NAME_DOWN:
			card_keys.sort_custom(func(a, b):
				var n1 = Global.cards.get(a["id_set"], {}).get("name", "")
				var n2 = Global.cards.get(b["id_set"], {}).get("name", "")
				return n1.to_lower() > n2.to_lower()
			)
		SortMode.NUMBER_UP:
			card_keys.sort_custom(func(a, b):
				var id1 = int(Global.cards.get(a["id_set"], {}).get("id", 0))
				var id2 = int(Global.cards.get(b["id_set"], {}).get("id", 0))
				return id1 < id2
			)
		SortMode.NUMBER_DOWN:
			card_keys.sort_custom(func(a, b):
				var id1 = int(Global.cards.get(a["id_set"], {}).get("id", 0))
				var id2 = int(Global.cards.get(b["id_set"], {}).get("id", 0))
				return id1 > id2
			)
		_:
			pass
	total_pages = int(ceil(float(card_keys.size()) / CARDS_PER_PAGE)) if card_keys.size() > 0 else 1
	current_page = 0

func update_set_label():
	if has_node("Sets/Set"):
		var label = get_node("Sets/Set")
		if current_set == 0:
			label.text = "All Sets"
		else:
			var edition = Global.set_editions.get(current_set, "")
			label.text = "Set #%d%s" % [current_set, " - " + edition if edition != "" else ""]

func populate_cards():
	var start_index = current_page * CARDS_PER_PAGE
	var end_index = min(start_index + CARDS_PER_PAGE, card_keys.size())
	var cards_on_page = end_index - start_index

	for i in range(CARDS_PER_PAGE):
		var card_node = get_node(card_node_paths[i]) if has_node(card_node_paths[i]) else null
		if card_node:
			if i < cards_on_page:
				var card_entry = card_keys[start_index + i]
				var id_set = card_entry["id_set"]
				var effect = card_entry["effect"]
				var card_data = Global.cards.get(id_set, null)
				if card_data:
					card_node.set_effect(effect)
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
					if card_node.has_method("update_card_appearance"):
						card_node.update_card_appearance()
					card_node.visible = true
					# Set the Price label in each card grid slot
					if card_node.has_node("Price"):
						var price = get_card_price(id_set, effect)
						var price_text = "unknown"
						if price != null:
							price_text = "¥%d" % price
						card_node.get_node("Price").text = "%s" % price_text
				else:
					card_node.visible = false
			else:
				card_node.visible = false

func _on_card_button_pressed(card_index):
	var start_index = current_page * CARDS_PER_PAGE
	if card_index >= 0 and (start_index + card_index) < card_keys.size():
		var card_entry = card_keys[start_index + card_index]
		var card_node = get_node(card_node_paths[card_index]) if has_node(card_node_paths[card_index]) else null
		show_full_card(card_entry["id_set"], card_entry["effect"])

func show_full_card(id_set, effect = ""):
	print("DEBUG: show_full_card called for id_set: %s, effect: %s" % [id_set, effect])
	fullcard_id_set = id_set
	fullcard_effect = effect
	var card_data = Global.cards.get(id_set, null)
	# 1. Show and update FullCard popup (if present)
	if card_data and has_node("FullCard"):
		var full_card = get_node("FullCard")
		$VBoxContainer.visible = false
		$Price.visible = true
		full_card.visible = true
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
		# Optionally, you can also show price info in FullCard if you want
		if full_card.has_node("Price"):
			var price = get_card_price(id_set, effect)
			var price_text = "unknown"
			if price != null:
				price_text = "¥%d" % price
			full_card.get_node("Price").text = "%s" % price_text
			print("DEBUG: FullCard price label updated: %s" % price_text)
		# Show and enable the sell button
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = true
	# 2. Update the top-level Price label in the scene
	if card_data and has_node("Price"):
		print("DEBUG: Scene has node 'Price'")
		var price_label = get_node("Price")
		var price = get_card_price(id_set, effect)
		var price_text = "unknown"
		if price != null:
			price_text = "¥%d" % price
		var rarity = card_data.get("rarity", "Unknown")
		var set_num = card_data.get("set", "Unknown")
		var effect_str = "None"
		if effect != "":
			effect_str = effect
		if Global.info == true:
			price_label.text = "Name: %s\nSet: %s\nRarity: %s\nEffect: %s\nPrice: %s" % [
				card_data.get("name", "Unknown"),
				str(set_num),
				rarity,
				effect_str,
				price_text
			]
		else:
			price_label.text = "Set: %s\nRarity: %s\nPrice: %s" % [
				str(set_num),
				rarity,
				price_text
			]
		print("DEBUG: Updated Price label for id_set: %s, effect: %s, price: %s" % [str(id_set), str(effect), price_text])
	elif not has_node("Price"):
		print("ERROR: Scene does NOT have a node named 'Price'!")

func _on_full_card_button_pressed():
	if has_node("FullCard"):
		get_node("FullCard").visible = false
		$VBoxContainer.visible = true
		$Price.visible = false
	if has_node("ButtonSell"):
		get_node("ButtonSell").visible = false

func _on_button_sell_pressed() -> void:
	pending_sell_id_set = fullcard_id_set
	pending_sell_effect = fullcard_effect
	confirm_dialog.dialog_text = "\nAre you sure you want to sell this card?\n"
	confirm_dialog.popup_centered()

func _on_confirm_sell():
	if pending_sell_id_set == null:
		return
	# Sell the card currently shown in FullCard
	if fullcard_id_set == null:
		print("ERROR: No card selected for selling!")
		return
	var id_set = pending_sell_id_set
	var effect = pending_sell_effect
	var entry = Global.collection.get(id_set, null)
	if entry == null:
		print("ERROR: Card not found in collection for selling!")
		return
	var sold = false
	# Remove effect card if effect is not empty
	if effect != "" and entry.has("effects") and entry["effects"].has(effect):
		entry["effects"][effect] -= 1
		if entry["effects"][effect] <= 0:
			entry["effects"].erase(effect)
		sold = true
	# Remove normal card if effect is empty
	elif effect == "" and entry.get("amount", 0) > 0:
		entry["amount"] -= 1
		sold = true
	# If no more cards left, remove from collection
	if entry.get("amount", 0) <= 0 and (not entry.has("effects") or entry["effects"].size() == 0):
		Global.collection.erase(id_set)
	if sold:
		var price = get_card_price(id_set, effect)
		if price != null:
			Global.money += price
			print("DEBUG: Sold card for ¥%d, new money: %s" % [price, str(Global.money)])
		Global.save_data()
		update_card_keys()
		populate_cards()
		# Hide FullCard and ButtonSell after selling
		$VBoxContainer.visible = true
		$Price.visible = false
		if has_node("FullCard"):
			get_node("FullCard").visible = false
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = false
	else:
		print("ERROR: Could not sell card (not owned or already at zero)")
		$VBoxContainer.visible = true
		$Price.visible = false

func _on_button_left_pressed():
	if current_page > 0:
		current_page -= 1
		populate_cards()

func _on_button_right_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		populate_cards()

func _on_button_home_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_set_left_pressed():
	var idx = set_ids.find(current_set)
	if idx > 0:
		current_set = set_ids[idx - 1]
	else:
		current_set = set_ids[-1]  # Wrap around to last
	update_set_label()
	update_card_keys()
	populate_cards()

func _on_set_right_pressed():
	var idx = set_ids.find(current_set)
	if idx < set_ids.size() - 1:
		current_set = set_ids[idx + 1]
	else:
		current_set = set_ids[0]  # Wrap around to first (all)
	update_set_label()
	update_card_keys()
	populate_cards()

func _on_button_dupe_pressed():
	showing_duplicates_only = !showing_duplicates_only
	update_card_keys()
	populate_cards()
	# Update button text
	if has_node("ButtonDupe"):
		var btn = get_node("ButtonDupe")
		if showing_duplicates_only:
			btn.text = "Show All"
		else:
			btn.text = "Duplicates Only"
