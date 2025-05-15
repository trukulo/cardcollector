extends Control

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

const FILTER_ALL = "ALL"  # Special value for showing all effects

var current_set_id: int = 1
var current_fullcard_index: int = -1
var current_filter: String = "ALL"  # Track the current effect filter
var cards_in_set: Array = []
var card_template = null

func _ready():
	Global.load_data()

	# Get the card template - this should be a Card node that's already in your scene
	card_template = $ScrollContainer/CenterContainer/GridContainer/Card1
	if not card_template:
		print("Card template not found!")
		return
	card_template.visible = false  # Hide the template

	# Connect UI buttons - with null checks
	if has_node("SetControls/SetLeft"):
		$SetControls/SetLeft.connect("pressed", Callable(self, "_on_set_left_pressed"))
	if has_node("SetControls/SetRight"):
		$SetControls/SetRight.connect("pressed", Callable(self, "_on_set_right_pressed"))

	# Connect effect filter buttons - with null checks
	if has_node("Effects/EfAll"):
		$Effects/EfAll.connect("pressed", Callable(self, "_on_ef_all_pressed"))
	if has_node("Effects/EfB"):
		$Effects/EfB.connect("pressed", Callable(self, "_on_ef_b_pressed"))
	if has_node("Effects/EfS"):
		$Effects/EfS.connect("pressed", Callable(self, "_on_ef_s_pressed"))
	if has_node("Effects/EfG"):
		$Effects/EfG.connect("pressed", Callable(self, "_on_ef_g_pressed"))
	if has_node("Effects/EfH"):
		$Effects/EfH.connect("pressed", Callable(self, "_on_ef_h_pressed"))
	if has_node("Effects2/EfFA"):
		$Effects2/EfFA.connect("pressed", Callable(self, "_on_ef_fa_pressed"))
	if has_node("Effects2/EfFS"):
		$Effects2/EfFS.connect("pressed", Callable(self, "_on_ef_fs_pressed"))
	if has_node("Effects2/EfFG"):
		$Effects2/EfFG.connect("pressed", Callable(self, "_on_ef_fg_pressed"))
	if has_node("Effects2/EfFH"):
		$Effects2/EfFH.connect("pressed", Callable(self, "_on_ef_fh_pressed"))

	# Connect HideFull button to close the popup
	if has_node("HideFull"):
		$HideFull.connect("pressed", Callable(self, "_on_hide_full_pressed"))

	# Connect home button
	if has_node("HBoxContainer/ButtonHome"):
		$HBoxContainer/ButtonHome.connect("pressed", Callable(self, "_on_button_home_pressed"))

	if Global.info == false:
		if has_node("BoosterTemplate"):
			$BoosterTemplate.visible = false
		if has_node("FullCards"):
			$FullCards.scale = Vector2(0.90, 0.90)

	# Load the initial set
	load_set(current_set_id)

func load_set(set_id: int):
	# Filter cards for the specified set
	cards_in_set = Global.cards.values().filter(func(card):
		return card["set"] == set_id
	)

	# Sort cards by ID
	cards_in_set.sort_custom(Callable(self, "_sort_by_id"))

	# Update set display elements
	current_set_id = set_id
	var set_folder = "res://cards/" + str(set_id)
	var booster_image_path = set_folder + "/1.jpg"
	if ResourceLoader.exists(booster_image_path):
		$Booster.texture = load(booster_image_path)
	else:
		print("Error: Booster pack image not found for set", set_id)

	$BoosterTemplate/set.text = "Set #" + str(set_id)

	# Clear existing cards in the GridContainer (except the template)
	var grid_container = $ScrollContainer/CenterContainer/GridContainer
	for child in grid_container.get_children():
		if child != card_template:
			child.queue_free()

	# Add cards to the grid
	for card_data in cards_in_set:
		# Duplicate the template
		var card_node = card_template.duplicate()
		card_node.visible = true
		grid_container.add_child(card_node)

		# Populate card details
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

		# Load the card image
		if card_node.has_node("Panel/Picture"):
			var image_path = card_data.get("image", "")
			if ResourceLoader.exists(image_path):
				card_node.get_node("Panel/Picture").texture = load(image_path)
			else:
				card_node.get_node("Panel/Picture").texture = null
				print("Warning: Image not found:", image_path)

		# Get the card ID set
		var id_set = card_data.get("id_set", card_data.get("id", ""))

		# Setup the card based on current filter
		apply_card_filter(card_node, id_set)

		# Update effects text display for this card
		update_effects_text(card_node, id_set)

		# Connect the card button to show the FullCard view
		var button = card_node.get_node("Button")
		if button:
			if button.is_connected("pressed", Callable(self, "_on_card_button_pressed")):
				button.disconnect("pressed", Callable(self, "_on_card_button_pressed"))
			button.connect("pressed", Callable(self, "_on_card_button_pressed").bind(cards_in_set.find(card_data)))

	# Update collection count display
	update_collection_count()

# Apply the current filter to a card
func apply_card_filter(card_node, id_set):
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
	if card_node.has_node("Panel/Picture"):
		card_node.get_node("Panel/Picture").modulate = Color(1, 1, 1) if owned else Color(0.2, 0.2, 0.2)

	# Update the card appearance if it has that method
	if card_node.has_method("update_card_appearance"):
		card_node.update_card_appearance()

# Update the effects text display
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

# Check if any effect is owned for this card
func is_any_effect_owned_for_card(id_set):
	if not Global.collection.has(id_set):
		return false
	if not Global.collection[id_set].has("cards"):
		return false
	return Global.collection[id_set]["cards"].size() > 0

# Check if a specific effect is owned for this card
func is_effect_owned_for_card(id_set, effect):
	if not Global.collection.has(id_set):
		return false
	if not Global.collection[id_set].has("cards"):
		return false
	for card_instance in Global.collection[id_set]["cards"]:
		if card_instance.get("effect", "") == effect:
			return true
	return false

# Show the full card view when a card is clicked
func _on_card_button_pressed(card_index):
	if card_index < 0 or card_index >= cards_in_set.size():
		return

	var card_data = cards_in_set[card_index]
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

				# Update card details
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

				# Load card image
				if full_card.has_node("Panel/Picture"):
					var image_path = card_data.get("image", "")
					if ResourceLoader.exists(image_path):
						full_card.get_node("Panel/Picture").texture = load(image_path)
					else:
						full_card.get_node("Panel/Picture").texture = null

				if full_card.has_method("update_card_appearance"):
					full_card.update_card_appearance()

	# Show FullCards and HideFull buttons
	$FullCards.visible = true
	$ScrollContainer.visible = false
	$HideFull.visible = true
	$Effects.visible = false
	$Effects2.visible = false  # Hide the second Effects container too

# Get the path to a full card by index
func get_full_card_path(index: int) -> String:
	if index < 4:
		return "FullCards/HBoxContainer/Card%d" % (index + 1)
	else:
		return "FullCards/HBoxContainer2/Card%d" % (index - 4 + 5)

# Hide the full card view
func _on_hide_full_pressed():
	$Effects.visible = true
	$Effects2.visible = true  # Show the second Effects container too
	$FullCards.visible = false
	$ScrollContainer.visible = true
	$HideFull.visible = false

# Navigate to previous set
func _on_set_left_pressed() -> void:
	current_set_id -= 1
	if current_set_id < 1:
		current_set_id = Global.set_editions.size()
	load_set(current_set_id)

# Navigate to next set
func _on_set_right_pressed() -> void:
	current_set_id += 1
	if current_set_id > Global.set_editions.size():
		current_set_id = 1
	load_set(current_set_id)

# Sort cards by ID
func _sort_by_id(card_a: Dictionary, card_b: Dictionary) -> bool:
	return card_a["id"] < card_b["id"]

# Return to home scene
func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Update collection count display based on the current filter
func update_collection_count() -> void:
	if current_filter == FILTER_ALL:
		_cards_in_collection()  # Show count for all effects
	else:
		_cards_in_collection_by_effect(current_filter)  # Show count for specific effect

# Count all cards in collection for the current set
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

# Count cards in collection with a specific effect
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

# Handle keyboard input
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_button_home_pressed()

# Filter functions
func _filter_by_effect(effect_type: String) -> void:
	current_filter = effect_type  # Set the current filter

	# Update all card nodes with the new filter
	var grid_container = $ScrollContainer/CenterContainer/GridContainer
	for card_node in grid_container.get_children():
		if card_node == card_template or not card_node.visible:
			continue

		var card_index = grid_container.get_children().find(card_node) - 1  # -1 for template
		if card_index >= 0 and card_index < cards_in_set.size():
			var card_data = cards_in_set[card_index]
			var id_set = card_data.get("id_set", card_data.get("id", ""))
			apply_card_filter(card_node, id_set)

	# Update collection count display
	update_collection_count()

# Filter button handlers
func _on_ef_all_pressed() -> void:
	_filter_by_effect(FILTER_ALL)

func _on_ef_b_pressed() -> void:
	_filter_by_effect("")  # Basic effect

func _on_ef_s_pressed() -> void:
	_filter_by_effect("Silver")

func _on_ef_g_pressed() -> void:
	_filter_by_effect("Gold")

func _on_ef_h_pressed() -> void:
	_filter_by_effect("Holo")

func _on_ef_fa_pressed() -> void:
	_filter_by_effect("Full Art")

func _on_ef_fs_pressed() -> void:
	_filter_by_effect("Full Silver")

func _on_ef_fg_pressed() -> void:
	_filter_by_effect("Full Gold")

func _on_ef_fh_pressed() -> void:
	_filter_by_effect("Full Holo")
