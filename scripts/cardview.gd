extends Control

var current_set = 1  # Start with set 1

func _ready() -> void:
	# Connect the SetLeft and SetRight buttons
	$Sets/SetLeft.connect("pressed", Callable(self, "_on_set_left_pressed"))
	$Sets/SetRight.connect("pressed", Callable(self, "_on_set_right_pressed"))

	# Load the initial set
	load_set(current_set)

func load_set(set_id: int) -> void:
	# Get the Card1 node to use as a template
	var card_template = $ScrollContainer/CenterContainer/GridContainer/Card1
	if not card_template:
		print("Card1 template not found!")
		return

	# Clear existing cards in the GridContainer (except the template)
	var grid_container = $ScrollContainer/CenterContainer/GridContainer
	for child in grid_container.get_children():
		if child != card_template:
			child.queue_free()

	# Check if the set is unlocked
	if not Global.available_sets.has(set_id) or not Global.available_sets[set_id]:
		print("Set %d is not unlocked." % set_id)
		return

	# Collect all unique cards in the player's collection for the selected set
	var unique_cards = []
	var seen_ids = {}
	for id_set in Global.collection.keys():
		if id_set.ends_with("_%d" % set_id) and not seen_ids.has(id_set):
			unique_cards.append(Global.cards[id_set])
			seen_ids[id_set] = true

	# Sort the unique cards by their number (id)
	unique_cards.sort_custom(Callable(self, "_sort_by_card_number"))

	# Add the unique cards to the grid
	for i in range(unique_cards.size()):
		var card_data = unique_cards[i]
		print("Adding card to grid:", card_data["id"])  # Debugging
		# Duplicate the template
		var card_node = card_template.duplicate()
		card_node.visible = true
		grid_container.add_child(card_node)

		# Populate card details
		card_node.get_node("Panel/Info/name").text = card_data.get("name", "Unknown").to_upper()
		card_node.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
		card_node.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
		card_node.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
		card_node.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))

		# Disable the Panel/Info section
		var info_panel = card_node.get_node("Panel/Info")
		if info_panel:
			info_panel.visible = false  # Disable the Info panel
			card_node.get_node("Panel/Picture").position.y = 0

		# Load the texture for the card picture
		var image_path = card_data.get("image", "")
		if ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
		else:
			print("Warning: Image not found for card:", card_data.get("name", "Unknown"))

		# Connect the card button to show the FullCard
		var button = card_node.get_node("Button")  # Adjust the path if necessary
		if button:
			button.connect("pressed", Callable(self, "_on_card_pressed").bind(card_data["id_set"], {}))
		else:
			print("Warning: Button node not found in card_node!")

		# Add delay after the 10th card
		if i >= 10:
			await get_tree().create_timer(0.1).timeout

	# Update the set label
	update_set_label()

func update_set_label() -> void:
	var label = $Sets/Set
	label.text = "Set #%d" % current_set

func _on_set_left_pressed() -> void:
	# Navigate to the previous set
	current_set -= 1
	if current_set < 1:
		current_set = 1  # Prevent going below set 1
	load_set(current_set)

func _on_set_right_pressed() -> void:
	# Navigate to the next set
	current_set += 1
	if current_set > Global.set_editions.size():
		current_set = Global.set_editions.size()  # Prevent going beyond the last set
	load_set(current_set)

func _on_card_pressed(id_set: String, card_instance: Dictionary) -> void:
	# Make FullCard visible
	var full_card = $FullCard

	# Get card data from Global.cards
	var card_data = Global.cards[id_set]

	# Load card data into FullCard
	full_card.get_node("Panel/Info/name").text = card_data.get("name", "Unknown").to_upper()
	full_card.get_node("Panel/Info/number").text = str(card_data.get("id", 0))
	full_card.get_node("Panel/Info/red").text = str(card_data.get("red", 0))
	full_card.get_node("Panel/Info/blue").text = str(card_data.get("blue", 0))
	full_card.get_node("Panel/Info/yellow").text = str(card_data.get("yellow", 0))

	# Load the texture for the card picture
	var image_path = card_data.get("image", "")
	if ResourceLoader.exists(image_path):
		full_card.get_node("Panel/Picture").texture = load(image_path)
	else:
		print("Warning: Image not found for card:", card_data.get("name", "Unknown"))

	# Retrieve and set the effect for the FullCard from card_instance
	var effect = card_instance.get("effect", "")

	if full_card.has_method("set_effect"):
		full_card.set_effect(effect)
	else:
		print("Warning: FullCard does not have a set_effect() method!")

	var info_panel = full_card.get_node("Panel/Info")
	info_panel.visible = false  # Disable the Info panel
	$FullCard/Panel/Picture.position.y = 0
	full_card.visible = true

func _sort_by_card_number(a: Dictionary, b: Dictionary) -> int:
	var card_id_a = int(a["id_set"].split("_")[0].strip_edges())
	var card_id_b = int(b["id_set"].split("_")[0].strip_edges())
	return card_id_a - card_id_b

func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_hide_pressed() -> void:
	$FullCard.visible = false
