extends Control

const CARDS_PER_PAGE = 12
const FILTER_ALL = "ALL"  # Special value for showing all effects

const EFFECT_TYPES = [
	"", "Full Art", "Gold", "Silver", "Holo", "Full Silver", "Full Gold", "Full Holo"
]

const FULL_CARD_EFFECTS = [
	"", "Silver", "Gold", "Holo", "Full Art", "Full Silver", "Full Gold", "Full Holo"
]

# Effect abbreviations mapping
const EFFECT_ABBR = {
	"": "B",
	"Silver": "S",
	"Gold": "G",
	"Holo": "H",
	"Full Art": "FA",
	"Full Silver": "FS",
	"Full Gold": "FG",
	"Full Holo": "FH"
}

var current_set_id: int = 1
var current_page: int = 0
var total_pages: int = 0
var cards_in_set: Array = []
var current_fullcard_index: int = -1
var current_filter: String = "ALL"  # Track the current effect filter

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

	_cards_in_collection()

func load_set(set_id: int):
	cards_in_set = Global.cards.values().filter(func(card):
		return card["set"] == set_id
	)
	cards_in_set.sort_custom(Callable(self, "_sort_by_id"))
	total_pages = ceil(float(cards_in_set.size()) / CARDS_PER_PAGE)
	current_page = 0
	var set_folder = "res://cards/" + str(set_id)
	var image_path = set_folder + "/1.jpg"
	if ResourceLoader.exists(image_path):
		$Booster.texture = load(image_path)
	else:
		print("Error: Booster pack image not found for set", set_id)
	$BoosterTemplate/set.text = "Set #" + str(set_id)
	update_page()

func update_booster_pack_image(set_id: int):
	var set_folder = "res://cards/" + str(set_id)
	var image_path = set_folder + "/1.jpg"
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
				# Basic card info updates...
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

					# Determine if the card is owned with the current filter effect
					var owned
					if current_filter == FILTER_ALL:  # Special "All" case
						owned = is_any_effect_owned_for_card(id_set)
					else:  # Specific effect (including Basic "")
						owned = is_effect_owned_for_card(id_set, current_filter)

					# Apply the visual effect based on filter and ownership
					if card_node.has_method("set_effect"):
						if owned:
							if current_filter == FILTER_ALL:
								card_node.set_effect("")  # Default to basic effect for "All" view
							else:
								card_node.set_effect(current_filter)
						else:
							# Remove shader effect for unowned cards
							card_node.set_effect("")
							if current_filter in ["Full Art", "Full Silver", "Full Gold", "Full Holo"]:
								card_node.set_effect("Full Art")

					# Set the card's brightness based on ownership

					card_node.get_node("Panel/Picture").modulate = Color(1, 1, 1) if owned else Color(0.2, 0.2, 0.2)


				# Update the Effects text for this card
				var id_set = card_data.get("id_set", card_data.get("id", ""))
				update_effects_text(card_node, id_set)  # Show all owned effects

				if card_node.has_method("update_card_appearance"):
					card_node.update_card_appearance()
				card_node.visible = true
			else:
				card_node.visible = false

	# Update collection count based on current filter
	if current_filter == FILTER_ALL:
		_cards_in_collection()  # Show count for all effects
	else:
		_cards_in_collection_by_effect(current_filter)  # Show count for specific effect

# New function to update the effects text
func update_effects_text(card_node, id_set):
	if card_node.has_node("Effects"):
		var effects_text = ""
		var effects_owned = []

		# Check which effects are owned for this card
		for effect in FULL_CARD_EFFECTS:
			if is_effect_owned_for_card(id_set, effect):
				effects_owned.append(EFFECT_ABBR[effect])

		# Join with dash separator
		effects_text = "-".join(effects_owned)

		# Update the Effects text node
		card_node.get_node("Effects").text = effects_text

# Updates the effects text to show only a specific effect (if owned)
func update_specific_effect_text(card_node, id_set, effect_type):
	if card_node.has_node("Effects"):
		var effects_text = ""

		# Check if this specific effect is owned
		if is_effect_owned_for_card(id_set, effect_type):
			effects_text = EFFECT_ABBR[effect_type]

		# Update the Effects text node
		card_node.get_node("Effects").text = effects_text

func is_any_effect_owned_for_card(id_set):
	if not Global.collection.has(id_set):
		return false
	if not Global.collection[id_set].has("cards"):
		return false
	return Global.collection[id_set]["cards"].size() > 0

func get_card_path(index: int) -> String:
	if index < 4:
		return "VBoxContainer/HBoxContainer/Card%d" % (index + 1)
	elif index < 8:
		return "VBoxContainer/HBoxContainer2/Card%d" % (index - 3)
	else:
		return "VBoxContainer/HBoxContainer3/Card%d" % (index - 7)

func get_full_card_path(index: int) -> String:
	if index < 4:
		return "FullCards/HBoxContainer/Card%d" % (index + 1)
	else:
		return "FullCards/HBoxContainer2/Card%d" % (index - 4 +5)

func is_effect_owned_for_card(id_set, effect):
	if not Global.collection.has(id_set):
		return false
	if not Global.collection[id_set].has("cards"):
		return false
	for card_instance in Global.collection[id_set]["cards"]:
		if card_instance.get("effect", "") == effect:
			return true
	return false

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
				# Set protection from the first matching card instance
				if full_card.has_method("set_protection"):
					var protection = 0
					if Global.collection.has(id_set) and Global.collection[id_set].has("cards"):
						for card_instance in Global.collection[id_set]["cards"]:
							if card_instance.get("effect", "") == effect:
								protection = card_instance.get("protection", 0)
								break
					else:
						protection = card_data.get("protection", 0)
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
	$Effects.visible = false

func _on_hide_full_pressed():
	$Effects.visible = true
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

func _cards_in_collection() -> void:
	var owned_id_sets := {}
	for key in Global.collection.keys():
		# key is like "24_1", "15_1", etc.
		if key.ends_with("_" + str(current_set_id)):
			owned_id_sets[key] = true
	var x = owned_id_sets.size()
	var y = 0
	for card in Global.cards.values():
		if card.get("set", 0) == int(current_set_id):
			y += 1
	$Collection.text = "Cards: %d/%d" % [x, y]

# Counts cards in collection with a specific effect
func _cards_in_collection_by_effect(effect_type: String) -> void:
	var owned_count := 0
	var total_count := 0

	# Count the cards with this effect in the current set
	for card in Global.cards.values():
		if card.get("set", 0) == current_set_id:
			total_count += 1

			# Check if we own this card with this effect
			var id_set = card.get("id_set", card.get("id", ""))
			if is_effect_owned_for_card(id_set, effect_type):
				owned_count += 1

	$Collection.text = "Cards: %d/%d (%s)" % [owned_count, total_count, EFFECT_ABBR[effect_type]]

func _unhandled_input(event):
	if event.is_action_pressed("ui_left"):
		_on_button_left_pressed()
		# Optionally, accept the event to prevent further propagation:
		# get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_button_right_pressed()
		# get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_button_home_pressed()

func _filter_by_effect(effect_type: String) -> void:
	current_filter = effect_type  # Set the current filter
	update_page()  # Update the page with the new filter applied

func _on_ef_all_pressed() -> void:
	current_filter = FILTER_ALL  # Use special value for "All" filter
	update_page()

func _on_ef_b_pressed() -> void:
	_filter_by_effect("")  # Filter to show only Basic effect

func _on_ef_s_pressed() -> void:
	_filter_by_effect("Silver")  # Filter to show only Silver effect

func _on_ef_g_pressed() -> void:
	_filter_by_effect("Gold")  # Filter to show only Gold effect

func _on_ef_h_pressed() -> void:
	_filter_by_effect("Holo")  # Filter to show only Holo effect

func _on_ef_fa_pressed() -> void:
	_filter_by_effect("Full Art")  # Filter to show only Full Art effect

func _on_ef_fs_pressed() -> void:
	_filter_by_effect("Full Silver")  # Filter to show only Full Silver effect

func _on_ef_fg_pressed() -> void:
	_filter_by_effect("Full Gold")  # Filter to show only Full Gold effect

func _on_ef_fh_pressed() -> void:
	_filter_by_effect("Full Holo")  # Filter to show only Full Holo effect
