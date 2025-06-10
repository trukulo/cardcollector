extends Control

const CARDS_PER_BATCH = 6  # Load cards in batches for smooth performance
const BATCH_DELAY = 0.05   # Delay between batches in seconds

var current_set = 1
var unique_cards: Dictionary = {}  # Store unique cards by ID to prevent duplicates
var cards_in_set: Array = []
var card_template = null
var grid_container = null
var is_loading: bool = false

func _ready() -> void:
	# Cache frequently accessed nodes
	grid_container = $ScrollContainer/CenterContainer/GridContainer
	card_template = grid_container.get_node("Card1")
	
	if not card_template:
		push_error("Card1 template not found!")
		return
	
	card_template.visible = false
	
	# Set up grid container for 3 columns
	if grid_container.columns != 3:
		grid_container.columns = 3
	
	# Connect the SetLeft and SetRight buttons
	_connect_ui_signals()
	
	# Load the initial set
	load_set(current_set)

func _connect_ui_signals():
	# Connect UI buttons with error checking
	var connections = [
		["Sets/SetLeft", "_on_set_left_pressed"],
		["Sets/SetRight", "_on_set_right_pressed"]
	]
	
	for connection in connections:
		if has_node(connection[0]):
			var button = get_node(connection[0])
			if not button.is_connected("pressed", Callable(self, connection[1])):
				button.connect("pressed", Callable(self, connection[1]))
		else:
			push_warning("Button not found: " + connection[0])

func load_set(set_id: int) -> void:
	if is_loading:
		return
	
	is_loading = true
	current_set = set_id
	
	# Clear previous data
	unique_cards.clear()
	cards_in_set.clear()
	
	# Check if the set is unlocked
	if not _is_set_unlocked(set_id):
		push_warning("Set %d is not unlocked." % set_id)
		is_loading = false
		return
	
	# Prepare unique cards for this set
	_prepare_unique_cards(set_id)
	
	# Clear existing cards (except template)
	_clear_existing_cards()
	
	# Load cards in batches for smooth performance
	await _load_cards_in_batches()
	
	# Update the set label
	update_set_label()
	
	is_loading = false

func _is_set_unlocked(set_id: int) -> bool:
	return Global.available_sets.has(set_id) and Global.available_sets[set_id]

func _prepare_unique_cards(set_id: int):
	# Collect all unique cards in the player's collection for the selected set
	var seen_ids = {}
	
	for id_set in Global.collection.keys():
		if id_set.ends_with("_%d" % set_id) and not seen_ids.has(id_set):
			if Global.cards.has(id_set):
				var card_data = Global.cards[id_set]
				var card_id = card_data.get("id", 0)
				
				# Only keep the first occurrence of each card ID
				if not unique_cards.has(card_id):
					unique_cards[card_id] = card_data
					seen_ids[id_set] = true
	
	# Convert to sorted array by card number (1, 2, 3, ...)
	cards_in_set = unique_cards.values()
	cards_in_set.sort_custom(_sort_by_card_number)

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
	
	# Configure card appearance
	_configure_card_appearance(card_node)
	
	# Load card image
	_load_card_image(card_node, card_data)
	
	# Connect card button
	_connect_card_button(card_node, card_data)
	
	card_node.z_index = 0
	card_node.set_meta("original_z_index", 0)
	card_node.connect("mouse_entered", Callable(self, "_on_card_mouse_entered").bind(card_node))
	card_node.connect("mouse_exited", Callable(self, "_on_card_mouse_exited").bind(card_node))

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

func _configure_card_appearance(card_node: Node):
	# Disable the Panel/Info section and adjust picture position
	var info_panel = card_node.get_node("Panel/Info")
	if info_panel:
		info_panel.visible = false
		
		# Adjust picture position
		var picture_node = card_node.get_node("Panel/Picture")
		if picture_node:
			picture_node.position.y = 0

func _load_card_image(card_node: Node, card_data: Dictionary):
	var picture_node = card_node.get_node("Panel/Picture")
	if not picture_node:
		return
	
	var image_path = card_data.get("image", "")
	if ResourceLoader.exists(image_path):
		picture_node.texture = load(image_path)
	else:
		picture_node.texture = null
		if image_path != "":
			push_warning("Image not found for card: " + card_data.get("name", "Unknown"))

func _connect_card_button(card_node: Node, card_data: Dictionary):
	var button = card_node.get_node("Button")
	if not button:
		push_warning("Button node not found in card_node!")
		return
	
	# Disconnect if already connected
	if button.is_connected("pressed", Callable(self, "_on_card_pressed")):
		button.disconnect("pressed", Callable(self, "_on_card_pressed"))
	
	# Connect with card data
	var id_set = card_data.get("id_set", "")
	button.connect("pressed", Callable(self, "_on_card_pressed").bind(id_set, {}))

func update_set_label() -> void:
	if has_node("Sets/Set"):
		var label = $Sets/Set
		label.text = "Set #%d" % current_set

func _on_set_left_pressed() -> void:
	if is_loading:
		return
	
	# Navigate to the previous set
	current_set -= 1
	if current_set < 1:
		current_set = 1  # Prevent going below set 1
	load_set(current_set)

func _on_set_right_pressed() -> void:
	if is_loading:
		return
	
	# Navigate to the next set
	current_set += 1
	if current_set > Global.set_editions.size():
		current_set = Global.set_editions.size()  # Prevent going beyond the last set
	load_set(current_set)

func _on_card_pressed(id_set: String, card_instance: Dictionary) -> void:
	var full_card = $FullCard
	if not full_card:
		push_error("FullCard node not found!")
		return

	# Find the card node in the grid with this id_set and restore its z_index if needed
	for card_node in grid_container.get_children():
		if card_node.has_meta("original_z_index") and card_node.z_index != card_node.get_meta("original_z_index"):
			card_node.z_index = card_node.get_meta("original_z_index")

	# Get card data from Global.cards
	if not Global.cards.has(id_set):
		push_error("Card data not found for id_set: " + id_set)
		return

	var card_data = Global.cards[id_set]

	# Load card data into FullCard efficiently
	_populate_full_card_data(full_card, card_data)

	# Load the texture for the card picture
	_load_full_card_image(full_card, card_data)

	# Set the effect for the FullCard from card_instance
	_apply_full_card_effect(full_card, card_instance)

	# Configure full card appearance
	_configure_full_card_appearance(full_card)

	# Show the full card
	full_card.visible = true

func _populate_full_card_data(full_card: Node, card_data: Dictionary):
	# Efficiently populate full card information
	var info_mappings = [
		["Panel/Info/name", card_data.get("name", "Unknown").to_upper()],
		["Panel/Info/number", str(card_data.get("id", 0))],
		["Panel/Info/red", str(card_data.get("red", 0))],
		["Panel/Info/blue", str(card_data.get("blue", 0))],
		["Panel/Info/yellow", str(card_data.get("yellow", 0))]
	]
	
	for mapping in info_mappings:
		if full_card.has_node(mapping[0]):
			full_card.get_node(mapping[0]).text = mapping[1]

func _load_full_card_image(full_card: Node, card_data: Dictionary):
	var picture_node = full_card.get_node("Panel/Picture")
	if not picture_node:
		return
	
	var image_path = card_data.get("image", "")
	if ResourceLoader.exists(image_path):
		picture_node.texture = load(image_path)
	else:
		picture_node.texture = null
		if image_path != "":
			push_warning("Image not found for card: " + card_data.get("name", "Unknown"))

func _apply_full_card_effect(full_card: Node, card_instance: Dictionary):
	var effect = card_instance.get("effect", "")
	
	if full_card.has_method("set_effect"):
		full_card.set_effect(effect)
	else:
		push_warning("FullCard does not have a set_effect() method!")

func _configure_full_card_appearance(full_card: Node):
	# Configure full card appearance
	var info_panel = full_card.get_node("Panel/Info")
	if info_panel:
		info_panel.visible = false
	
	var picture_node = full_card.get_node("Panel/Picture")
	if picture_node:
		picture_node.position.y = 0

func _sort_by_card_number(a: Dictionary, b: Dictionary) -> bool:
	var card_id_a = a.get("id", 0)
	var card_id_b = b.get("id", 0)
	return card_id_a < card_id_b

# Button handlers
func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_hide_pressed() -> void:
	if has_node("FullCard"):
		$FullCard.visible = false

# Handle keyboard input
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if has_node("FullCard") and $FullCard.visible:
			_on_button_hide_pressed()
		else:
			_on_button_ok_pressed()

func _on_card_mouse_entered(card_node):
	card_node.set_meta("original_z_index", card_node.z_index)
	card_node.z_index = 1000
	card_node.scale = Vector2(1.1, 1.1)

func _on_card_mouse_exited(card_node):
	if card_node.has_meta("original_z_index"):
		card_node.z_index = card_node.get_meta("original_z_index")
	card_node.scale = Vector2(1, 1)