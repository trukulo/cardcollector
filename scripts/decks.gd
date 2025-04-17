extends Control

const CARDS_PER_PAGE = 18

var card_keys := []
var current_page := 0
var total_pages := 0
var current_set := 0  # 0 = all sets, otherwise set number
var set_ids := []
var card_node_paths = [
	"VBoxContainer/HBoxContainer/Card1", "VBoxContainer/HBoxContainer/Card2", "VBoxContainer/HBoxContainer/Card3",
	"VBoxContainer/HBoxContainer/Card4", "VBoxContainer/HBoxContainer/Card5", "VBoxContainer/HBoxContainer/Card6",
	"VBoxContainer/HBoxContainer2/Card1", "VBoxContainer/HBoxContainer2/Card2", "VBoxContainer/HBoxContainer2/Card3",
	"VBoxContainer/HBoxContainer2/Card4", "VBoxContainer/HBoxContainer2/Card5", "VBoxContainer/HBoxContainer2/Card6",
	"VBoxContainer/HBoxContainer3/Card1", "VBoxContainer/HBoxContainer3/Card2", "VBoxContainer/HBoxContainer3/Card3",
	"VBoxContainer/HBoxContainer3/Card4", "VBoxContainer/HBoxContainer3/Card5", "VBoxContainer/HBoxContainer3/Card6"
]

func _ready():
	Global.load_data()
	set_ids = [0] + Global.set_editions.keys()
	set_ids.sort()
	current_set = 0
	update_set_label()
	update_card_keys()
	current_page = 0
	populate_cards()
	# Connect set navigation buttons if not connected in the editor
	if has_node("Sets/SetLeft"):
		get_node("Sets/SetLeft").connect("pressed", Callable(self, "_on_set_left_pressed"))
	if has_node("Sets/SetRight"):
		get_node("Sets/SetRight").connect("pressed", Callable(self, "_on_set_right_pressed"))
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

func update_card_keys():
	if current_set == 0:
		card_keys = Global.collection.keys()
	else:
		card_keys = []
		for id_set in Global.collection.keys():
			if Global.cards.has(id_set) and Global.cards[id_set].get("set", 0) == current_set:
				card_keys.append(id_set)
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
				var id_set = card_keys[start_index + i]
				var card_data = Global.cards.get(id_set, null)
				if card_data:
					var effect = ""
					if Global.collection[id_set].has("effects"):
						var effects = Global.collection[id_set]["effects"].keys()
						if effects.size() > 0:
							effect = effects[0]
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
			else:
				card_node.visible = false

func _on_card_button_pressed(card_index):
	var start_index = current_page * CARDS_PER_PAGE
	if card_index >= 0 and (start_index + card_index) < card_keys.size():
		var id_set = card_keys[start_index + card_index]
		show_full_card(id_set)

func show_full_card(id_set):
	var card_data = Global.cards.get(id_set, null)
	if card_data and has_node("FullCard"):
		var full_card = get_node("FullCard")
		full_card.visible = true
		var effect = ""
		if Global.collection[id_set].has("effects"):
			var effects = Global.collection[id_set]["effects"].keys()
			if effects.size() > 0:
				effect = effects[0]
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

func _on_full_card_button_pressed():
	if has_node("FullCard"):
		get_node("FullCard").visible = false

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
