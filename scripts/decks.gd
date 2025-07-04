extends Control

enum SortMode {
	NONE, PRICE_UP, PRICE_DOWN, RARITY_UP, RARITY_DOWN, NUMBER_UP, NUMBER_DOWN, GRADE_UP, GRADE_DOWN
}

var sort_modes = [
	SortMode.NONE, SortMode.PRICE_UP, SortMode.PRICE_DOWN, SortMode.RARITY_UP, SortMode.RARITY_DOWN,
	SortMode.NUMBER_UP, SortMode.NUMBER_DOWN,
	SortMode.GRADE_UP, SortMode.GRADE_DOWN
]
var sort_mode: int = SortMode.NUMBER_UP  # Default to number ascending for proper order
var rarity_order = {"D": 0, "C": 1, "B": 2, "A": 3, "S": 4, "X": 5}

var all_card_instances := []  # Flat array of all card instances
var current_set := 0  # 0 = all sets, otherwise set number
var set_ids := []

# To remember which card is being shown in FullCard for selling
var fullcard_id_set: Variant = null
var fullcard_effect: String = ""
var fullcard_card_instance = null

var pending_sell_id_set: Variant = null
var pending_sell_effect: String = ""
var confirm_dialog: ConfirmationDialog = null

var full_card_original_position: Vector2
var full_card_original_scale: Vector2
var full_card_original_rotation: float

var current_fullcard_index: int = -1

enum FilterMode { DUPLICATES, PROTECTED, ALL }
var current_filter_mode = FilterMode.ALL

var filter_grading := [true, true, true, true, true]  # Grading: 6-10
var filter_rarity := [true, true, true, true, true, true]  # Rarity: D, C, B, A, S, X
var filter_effect := [true, true, true, true, true, true, true, true]  # Effects: B, S, G, H, FA, FS, FG, FH

func _ready():
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = tr("Are you sure you want to sell this card?")
	confirm_dialog.get_ok_button().text = tr("Sell")
	confirm_dialog.get_cancel_button().text = tr("Cancel")
	confirm_dialog.connect("confirmed", Callable(self, "_on_confirm_sell"))
	add_child(confirm_dialog)

	Global.load_data()
	$ButtonDupe.text = tr("Dupes")
	set_ids = Global.set_editions.keys()
	set_ids.sort()
	current_set = set_ids[0] if set_ids.size() > 0 else 0

	setup_grid_container()
	update_set_label()
	build_all_card_instances_list()
	populate_cards()
	_unlock()
	connect_buttons()
	update_sort_label()

func setup_grid_container():
	var grid_container = $ScrollContainer/CenterContainer/GridContainer
	if grid_container:
		grid_container.columns = 3  # Set to 3 columns for proper ordering

func connect_buttons():
	if has_node("Sets/SetLeft"):
		get_node("Sets/SetLeft").connect("pressed", Callable(self, "_on_set_left_pressed"))
	if has_node("Sets/SetRight"):
		get_node("Sets/SetRight").connect("pressed", Callable(self, "_on_set_right_pressed"))
	if has_node("Sort/SortLeft"):
		get_node("Sort/SortLeft").connect("pressed", Callable(self, "_on_sort_left_pressed"))
	if has_node("Sort/SortRight"):
		get_node("Sort/SortRight").connect("pressed", Callable(self, "_on_sort_right_pressed"))
	if has_node("FullCard/Button"):
		var btn = get_node("FullCard/Button")
		if not btn.is_connected("pressed", Callable(self, "_on_full_card_button_pressed")):
			btn.connect("pressed", Callable(self, "_on_full_card_button_pressed"))

func build_all_card_instances_list():
	all_card_instances.clear()
	for id_set in Global.collection.keys():
		var entry = Global.collection[id_set]
		var card_data = Global.cards.get(id_set, null)
		if card_data == null:
			continue
		if current_set != 0 and card_data.get("set", 0) != current_set:
			continue
		var cards_array = entry.get("cards", [])
		for i in range(cards_array.size()):
			var card_instance = cards_array[i]
			var grading = card_instance.get("grading", 8)
			var protection = card_instance.get("protection", 0)
			var effect = card_instance.get("effect", "")
			var rarity = card_data.get("rarity", "D")
			if not _passes_filters(grading, rarity, effect):
				continue
			# FilterMode logic
			var add_card = false
			match current_filter_mode:
				FilterMode.DUPLICATES:
					add_card = (cards_array.size() > 1)
				FilterMode.PROTECTED:
					add_card = (protection == 1)
				FilterMode.ALL:
					add_card = true
			if not add_card:
				continue
			all_card_instances.append({
				"id_set": id_set,
				"effect": effect,
				"grading": grading,
				"protection": protection,
				"card_data": card_data,
				"card_instance_index": i
			})
	sort_all_card_instances()

func sort_all_card_instances():
	match sort_mode:
		SortMode.NONE:
			all_card_instances.reverse()
		SortMode.PRICE_UP:
			all_card_instances.sort_custom(Callable(self, "_sort_by_price_asc"))
		SortMode.PRICE_DOWN:
			all_card_instances.sort_custom(Callable(self, "_sort_by_price_desc"))
		SortMode.RARITY_UP:
			all_card_instances.sort_custom(Callable(self, "_sort_by_rarity_asc"))
		SortMode.RARITY_DOWN:
			all_card_instances.sort_custom(Callable(self, "_sort_by_rarity_desc"))
		SortMode.NUMBER_UP:
			all_card_instances.sort_custom(Callable(self, "_sort_by_number_asc"))
		SortMode.NUMBER_DOWN:
			all_card_instances.sort_custom(Callable(self, "_sort_by_number_desc"))
		SortMode.GRADE_UP:
			all_card_instances.sort_custom(Callable(self, "_sort_by_grade_asc"))
		SortMode.GRADE_DOWN:
			all_card_instances.sort_custom(Callable(self, "_sort_by_grade_desc"))

func _sort_by_number_asc(a, b):
	var set_a = a["card_data"].get("set", 0)
	var set_b = b["card_data"].get("set", 0)
	if set_a != set_b:
		return set_a < set_b
	var num_a = a["card_data"].get("id", 0)
	var num_b = b["card_data"].get("id", 0)
	return num_a < num_b

func _sort_by_number_desc(a, b):
	var set_a = a["card_data"].get("set", 0)
	var set_b = b["card_data"].get("set", 0)
	if set_a != set_b:
		return set_a > set_b
	var num_a = a["card_data"].get("id", 0)
	var num_b = b["card_data"].get("id", 0)
	return num_a > num_b

func _sort_by_price_asc(a, b):
	var price_a = _get_full_card_price(a)
	var price_b = _get_full_card_price(b)
	if price_a == price_b:
		return _sort_by_number_asc(a, b)
	return price_a < price_b

func _sort_by_price_desc(a, b):
	var price_a = _get_full_card_price(a)
	var price_b = _get_full_card_price(b)
	if price_a == price_b:
		return _sort_by_number_desc(a, b)
	return price_a > price_b

func _sort_by_rarity_asc(a, b):
	var rarity_a = a["card_data"].get("rarity", "D")
	var rarity_b = b["card_data"].get("rarity", "D")
	var order_a = rarity_order.get(rarity_a, 0)
	var order_b = rarity_order.get(rarity_b, 0)
	if order_a == order_b:
		return _sort_by_number_asc(a, b)
	return order_a < order_b

func _sort_by_rarity_desc(a, b):
	var rarity_a = a["card_data"].get("rarity", "D")
	var rarity_b = b["card_data"].get("rarity", "D")
	var order_a = rarity_order.get(rarity_a, 0)
	var order_b = rarity_order.get(rarity_b, 0)
	if order_a == order_b:
		return _sort_by_number_desc(a, b)
	return order_a > order_b

func _sort_by_grade_asc(a, b):
	var grade_a = a["grading"]
	var grade_b = b["grading"]
	if grade_a == grade_b:
		return _sort_by_number_asc(a, b)
	return grade_a < grade_b

func _sort_by_grade_desc(a, b):
	var grade_a = a["grading"]
	var grade_b = b["grading"]
	if grade_a == grade_b:
		return _sort_by_number_desc(a, b)
	return grade_a > grade_b

func populate_cards():
	var grid_container = $ScrollContainer/CenterContainer/GridContainer
	var card_template = grid_container.get_node("Card1")
	if not card_template:
		print(tr("Card template not found!"))
		return
	for child in grid_container.get_children():
		if child != card_template:
			child.queue_free()
	card_template.visible = false
	var max_cards = min(all_card_instances.size(), 150)
	for i in range(max_cards):
		var card_data_entry = all_card_instances[i]
		var id_set = card_data_entry["id_set"]
		var effect = card_data_entry["effect"]
		var grading = card_data_entry["grading"]
		var protection = card_data_entry["protection"]
		var card_data = card_data_entry["card_data"]
		var card_node = card_template.duplicate()
		card_node.visible = true
		grid_container.add_child(card_node)
		if card_node.has_method("set_effect"):
			card_node.set_effect(effect)
		if card_node.has_method("set_protection"):
			card_node.set_protection(protection)
		if card_node.has_method("set_grading"):
			card_node.set_grading(grading)
		if card_node.has_node("Panel/Info/name"):
			card_node.get_node("Panel/Info/name").text = tr(card_data.get("name", "Unknown")).to_upper()
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
		if card_node.has_node("Price"):
			var price = get_card_price(id_set, effect, grading)
			if price != null:
				card_node.get_node("Price").text = "¥%d" % price
			else:
				card_node.get_node("Price").text = tr("unknown")
		if card_node.has_node("Button"):
			var btn = card_node.get_node("Button")
			btn.connect("pressed", Callable(self, "_on_card_button_pressed").bind(i))
	print(tr("DEBUG: Displayed %d card instances") % max_cards)

func update_card_keys():
	build_all_card_instances_list()

func _passes_filters(grading: int, rarity: String, effect: String) -> bool:
	if grading < 6 or grading > 10 or not filter_grading[grading - 6]:
		return false
	var rarity_index = rarity_order.get(rarity, -1)
	if rarity_index == -1 or not filter_rarity[rarity_index]:
		return false
	var effect_index = _get_effect_index(effect)
	if effect_index == -1 or not filter_effect[effect_index]:
		return false
	return true

func _get_effect_index(effect: String) -> int:
	match effect:
		"": return 0
		"Silver": return 1
		"Gold": return 2
		"Holo": return 3
		"Full Art": return 4
		"Full Silver": return 5
		"Full Gold": return 6
		"Full Holo": return 7
		_: return -1

func _get_full_card_price(card_entry):
	var base_price = Global.prices.get(card_entry["id_set"], 0)
	var protection = card_entry.get("protection", 0)
	if base_price == 0:
		return 0
	var multiplier = Global.get_effect_multiplier(card_entry["effect"])
	var price = base_price * multiplier
	if protection == 2:
		price *= 1.5
	var grading = card_entry.get("grading", 8)
	price *= 0.2 * (1.3 ** (grading - 6))
	price = int(max(1, round(price/2)))
	return price

func get_card_price(id_set, effect, grading = 8):
	var price = Global.prices.get(id_set, null)
	if price == null:
		return null
	var multiplier = Global.get_effect_multiplier(effect)
	price *= multiplier
	price *= 0.2 * (1.3 ** (grading - 6))
	price = int(max(1, round(price/2)))
	return price

func update_sort_label():
	if has_node("Sort/Sort"):
		var label = get_node("Sort/Sort")
		match sort_mode:
			SortMode.NONE:
				label.text = tr("No Sort")
			SortMode.PRICE_UP:
				label.text = tr("Price Asc")
			SortMode.PRICE_DOWN:
				label.text = tr("Price Desc")
			SortMode.RARITY_UP:
				label.text = tr("Rarity Asc")
			SortMode.RARITY_DOWN:
				label.text = tr("Rarity Desc")
			SortMode.NUMBER_UP:
				label.text = tr("Number Asc")
			SortMode.NUMBER_DOWN:
				label.text = tr("Number Desc")
			SortMode.GRADE_UP:
				label.text = tr("Grading Asc")
			SortMode.GRADE_DOWN:
				label.text = tr("Grading Desc")

func update_set_label():
	if has_node("Sets/Set"):
		var label = get_node("Sets/Set")
		var edition = Global.set_editions.get(current_set, "")
		label.text = tr("Set #%d%s") % [current_set, " - " + edition if edition != "" else ""]

func _on_sort_left_pressed():
	var idx = sort_modes.find(sort_mode)
	if idx > 0:
		sort_mode = sort_modes[idx - 1]
	else:
		sort_mode = sort_modes[-1]
	update_sort_label()
	build_all_card_instances_list()
	populate_cards()

func _on_sort_right_pressed():
	var idx = sort_modes.find(sort_mode)
	if idx < sort_modes.size() - 1:
		sort_mode = sort_modes[idx + 1]
	else:
		sort_mode = sort_modes[0]
	update_sort_label()
	build_all_card_instances_list()
	populate_cards()

func _on_card_button_pressed(card_index):
	if card_index >= 0 and card_index < all_card_instances.size():
		var card_entry = all_card_instances[card_index]
		current_fullcard_index = card_index
		show_full_card(card_entry["id_set"], card_entry["effect"], card_entry["card_instance_index"])

func show_full_card(id_set, effect = "", card_instance_index = -1):
	print(tr("DEBUG: show_full_card called for id_set: %s, effect: %s, instance_index: %s") % [id_set, effect, card_instance_index])
	fullcard_id_set = id_set
	fullcard_effect = effect
	fullcard_card_instance = null  # Reset before finding new instance

	var card_data = Global.cards.get(id_set, null)
	if card_data == null:
		print(tr("ERROR: Card data not found for id_set: %s") % id_set)
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
			print(tr("DEBUG: Found card by index %d with grading %d, protection %d") % [card_instance_index, grading, protection])
		# Otherwise find by effect
		else:
			for i in range(cards_array.size()):
				var card_instance = cards_array[i]
				if card_instance.get("effect", "") == effect:
					grading = card_instance.get("grading", 8)
					protection = card_instance.get("protection", 0)
					fullcard_card_instance = card_instance
					print(tr("DEBUG: Found card by effect '%s' with grading %d, protection %d") % [effect, grading, protection])
					break

	# Update the protect button text based on current protection status
	if has_node("ButtonProtect"):
		if protection == 1:
			get_node("ButtonProtect").text = tr("UNPROTECT")
		else:
			if Global.unlock < 9:
				get_node("ButtonProtect").disabled = true
				get_node("ButtonProtect").text = tr("Protect (L)")
			else:
				get_node("ButtonProtect").disabled = false
				get_node("ButtonProtect").text = tr("Protect")

	# 1. Show and update FullCard popup (if present)
	if card_data and has_node("FullCard"):
		var full_card = get_node("FullCard")
		if full_card.has_node("Panel/Info/Overlay"):
			full_card.get_node("Panel/Info/Overlay").visible = true
		full_card.set_effect("")
		$ScrollContainer.visible = false
		$Panel.visible = true
		$Price.visible = true
		full_card.visible = true
		full_card.set_effect(effect)
		$Sets.visible = false
		$Sort.visible = false
		$ButtonDupe.visible = false
		$ButtonFilters.visible = false
		$HBoxContainer.visible = false

		# Set protection status
		if full_card.has_method("set_protection"):
			full_card.set_protection(protection)

		if full_card.has_node("Panel/Info/name"):
			full_card.get_node("Panel/Info/name").text = tr(card_data.get("name", "Unknown")).to_upper()
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
			var price_text = tr("unknown")
			if price != null:
				price_text = "¥%d" % price
			full_card.get_node("Price").text = "%s" % price_text
			print(tr("DEBUG: FullCard price label updated: %s") % price_text)

		# Show and enable the sell button
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = true
		# Show and enable the protect button
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = true
		# Show and enable the sacrifice button
		if has_node("ButtonSacrifice"):
			get_node("ButtonSacrifice").visible = true

	# 2. Update the top-level Price label in the scene
	if card_data and has_node("Price"):
		print(tr("DEBUG: Scene has node 'Price'"))
		var price_label = get_node("Price")
		var price = get_card_price(id_set, effect, grading)
		var price_text = tr("unknown")
		if price != null:
			price_text = "¥%d" % price
		var rarity = card_data.get("rarity", tr("Unknown"))
		var set_num = card_data.get("set", tr("Unknown"))
		var effect_str = tr("None")
		if effect != "":
			effect_str = tr(effect)

		# Display protection status
		var protection_text = tr("No")
		if protection == 1:
			protection_text = tr("Yes")

		if Global.info == true:
			price_label.text = tr("Grading: %s\nSet: %s\nRarity: %s\nEffect: %s\nPrice: %s") % [grading, str(set_num), tr(rarity), effect_str, price_text]
		else:
			price_label.text = tr("Set: %s\nRarity: %s\nPrice: %s") % [str(set_num), tr(rarity), price_text]

func _on_full_card_button_pressed():
	if has_node("FullCard"):
		get_node("FullCard").visible = false
		$Panel.visible = false
		$ScrollContainer.visible = true
		$Price.visible = false
	if has_node("ButtonSell"):
		get_node("ButtonSell").visible = false
	if has_node("ButtonProtect"):
		get_node("ButtonProtect").visible = false
	if has_node("ButtonSacrifice"):
		get_node("ButtonSacrifice").visible = false
	$ButtonDupe.visible = true
	$ButtonFilters.visible = true
	$HBoxContainer.visible = true
	$Sets.visible = true
	$Sort.visible = true

func _on_button_sell_pressed() -> void:
	pending_sell_id_set = fullcard_id_set
	pending_sell_effect = fullcard_effect
	confirm_dialog.dialog_text = "\n" + tr("Are you sure you want to sell this card?") + "\n"
	confirm_dialog.popup_centered()

func _on_confirm_sell():
	if pending_sell_id_set == null:
		return

	var id_set = pending_sell_id_set
	var effect = pending_sell_effect

	if not Global.collection.has(id_set):
		print(tr("ERROR: Card not found in collection for selling!"))
		return

	var entry = Global.collection[id_set]
	var cards_array = entry.get("cards", [])
	var found_card_index = -1

	# Retrieve grading and protection from the full card instance
	var grading = fullcard_card_instance.get("grading", 8) if fullcard_card_instance else 8
	var protection = fullcard_card_instance.get("protection", 0) if fullcard_card_instance else 0

	# Find the specific card with matching effect, grading, and protection
	for i in range(cards_array.size()):
		var card = cards_array[i]
		if card.get("effect", "") == effect and card.get("grading", 8) == grading and card.get("protection", 0) == protection:
			found_card_index = i
			break

	if found_card_index >= 0:
		# Get the price before removing
		var price = get_card_price(id_set, effect, grading)

		# Remove the specific card instance
		cards_array.remove_at(found_card_index)

		# If no more cards left in this entry, remove the entry
		if cards_array.size() == 0:
			Global.collection.erase(id_set)

		# Apply price increase
		if price != null:
			Global.money += price
			print(tr("DEBUG: Sold card for ¥%d, new money: %s") % [price, str(Global.money)])

		Global.save_data()
		update_card_keys()
		populate_cards()

		# Hide FullCard and buttons after selling
		$ScrollContainer.visible = true
		$Panel.visible = false
		$Price.visible = false
		if has_node("FullCard"):
			get_node("FullCard").visible = false
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = false
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = false
		if has_node("ButtonSacrifice"):
			get_node("ButtonSacrifice").visible = false

		$ButtonDupe.visible = true
		$ButtonFilters.visible = true
		$HBoxContainer.visible = true
		$Sets.visible = true
		$Sort.visible = true

	else:

		print(tr("ERROR: Could not find specific card to sell"))
		$VBoxContainer.visible = true
		$Panel.visible = false
		$Price.visible = false
		if has_node("FullCard"):
			get_node("FullCard").visible = false
		if has_node("ButtonSell"):
			get_node("ButtonSell").visible = false
		if has_node("ButtonProtect"):
			get_node("ButtonProtect").visible = false
		if has_node("ButtonSacrifice"):
			get_node("ButtonSacrifice").visible = false

		$ButtonDupe.visible = true
		$ButtonFilters.visible = true
		$HBoxContainer.visible = true
		$Sets.visible = true
		$Sort.visible = true

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
	# Cycle to the next filter mode
	current_filter_mode = (current_filter_mode + 1) % 3

	# Update the button text based on the current mode
	match current_filter_mode:
		FilterMode.ALL:
			$ButtonDupe.text = tr("Duplicates")
		FilterMode.DUPLICATES:
			$ButtonDupe.text = tr("Protected")
		FilterMode.PROTECTED:
			$ButtonDupe.text = tr("All")

	# Refresh the displayed cards
	update_card_keys()
	populate_cards()

func _on_button_protect_pressed() -> void:
	# Ensure we have the current card selected
	if fullcard_id_set == null:
		print(tr("ERROR: No card selected for protection!"))
		return

	# Check if the card is already protected
	var is_protected = false
	if fullcard_card_instance != null:
		is_protected = fullcard_card_instance.get("protection", 0) == 1
	else:
		# Find the card instance by effect if we don't have a direct reference
		var entry = Global.collection.get(fullcard_id_set, {})
		var cards_array = entry.get("cards", [])
		for card in cards_array:
			if card.get("effect", "") == fullcard_effect:
				is_protected = card.get("protection", 0) == 1
				break

	if is_protected:
		# Unprotect the card (with confirmation dialog)
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = tr("Are you sure you want to remove protection from this card?\nThe card will be available for duels again.")
		add_child(dialog)

		dialog.get_ok_button().text = tr("Yes")
		dialog.get_cancel_button().text = tr("No")

		# Make sure we remove any previous connections to avoid duplicates
		if dialog.is_connected("confirmed", Callable(self, "_on_confirm_unprotect_card")):
			dialog.disconnect("confirmed", Callable(self, "_on_confirm_unprotect_card"))

		# Connect the signal to our handler
		dialog.connect("confirmed", Callable(self, "_on_confirm_unprotect_card"))
		dialog.popup_centered()

		# Connect signals to clean up the dialog after it's closed
		if not dialog.is_connected("close_requested", Callable(self, "_cleanup_dialog")):
			dialog.connect("close_requested", Callable(self, "_cleanup_dialog").bind(dialog))
		if not dialog.is_connected("canceled", Callable(self, "_cleanup_dialog")):
			dialog.connect("canceled", Callable(self, "_cleanup_dialog").bind(dialog))
	else:
		# Protect the card (with confirmation dialog and cost)
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = tr("Protecting will cost ¥100.\nWhen you protect a card, it won't be used in duels.\nDo you want to continue?")
		add_child(dialog)

		dialog.get_ok_button().text = tr("Yes")
		dialog.get_cancel_button().text = tr("No")

		# Make sure we remove any previous connections to avoid duplicates
		if dialog.is_connected("confirmed", Callable(self, "_on_confirm_protect_card")):
			dialog.disconnect("confirmed", Callable(self, "_on_confirm_protect_card"))

		# Connect the signal to our handler
		dialog.connect("confirmed", Callable(self, "_on_confirm_protect_card"))
		dialog.popup_centered()

		# Connect signals to clean up the dialog after it's closed
		if not dialog.is_connected("close_requested", Callable(self, "_cleanup_dialog")):
			dialog.connect("close_requested", Callable(self, "_cleanup_dialog").bind(dialog))
		if not dialog.is_connected("canceled", Callable(self, "_cleanup_dialog")):
			dialog.connect("canceled", Callable(self, "_cleanup_dialog").bind(dialog))

func _cleanup_dialog(dialog):
	if is_instance_valid(dialog):
		dialog.queue_free()

func _on_confirm_protect_card() -> void:
	if Global.money < 100:
		var notif = AcceptDialog.new()
		notif.dialog_text = tr("You don't have enough money to protect this card!")
		add_child(notif)
		notif.popup_centered()
		return

	if fullcard_id_set == null or not Global.collection.has(fullcard_id_set):
		print(tr("ERROR: Invalid card selected for protection"))
		return

	Global.money -= 100
	Global.money_spent += 100

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
		notif.dialog_text = tr("This card is now protected!")
		add_child(notif)
		notif.popup_centered()
		# Refresh FullCard with the correct instance index!
		show_full_card(fullcard_id_set, fullcard_effect, protected_index)
	else:
		print(tr("ERROR: Failed to find specific card instance for protection"))

func _on_confirm_unprotect_card() -> void:
	if fullcard_id_set == null or not Global.collection.has(fullcard_id_set):
		print(tr("ERROR: Invalid card selected for unprotection"))
		return

	var entry = Global.collection[fullcard_id_set]
	var cards_array = entry.get("cards", [])
	var card_found = false
	var unprotected_index = -1

	# Try to find by direct reference
	if fullcard_card_instance != null:
		for i in range(cards_array.size()):
			if cards_array[i] == fullcard_card_instance:
				cards_array[i]["protection"] = 0
				card_found = true
				unprotected_index = i
				break

	# Fallback: find by effect
	if not card_found:
		for i in range(cards_array.size()):
			if cards_array[i].get("effect", "") == fullcard_effect:
				cards_array[i]["protection"] = 0
				card_found = true
				unprotected_index = i
				break

	if card_found:
		Global.save_data()
		update_card_keys()
		populate_cards()
		var notif = AcceptDialog.new()
		notif.dialog_text = tr("This card is no longer protected!")
		add_child(notif)
		notif.popup_centered()
		# Refresh FullCard with the correct instance index!
		show_full_card(fullcard_id_set, fullcard_effect, unprotected_index)
	else:
		print(tr("ERROR: Failed to find specific card instance for unprotection"))

func _unlock() -> void:
	if Global.unlock < 8:
		$ButtonSell.disabled = true
		$ButtonSell.text = tr("Sell (L)")
	if Global.unlock < 9:
		$ButtonProtect.disabled = true
		$ButtonProtect.text = tr("Protect (L)")
	if Global.unlock < 10:
		$ButtonSacrifice.disabled = true
		$ButtonSacrifice.text = tr("Sacrifice (L)")

func _on_button_sacrifice_pressed() -> void:
	var full_card = get_node("FullCard")
	full_card_original_position = full_card.position
	full_card_original_scale = full_card.scale
	full_card_original_rotation = full_card.rotation_degrees

	# Check if we have a valid card selected
	if fullcard_id_set == null:
		print(tr("ERROR: No card selected for sacrifice!"))
		return
	if not Global.collection.has(fullcard_id_set):
		print(tr("ERROR: Card not found in collection for sacrifice!"))
		return

	# After removing the card, before saving data
	var rarity = "D"
	if Global.cards.has(fullcard_id_set):
		rarity = Global.cards[fullcard_id_set].get("rarity", "D")

	# Calculate base souls from rarity
	var souls_gained = 1
	match rarity:
		"D": souls_gained = 1
		"C": souls_gained = 2
		"B": souls_gained = 5
		"A": souls_gained = 10
		"S": souls_gained = 15
		"X": souls_gained = 20

	# Remove only the specific card instance
	var entry = Global.collection[fullcard_id_set]
	var cards_array = entry.get("cards", [])
	var found_card_index = -1

	# FIXED: Improved card identification by using the card instance reference or matching multiple attributes
	if fullcard_card_instance != null:
		# Use direct instance reference if available
		for i in range(cards_array.size()):
			if cards_array[i] == fullcard_card_instance:
				found_card_index = i
				break

	# Fallback: match by effect AND grading if we couldn't find by reference
	if found_card_index == -1 and fullcard_card_instance != null:
		var target_effect = fullcard_card_instance.get("effect", "")
		var target_grading = fullcard_card_instance.get("grading", 8)
		var target_protection = fullcard_card_instance.get("protection", 0)

		for i in range(cards_array.size()):
			var card = cards_array[i]
			if card.get("effect", "") == target_effect and \
			   card.get("grading", 8) == target_grading and \
			   card.get("protection", 0) == target_protection:
				found_card_index = i
				break

	# Final fallback: just match by effect (original behavior)
	if found_card_index == -1:
		print(tr("DEBUG: Fallback to matching by effect only"))
		for i in range(cards_array.size()):
			if cards_array[i].get("effect", "") == fullcard_effect:
				found_card_index = i
				break

	# Get the effect for souls calculation from the actual found card
	var effect = ""
	if found_card_index != -1:
		effect = cards_array[found_card_index].get("effect", "")
	else:
		print(tr("ERROR: Could not find specific card to sacrifice!"))
		return

	# Calculate additional souls from effect
	match effect:
		"Silver": souls_gained += 1
		"Gold": souls_gained += 2
		"Holo": souls_gained += 3
		"Full Art": souls_gained += 5
		"Full Silver": souls_gained += 7
		"Full Gold": souls_gained += 8
		"Full Holo": souls_gained += 10

	# Add souls and remove the card
	Global.souls += souls_gained
	print(tr("DEBUG: Sacrificed card at index %s with effect %s - Souls gained: %s") % [str(found_card_index), effect, str(souls_gained)])

	# Remove the card from collection
	cards_array.remove_at(found_card_index)
	if cards_array.size() == 0:
		Global.collection.erase(fullcard_id_set)

	# Save and update
	Global.save_data()
	update_card_keys()
	populate_cards()

	# Animation
	var target_y = -full_card.size.y
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(full_card, "position:y", target_y, 1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(full_card, "rotation_degrees", 720, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(full_card, "scale", Vector2(0.1, 0.1), 1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_full_card_animation_finished.bind(full_card))

func _on_full_card_animation_finished(full_card):
	full_card.position = full_card_original_position
	full_card.scale = full_card_original_scale
	full_card.rotation_degrees = full_card_original_rotation
	full_card.visible = false
	_on_full_card_button_pressed()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_button_home_pressed()

func _on_close_filters_pressed():
	# Update filter settings based on checkboxes
	var filter_container = $Filters/VBoxContainer

	# Update grading filter
	var grading_hbox = filter_container.get_node("HBoxContainer")
	for i in range(5):  # Grading: 6 to 10
		filter_grading[i] = grading_hbox.get_child(i * 2).button_pressed  # CheckBox states

	# Update rarity filter
	var rarity_hbox = filter_container.get_node("HBoxContainer2")
	for i in range(6):  # Rarity: D, C, B, A, S, X
		filter_rarity[i] = rarity_hbox.get_child(i * 2).button_pressed  # CheckBox states

	# Update type (effect) filter
	var effect_hbox = filter_container.get_node("HBoxContainer3")
	for i in range(8):  # Effects: B, S, G, H, FA, FS, FG, FH
		filter_effect[i] = effect_hbox.get_child(i * 2).button_pressed  # CheckBox states

	# Apply filters and refresh cards
	update_card_keys()
	populate_cards()
	$Filters.visible = false

func _on_button_filters_pressed() -> void:
	$Filters.visible = true

func _on_full_view_pressed() -> void:
	var info_panel = $FullCard/Panel/Info
	var effect_overlay = $FullCard/Panel/Info/Overlay
	var picture = $FullCard/Panel/Picture

	# Check if the card is "Full Art"
	var is_full_art = (fullcard_effect == "Full Art")

	if info_panel.visible:
		# Hide info panel and effect overlay
		info_panel.visible = false
		effect_overlay.visible = false

		# Store original position of the picture if not already stored
		if not picture.has_meta("original_position"):
			picture.set_meta("original_position", picture.position)

		# Set picture position Y to 0
		picture.position.y = 0
	else:
		# Show info panel
		info_panel.visible = true

		# Show effect overlay only if the card is not "Full Art"
		effect_overlay.visible = not is_full_art

		# Restore original position of the picture if it was stored
		if picture.has_meta("original_position"):
			picture.position = picture.get_meta("original_position")
