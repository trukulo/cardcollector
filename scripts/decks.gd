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
var fullcard_card_instance = null  # Added to store reference to the specific card instance

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
		if not btn.is_connected("pressed", Callable(self, "_on_button_sell_pressed")):
			btn.connect("pressed", Callable(self, "_on_button_sell_pressed"))
		btn.visible = false
	# Connect protect button
	if has_node("ButtonProtect"):
		var btn = get_node("ButtonProtect")
		if not btn.is_connected("pressed", Callable(self, "_on_button_protect_pressed")):
			btn.connect("pressed", Callable(self, "_on_button_protect_pressed"))
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

# Sorting implementation
func sort_card_keys():
	match sort_mode:
		SortMode.PRICE_UP:
			card_keys.sort_custom(Callable(self, "_sort_by_price_asc"))
		SortMode.PRICE_DOWN:
			card_keys.sort_custom(Callable(self, "_sort_by_price_desc"))
		SortMode.RARITY_UP:
			card_keys.sort_custom(Callable(self, "_sort_by_rarity_asc"))
		SortMode.RARITY_DOWN:
			card_keys.sort_custom(Callable(self, "_sort_by_rarity_desc"))
		SortMode.NAME_UP:
			card_keys.sort_custom(Callable(self, "_sort_by_name_asc"))
		SortMode.NAME_DOWN:
			card_keys.sort_custom(Callable(self, "_sort_by_name_desc"))
		SortMode.NUMBER_UP:
			card_keys.sort_custom(Callable(self, "_sort_by_number_asc"))
		SortMode.NUMBER_DOWN:
			card_keys.sort_custom(Callable(self, "_sort_by_number_desc"))

# Sorting comparison functions
func _sort_by_price_asc(a, b):
	var price_a = _get_full_card_price(a)
	var price_b = _get_full_card_price(b)
	if price_a < price_b:
		return true
	return false

func _sort_by_price_desc(a, b):
	var price_a = _get_full_card_price(a)
	var price_b = _get_full_card_price(b)
	if price_a > price_b:
		return true
	return false

func _sort_by_rarity_asc(a, b):
	var rarity_a = a["card_data"].get("rarity", "D")
	var rarity_b = b["card_data"].get("rarity", "D")
	var order_a = rarity_order.get(rarity_a, 0)
	var order_b = rarity_order.get(rarity_b, 0)
	if order_a < order_b:
		return true
	return false

func _sort_by_rarity_desc(a, b):
	var rarity_a = a["card_data"].get("rarity", "D")
	var rarity_b = b["card_data"].get("rarity", "D")
	var order_a = rarity_order.get(rarity_a, 0)
	var order_b = rarity_order.get(rarity_b, 0)
	if order_a > order_b:
		return true
	return false

func _sort_by_name_asc(a, b):
	var name_a = a["card_data"].get("name", "").to_lower()
	var name_b = b["card_data"].get("name", "").to_lower()
	if name_a < name_b:
		return true
	return false

func _sort_by_name_desc(a, b):
	var name_a = a["card_data"].get("name", "").to_lower()
	var name_b = b["card_data"].get("name", "").to_lower()
	if name_a > name_b:
		return true
	return false

func _sort_by_number_asc(a, b):
	var num_a = a["card_data"].get("id", 0)
	var num_b = b["card_data"].get("id", 0)
	if num_a < num_b:
		return true
	return false

func _sort_by_number_desc(a, b):
	var num_a = a["card_data"].get("id", 0)
	var num_b = b["card_data"].get("id", 0)
	if num_a > num_b:
		return true
	return false

# Helper function to calculate the full price with all modifiers
func _get_full_card_price(card_entry):
	var base_price = Global.prices.get(card_entry["id_set"], 0)
	if base_price == 0:
		return 0

	# Apply effect multiplier
	var multiplier = Global.get_effect_multiplier(card_entry["effect"])
	var price = base_price * multiplier

	# Apply grading modifier
	var grading = card_entry.get("grading", 8)
	price *= 0.2 * (2.7 ** (grading - 6))  # Grading formula

	# Final adjustment and rounding
	price = int(max(1, round(price/2)))
	return price

# Update the get_card_price function to match (for display purposes)
func get_card_price(id_set, effect, grading = 8):
	var price = Global.prices.get(id_set, null)
	if price == null:
		return null

	# Apply effect multiplier
	var multiplier = Global.get_effect_multiplier(effect)
	price *= multiplier

	# Apply grading modifier
	price *= 0.2 * (2.7 ** (grading - 6))  # Same grading formula

	# Final adjustment and rounding
	price = int(max(1, round(price/2)))
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

		var cards_array = entry.get("cards", [])
		var total_owned = cards_array.size()
		var is_duplicate = total_owned > 1

		# Only show cards with more than one instance in duplicates-only mode
		if showing_duplicates_only:
			if not is_duplicate:
				continue
			# Add ALL instances of duplicated cards
			for i in range(cards_array.size()):
				var card_instance = cards_array[i]
				var protection = 0
				if card_instance.has("protection"):
					protection = card_instance["protection"]
				elif entry.has("protection"):
					protection = entry["protection"]
				elif card_data.has("protection"):
					protection = card_data["protection"]
				else:
					protection = 0

				card_keys.append({
					"id_set": id_set,
					"effect": card_instance.get("effect", ""),
					"grading": card_instance.get("grading", 8),
					"protection": protection,
					"card_data": card_data,
					"card_instance_index": i
				})
		else:
			# Show all cards (regardless of duplicates)
			for i in range(cards_array.size()):
				var card_instance = cards_array[i]
				var protection = 0
				if card_instance.has("protection"):
					protection = card_instance["protection"]
				elif entry.has("protection"):
					protection = entry["protection"]
				elif card_data.has("protection"):
					protection = card_data["protection"]
				else:
					protection = 0

				card_keys.append({
					"id_set": id_set,
					"effect": card_instance.get("effect", ""),
					"grading": card_instance.get("grading", 8),
					"protection": protection,
					"card_data": card_data,
					"card_instance_index": i
				})

	# Apply sorting after building the array
	if sort_mode != SortMode.NONE:
		sort_card_keys()

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
				var grading = card_entry["grading"]
				var protection = card_entry["protection"]
				var card_data = card_entry["card_data"]  # This should be already included in your card_entry

				if card_data:
					# Set the card's specific properties
					card_node.set_effect(effect)
					card_node.set_protection(protection)

					# Implement a method to set grading if it doesn't exist
					if card_node.has_method("set_grading"):
						card_node.set_grading(grading)

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
						var price = get_card_price(id_set, effect, grading)
						var price_text = "unknown"
						if price != null:
							price_text = "¥%d" % price
						card_node.get_node("Price").text = "%s" % price_text

					# Optionally, display grading information on each card
					if card_node.has_node("Grading"):
						card_node.get_node("Grading").text = "Grade: %d" % grading
				else:
					card_node.visible = false
			else:
				card_node.visible = false

func _on_card_button_pressed(card_index):
	var start_index = current_page * CARDS_PER_PAGE
	if card_index >= 0 and (start_index + card_index) < card_keys.size():
		var card_entry = card_keys[start_index + card_index]
		var card_node = get_node(card_node_paths[card_index]) if has_node(card_node_paths[card_index]) else null
		show_full_card(card_entry["id_set"], card_entry["effect"], card_entry["card_instance_index"])

func show_full_card(id_set, effect = "", card_instance_index = -1):
	print("DEBUG: show_full_card called for id_set: %s, effect: %s, instance_index: %s" % [id_set, effect, card_instance_index])
	fullcard_id_set = id_set
	fullcard_effect = effect
	fullcard_card_instance = null  # Reset before finding new instance

	var card_data = Global.cards.get(id_set, null)
	if card_data == null:
		print("ERROR: Card data not found for id_set: %s" % id_set)
		return

	# Initialize with default grading and protection
	var grading = 8
	var protection = 0

	# Find the specific card instance
	if Global.collection.has(id_set):
		var cards_array = Global.collection[id_set].get("cards", [])

		# If we have a specific index, use it
		if card_instance_index >= 0 and card_instance_index < cards_array.size():
			var card_instance = cards_array[card_instance_index]
			grading = card_instance.get("grading", 8)
			protection = card_instance.get("protection", 0)
			fullcard_card_instance = card_instance
			print("DEBUG: Found card by index %d with grading %d, protection %d" % [card_instance_index, grading, protection])
		# Otherwise find by effect
		else:
			for i in range(cards_array.size()):
				var card_instance = cards_array[i]
				if card_instance.get("effect", "") == effect:
					grading = card_instance.get("grading", 8)
					protection = card_instance.get("protection", 0)
					fullcard_card_instance = card_instance
					print("DEBUG: Found card by effect '%s' with grading %d, protection %d" % [effect, grading, protection])
					break

	# 1. Show and update FullCard popup (if present)
	if card_data and has_node("FullCard"):
		var full_card = get_node("FullCard")
		full_card.get_node("Panel/Info/Overlay").visible = true
		full_card.set_effect("")
		$VBoxContainer.visible = false
		$Price.visible = true
		full_card.visible = true
		full_card.set_effect(effect)

		# Set protection status
		if full_card.has_method("set_protection"):
			full_card.set_protection(protection)

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

		# Show price info in FullCard
		if full_card.has_node("Price"):
			var price = get_card_price(id_set, effect, grading)
			var price_text = "unknown"
			if price != null:
				price_text = "¥%d" % price
			full_card.get_node("Price").text = "%s" % price_text
			print("DEBUG: FullCard price label updated: %s" % price_text)

		# Show and enable the sell button
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = true
			get_node("ButtonSell").disabled = false
		# Show and enable the protect button
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = true
			# Disable protect button if already protected
			get_node("ButtonProtect").disabled = (protection == 1)

	# 2. Update the top-level Price label in the scene
	if card_data and has_node("Price"):
		print("DEBUG: Scene has node 'Price'")
		var price_label = get_node("Price")
		var price = get_card_price(id_set, effect, grading)
		var price_text = "unknown"
		if price != null:
			price_text = "¥%d" % price
		var rarity = card_data.get("rarity", "Unknown")
		var set_num = card_data.get("set", "Unknown")
		var effect_str = "None"
		if effect != "":
			effect_str = effect

		# Display protection status
		var protection_text = "No"
		if protection == 1:
			protection_text = "Yes"

		if Global.info == true:
			price_label.text = "Grading: %s\nSet: %s\nRarity: %s\nEffect: %s\nPrice: %s" % [
				grading,
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

func _on_full_card_button_pressed():
	if has_node("FullCard"):
		get_node("FullCard").visible = false
		$VBoxContainer.visible = true
		$Price.visible = false
	if has_node("ButtonSell"):
		get_node("ButtonSell").visible = false
		get_node("ButtonSell").disabled = true
	if has_node("ButtonProtect"):
		get_node("ButtonProtect").visible = false
		get_node("ButtonProtect").disabled = true

func _on_button_sell_pressed() -> void:
	pending_sell_id_set = fullcard_id_set
	pending_sell_effect = fullcard_effect
	confirm_dialog.dialog_text = "\nAre you sure you want to sell this card?\n"
	confirm_dialog.popup_centered()

func _on_confirm_sell():
	if pending_sell_id_set == null:
		return

	var id_set = pending_sell_id_set
	var effect = pending_sell_effect

	if not Global.collection.has(id_set):
		print("ERROR: Card not found in collection for selling!")
		return

	var entry = Global.collection[id_set]
	var cards_array = entry.get("cards", [])
	var found_card_index = -1

	# Find the specific card with matching effect
	for i in range(cards_array.size()):
		if cards_array[i].get("effect", "") == effect:
			found_card_index = i
			break

	if found_card_index >= 0:
		# Get the price before removing
		var price = get_card_price(id_set, effect, cards_array[found_card_index].get("grading", 8))

		# Remove the specific card instance
		cards_array.remove_at(found_card_index)

		# If no more cards left in this entry, remove the entry
		if cards_array.size() == 0:
			Global.collection.erase(id_set)

		# Apply price increase
		if price != null:
			Global.money += price
			print("DEBUG: Sold card for ¥%d, new money: %s" % [price, str(Global.money)])

		Global.save_data()
		update_card_keys()
		populate_cards()

		# Hide FullCard and buttons after selling
		$VBoxContainer.visible = true
		$Price.visible = false
		if has_node("FullCard"):
			get_node("FullCard").visible = false
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = false
			get_node("ButtonSell").disabled = true
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = false
			get_node("ButtonProtect").disabled = true
	else:
		print("ERROR: Could not find specific card to sell")
		$VBoxContainer.visible = true
		$Price.visible = false
		if has_node("FullCard"):
			get_node("FullCard").visible = false
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = false
			get_node("ButtonSell").disabled = true
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = false
			get_node("ButtonProtect").disabled = true

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

func _on_button_protect_pressed() -> void:
	# Ensure we have the current card selected
	if fullcard_id_set == null:
		print("ERROR: No card selected for protection!")
		return

	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Protecting will cost ¥100.\nWhen you protect a card, it won't be used in duels.\nDo you want to continue?"
	add_child(dialog)

	dialog.get_ok_button().text = "Yes"
	dialog.get_cancel_button().text = "No"

	dialog.popup_centered()
	dialog.connect("confirmed", Callable(self, "_on_confirm_protect_card"))

func _on_confirm_protect_card() -> void:
	if Global.money < 100:
		var notif = AcceptDialog.new()
		notif.dialog_text = "You don't have enough money to protect this card!"
		add_child(notif)
		notif.popup_centered()
		return

	if fullcard_id_set == null or not Global.collection.has(fullcard_id_set):
		print("ERROR: Invalid card selected for protection")
		return

	Global.money -= 100

	var entry = Global.collection[fullcard_id_set]
	var cards_array = entry.get("cards", [])
	var card_found = false
	var protected_index = -1

	# Try to find by direct reference
	if fullcard_card_instance != null:
		for i in range(cards_array.size()):
			if cards_array[i] == fullcard_card_instance:
				cards_array[i]["protection"] = 1
				card_found = true
				protected_index = i
				break

	# Fallback: find by effect
	if not card_found:
		for i in range(cards_array.size()):
			if cards_array[i].get("effect", "") == fullcard_effect:
				cards_array[i]["protection"] = 1
				card_found = true
				protected_index = i
				break

	if card_found:
		Global.save_data()
		update_card_keys()
		populate_cards()
		var notif = AcceptDialog.new()
		notif.dialog_text = "This card is now protected!"
		add_child(notif)
		notif.popup_centered()
		# Refresh FullCard with the correct instance index!
		show_full_card(fullcard_id_set, fullcard_effect, protected_index)
	else:
		print("ERROR: Failed to find specific card instance for protection")
