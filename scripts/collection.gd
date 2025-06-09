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

const FILTER_ALL = "ALL"
const CARDS_PER_BATCH = 6  # Load cards in batches for smooth performance
const BATCH_DELAY = 0.05   # Delay between batches in seconds

var current_set_id: int = 1
var current_fullcard_index: int = -1
var current_filter: String = "ALL"
var cards_in_set: Array = []
var unique_cards: Dictionary = {}  # Store unique cards by ID to prevent duplicates
var card_template = null
var grid_container = null
var is_loading: bool = false

func _ready():
	Global.load_data()
	
	# Cache frequently accessed nodes
	grid_container = $ScrollContainer/CenterContainer/GridContainer
	card_template = grid_container.get_node("Card1")
	
	if not card_template:
		push_error("Card template not found!")
		return
	
	card_template.visible = false
	
	# Set up grid container for 3 columns
	if grid_container.columns != 3:
		grid_container.columns = 3
	
	_connect_ui_signals()
	
	if Global.info == false:
		if has_node("BoosterTemplate"):
			$BoosterTemplate.visible = false
		if has_node("FullCards"):
			$FullCards.scale = Vector2(0.90, 0.90)
	
	# Load the initial set
	load_set(current_set_id)

func _connect_ui_signals():
	# Connect UI buttons with error checking
	var connections = [
		["SetControls/SetLeft", "_on_set_left_pressed"],
		["SetControls/SetRight", "_on_set_right_pressed"],
		["Effects/EfAll", "_on_ef_all_pressed"],
		["Effects/EfB", "_on_ef_b_pressed"],
		["Effects/EfS", "_on_ef_s_pressed"],
		["Effects/EfG", "_on_ef_g_pressed"],
		["Effects/EfH", "_on_ef_h_pressed"],
		["Effects2/EfFA", "_on_ef_fa_pressed"],
		["Effects2/EfFS", "_on_ef_fs_pressed"],
		["Effects2/EfFG", "_on_ef_fg_pressed"],
		["Effects2/EfFH", "_on_ef_fh_pressed"],
		["HideFull", "_on_hide_full_pressed"],
		["HBoxContainer/ButtonHome", "_on_button_home_pressed"]
	]
	
	for connection in connections:
		if has_node(connection[0]):
			var button = get_node(connection[0])
			if not button.is_connected("pressed", Callable(self, connection[1])):
				button.connect("pressed", Callable(self, connection[1]))

func load_set(set_id: int):
	if is_loading:
		return
	
	is_loading = true
	current_set_id = set_id
	
	# Clear previous data
	unique_cards.clear()
	cards_in_set.clear()
	
	# Filter and organize cards for the specified set
	_prepare_unique_cards(set_id)
	
	# Update set display elements
	_update_set_display(set_id)
	
	# Clear existing cards (except template)
	_clear_existing_cards()
	
	# Load cards in batches for smooth performance
	await _load_cards_in_batches()
	
	# Update collection count display
	update_collection_count()
	
	is_loading = false

func _prepare_unique_cards(set_id: int):
	# First pass: collect unique cards by ID for this set
	for card_data in Global.cards.values():
		if card_data.get("set", 0) == set_id:
			var card_id = card_data.get("id", 0)
			
			# Only keep the first occurrence of each card ID
			if not unique_cards.has(card_id):
				unique_cards[card_id] = card_data
	
	# Convert to sorted array by card number (1, 2, 3, ...)
	cards_in_set = unique_cards.values()
	cards_in_set.sort_custom(_sort_by_id)

func _update_set_display(set_id: int):
	var set_folder = "res://cards/" + str(set_id)
	var booster_image_path = set_folder + "/1.jpg"
	
	if ResourceLoader.exists(booster_image_path):
		$Booster.texture = load(booster_image_path)
	else:
		push_warning("Booster pack image not found for set " + str(set_id))
	
	if has_node("BoosterTemplate/set"):
		$BoosterTemplate/set.text = "Set #" + str(set_id)

func _clear_existing_cards():
	var children_to_remove = []
	
	# Collect children to remove (can't modify during iteration)
	for child in grid_container.get_children():
		if child != card_template:
			children_to_remove.append(child)
	
	# Remove children
	for child in children_to_remove:
		child.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame

func _load_cards_in_batches():
	var total_cards = cards_in_set.size()
	var cards_loaded = 0
	
	while cards_loaded < total_cards:
		var batch_end = min(cards_loaded + CARDS_PER_BATCH, total_cards)
		
		# Load batch of cards
		for i in range(cards_loaded, batch_end):
			_create_card_node(i)
		
		cards_loaded = batch_end
		
		# Small delay between batches to keep UI responsive
		if cards_loaded < total_cards:
			await get_tree().create_timer(BATCH_DELAY).timeout

func _create_card_node(card_index: int):
	if card_index >= cards_in_set.size():
		return
	
	var card_data = cards_in_set[card_index]
	var card_node = card_template.duplicate()
	card_node.visible = true
	
	# Add to grid container
	grid_container.add_child(card_node)
	
	# Populate card details efficiently
	_populate_card_data(card_node, card_data)
	
	# Get the card ID set
	var id_set = card_data.get("id_set", str(card_data.get("id", "")))
	
	# Apply current filter and effects
	apply_card_filter(card_node, id_set)
	update_effects_text(card_node, id_set)
	
	# Connect card button
	_connect_card_button(card_node, card_index)

func _populate_card_data(card_node: Node, card_data: Dictionary):
	# Efficiently populate card information
	var info_mappings = [
		["Panel/Info/name", card_data.get("name", "Unknown").to_upper()],
		["Panel/Info/number", str(card_data.get("id", 0))],
		["Panel/Info/red", str(card_data.get("red", 0))],
		["Panel/Info/blue", str(card_data.get("blue", 0))],
		["Panel/Info/yellow", str(card_data.get("yellow", 0))]
	]
	
	for mapping in info_mappings:
		if card_node.has_node(mapping[0]):
			card_node.get_node(mapping[0]).text = mapping[1]
	
	# Load card image
	if card_node.has_node("Panel/Picture"):
		var image_path = card_data.get("image", "")
		if ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
		else:
			card_node.get_node("Panel/Picture").texture = null
			if image_path != "":
				push_warning("Image not found: " + image_path)

func _connect_card_button(card_node: Node, card_index: int):
	var button = card_node.get_node("Button")
	if not button:
		return
	
	# Disconnect if already connected
	if button.is_connected("pressed", Callable(self, "_on_card_button_pressed")):
		button.disconnect("pressed", Callable(self, "_on_card_button_pressed"))
	
	# Connect with card index
	button.connect("pressed", Callable(self, "_on_card_button_pressed").bind(card_index))

# Apply the current filter to a card
func apply_card_filter(card_node, id_set):
	var owned = _check_card_ownership(id_set)
	
	# Apply visual effects
	if card_node.has_method("set_effect"):
		if owned:
			var effect_to_apply = "" if current_filter == FILTER_ALL else current_filter
			card_node.set_effect(effect_to_apply)
		else:
			card_node.set_effect("")
			if current_filter in ["Full Art", "Full Silver", "Full Gold", "Full Holo"]:
				card_node.set_effect("Full Art")
	
	# Set brightness based on ownership
	if card_node.has_node("Panel/Picture"):
		var brightness = 1.0 if owned else 0.2
		card_node.get_node("Panel/Picture").modulate = Color(brightness, brightness, brightness)
	
	# Update appearance if method exists
	if card_node.has_method("update_card_appearance"):
		card_node.update_card_appearance()

func _check_card_ownership(id_set: String) -> bool:
	if current_filter == FILTER_ALL:
		return is_any_effect_owned_for_card(id_set)
	else:
		return is_effect_owned_for_card(id_set, current_filter)

# Update the effects text display
func update_effects_text(card_node, id_set):
	if not card_node.has_node("Effects"):
		return
	
	var effects_owned = []
	
	# Check which effects are owned for this card
	for effect in FULL_CARD_EFFECTS:
		if is_effect_owned_for_card(id_set, effect):
			effects_owned.append(EFFECT_ABBR[effect])
	
	# Update the Effects text node
	card_node.get_node("Effects").text = "-".join(effects_owned)

# Optimized ownership checking
func is_any_effect_owned_for_card(id_set: String) -> bool:
	var collection_data = Global.collection.get(id_set, {})
	var cards = collection_data.get("cards", [])
	return cards.size() > 0

# Optimized specific effect ownership checking
func is_effect_owned_for_card(id_set: String, effect: String) -> bool:
	var collection_data = Global.collection.get(id_set, {})
	var cards = collection_data.get("cards", [])
	
	for card_instance in cards:
		if card_instance.get("effect", "") == effect:
			return true
	return false

# Improved sorting function
func _sort_by_id(card_a: Dictionary, card_b: Dictionary) -> bool:
	var id_a = card_a.get("id", 0)
	var id_b = card_b.get("id", 0)
	return id_a < id_b

# Show the full card view when a card is clicked
func _on_card_button_pressed(card_index: int):
	if card_index < 0 or card_index >= cards_in_set.size():
		return
	
	var card_data = cards_in_set[card_index]
	var id_set = card_data.get("id_set", str(card_data.get("id", "")))
	
	if not is_any_effect_owned_for_card(id_set):
		return
	
	_setup_full_card_display(card_data, id_set)
	_show_full_card_view()

func _setup_full_card_display(card_data: Dictionary, id_set: String):
	# Show only the effects you own, hide others
	for i in range(8):
		var effect = FULL_CARD_EFFECTS[i]
		var full_card_path = get_full_card_path(i)
		
		if not has_node(full_card_path):
			continue
		
		var full_card = get_node(full_card_path)
		var owned = is_effect_owned_for_card(id_set, effect)
		full_card.visible = owned
		
		if owned:
			_configure_full_card(full_card, card_data, id_set, effect)

func _configure_full_card(full_card: Node, card_data: Dictionary, id_set: String, effect: String):
	if full_card.has_method("set_effect"):
		full_card.set_effect(effect)
	
	# Set protection from the first matching card instance
	if full_card.has_method("set_protection"):
		var protection = _get_card_protection(id_set, effect, card_data)
		full_card.set_protection(protection)
	
	# Update card details
	_populate_card_data(full_card, card_data)
	
	if full_card.has_method("update_card_appearance"):
		full_card.update_card_appearance()

func _get_card_protection(id_set: String, effect: String, card_data: Dictionary) -> int:
	var collection_data = Global.collection.get(id_set, {})
	var cards = collection_data.get("cards", [])
	
	for card_instance in cards:
		if card_instance.get("effect", "") == effect:
			return card_instance.get("protection", 0)
	
	return card_data.get("protection", 0)

func _show_full_card_view():
	$FullCards.visible = true
	$ScrollContainer.visible = false
	$HideFull.visible = true
	$Effects.visible = false
	$Effects2.visible = false

# Get the path to a full card by index
func get_full_card_path(index: int) -> String:
	if index < 4:
		return "FullCards/HBoxContainer/Card%d" % (index + 1)
	else:
		return "FullCards/HBoxContainer2/Card%d" % (index - 4 + 5)

# Hide the full card view
func _on_hide_full_pressed():
	$Effects.visible = true
	$Effects2.visible = true
	$FullCards.visible = false
	$ScrollContainer.visible = true
	$HideFull.visible = false

# Navigate to previous set
func _on_set_left_pressed() -> void:
	if is_loading:
		return
	
	current_set_id -= 1
	if current_set_id < 1:
		current_set_id = Global.set_editions.size()
	load_set(current_set_id)

# Navigate to next set
func _on_set_right_pressed() -> void:
	if is_loading:
		return
	
	current_set_id += 1
	if current_set_id > Global.set_editions.size():
		current_set_id = 1
	load_set(current_set_id)

# Return to home scene
func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Update collection count display based on the current filter
func update_collection_count() -> void:
	if current_filter == FILTER_ALL:
		_cards_in_collection()
	else:
		_cards_in_collection_by_effect(current_filter)

# Count all cards in collection for the current set
func _cards_in_collection() -> void:
	var owned_count = 0
	var total_count = cards_in_set.size()
	
	for card in cards_in_set:
		var id_set = card.get("id_set", str(card.get("id", "")))
		if is_any_effect_owned_for_card(id_set):
			owned_count += 1
	
	$Collection.text = "Cards: %d/%d" % [owned_count, total_count]

# Count cards in collection with a specific effect
func _cards_in_collection_by_effect(effect_type: String) -> void:
	var owned_count = 0
	var total_count = cards_in_set.size()
	
	for card in cards_in_set:
		var id_set = card.get("id_set", str(card.get("id", "")))
		if is_effect_owned_for_card(id_set, effect_type):
			owned_count += 1
	
	$Collection.text = "Cards: %d/%d (%s)" % [owned_count, total_count, EFFECT_ABBR[effect_type]]

# Handle keyboard input
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_button_home_pressed()

# Filter functions
func _filter_by_effect(effect_type: String) -> void:
	if is_loading:
		return
	
	current_filter = effect_type
	
	# Update all existing card nodes with the new filter
	var card_nodes = []
	for child in grid_container.get_children():
		if child != card_template and child.visible:
			card_nodes.append(child)
	
	# Update cards in batches to maintain smooth performance
	var batch_size = 8
	var current_batch = 0
	
	while current_batch * batch_size < card_nodes.size():
		var start_idx = current_batch * batch_size
		var end_idx = min(start_idx + batch_size, card_nodes.size())
		
		for i in range(start_idx, end_idx):
			var card_node = card_nodes[i]
			var card_index = card_nodes.find(card_node)
			
			if card_index < cards_in_set.size():
				var card_data = cards_in_set[card_index]
				var id_set = card_data.get("id_set", str(card_data.get("id", "")))
				apply_card_filter(card_node, id_set)
		
		current_batch += 1
		
		# Small delay between batches
		if current_batch * batch_size < card_nodes.size():
			await get_tree().create_timer(0.02).timeout
	
	# Update collection count display
	update_collection_count()

# Filter button handlers
func _on_ef_all_pressed() -> void:
	_filter_by_effect(FILTER_ALL)

func _on_ef_b_pressed() -> void:
	_filter_by_effect("")

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