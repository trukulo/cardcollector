extends Control

const PLAYER_CARD_PATHS = [
	"Background/Player/Card1",
	"Background/Player/Card2",
	"Background/Player/Card3",
	"Background/Player/Card4"
]
const RIVAL_CARD_PATHS = [
	"Background/Rival/Card1",
	"Background/Rival/Card2",
	"Background/Rival/Card3",
	"Background/Rival/Card4"
]
const CARD_BACK_IMAGE = "res://gui/backcard.jpg"

var player_cards: Array = []
var rival_cards: Array = []
var player_card_data: Array = []
var rival_card_data: Array = []

var selected_stat: String = ""
var selected_direction: String = ""
var selected_player_index: int = -1
var revealed_rival_index: int = -1

var turn: int = 1
var input_enabled: bool = true
var waiting_for_player_card: bool = false

var _bet_button_default_size: Vector2 = Vector2(0, 0)

# Track cards won and lost during the battle
var cards_won: Array = []
var cards_lost: Array = []

func _ready():
	Global.load_data()
	cards_won.clear()
	cards_lost.clear()
	_populate_rival_cards()
	_populate_player_cards()
	_connect_bet_buttons()
	_connect_player_card_buttons()
	_reset_selections()
	var btn_path = "Panel/Deal/RedUp"
	if has_node(btn_path):
		var btn = get_node(btn_path)
		if btn is Control:
			_bet_button_default_size = btn.custom_minimum_size
	_update_turn_state()

func _connect_bet_buttons():
	var stats = ["Red", "Blue", "Yellow"]
	var directions = ["Up", "Down"]
	for stat in stats:
		for dir in directions:
			var btn_path = "Panel/Deal/%s%s" % [stat, dir]
			if has_node(btn_path):
				var btn = get_node(btn_path)
				if btn is Button:
					btn.pressed.connect(func(): _on_bet_button_pressed(stat.to_lower(), dir.to_lower()))
					btn.disabled = false

func _set_bet_buttons_enabled(enabled: bool):
	var stats = ["Red", "Blue", "Yellow"]
	var directions = ["Up", "Down"]
	for stat in stats:
		for dir in directions:
			var btn_path = "Panel/Deal/%s%s" % [stat, dir]
			if has_node(btn_path):
				var btn = get_node(btn_path)
				if btn is Button:
					btn.disabled = not enabled

func _highlight_bet_button(selected_stat, selected_direction):
	var stats = ["red", "blue", "yellow"]
	var directions = ["up", "down"]
	for stat in stats:
		for dir in directions:
			var btn_path = "Panel/Deal/%s%s" % [stat.capitalize(), dir.capitalize()]
			if has_node(btn_path):
				var btn = get_node(btn_path)
				if btn is Button:
					if stat == selected_stat and dir == selected_direction:
						btn.modulate = Color(0.5, 0.5, 0.5) # Darker
					else:
						btn.modulate = Color(1, 1, 1) # Normal

func _update_turn_state():
	if turn > 4:
		await _show_end_of_game_results()
		await get_tree().create_timer(5.0).timeout
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if turn == 1 or turn == 3:
		input_enabled = true
		waiting_for_player_card = false
		_set_bet_buttons_enabled(true)
		_highlight_bet_button(null, null)
		if has_node("Notif"):
			$Notif.text = "Your turn: choose a stat and direction!"
			$Notif.visible = true
	else:
		input_enabled = false
		waiting_for_player_card = false
		_set_bet_buttons_enabled(false)
		_highlight_bet_button(null, null)
		await get_tree().create_timer(1.0).timeout
		await _rival_turn()

func _reset_selections():
	selected_stat = ""
	selected_direction = ""
	selected_player_index = -1
	revealed_rival_index = -1

func _on_bet_button_pressed(stat, direction):
	if not input_enabled:
		return
	selected_stat = stat
	selected_direction = direction
	_set_bet_buttons_enabled(false)
	_highlight_bet_button(stat, direction)
	if has_node("Notif"):
		$Notif.text = "Select your card to play!"
		$Notif.visible = true
	waiting_for_player_card = true

func _connect_player_card_buttons():
	for i in range(4):
		var btn_path = PLAYER_CARD_PATHS[i] + "/Button"
		if has_node(btn_path):
			var btn = get_node(btn_path)
			if btn is Button:
				btn.pressed.connect(func(): _on_player_card_pressed(i))

func _on_player_card_pressed(index):
	if not waiting_for_player_card or not input_enabled:
		return
	if player_card_data[index]["lost"]:
		return
	selected_player_index = index
	waiting_for_player_card = false
	input_enabled = false
	await _reveal_random_rival_card()

# --- RIVAL TURN LOGIC ---
func _rival_turn():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var stats = ["red", "blue", "yellow"]
	var stat = stats[rng.randi_range(0, stats.size() - 1)]
	var directions = ["up", "down"]
	var direction = directions[rng.randi_range(0, directions.size() - 1)]
	selected_stat = stat
	selected_direction = direction
	_set_bet_buttons_enabled(false)
	_highlight_bet_button(stat, direction)
	waiting_for_player_card = true
	input_enabled = true
	var dir_str = ""
	if direction == "up":
		dir_str = "Greater"
	else:
		dir_str = "Lesser"
	if has_node("Notif"):
		$Notif.text = "Rival chose stat: %s, direction: %s. Your turn to pick a card!" % [
			stat.capitalize(),
			dir_str
		]
		$Notif.visible = true

func _reveal_random_rival_card():
	var unrevealed = []
	for i in range(4):
		if not rival_card_data[i]["revealed"]:
			unrevealed.append(i)
	if unrevealed.size() == 0:
		return

	# --- Minimal AI Logic: Pick the unrevealed card with the highest value in the selected stat ---
	var best_index = unrevealed[0]
	var best_value = -INF
	for i in unrevealed:
		var card = rival_card_data[i]["card"]
		var value = int(card.get(selected_stat, 0))
		if value > best_value:
			best_value = value
			best_index = i
	revealed_rival_index = best_index

	rival_card_data[revealed_rival_index]["revealed"] = true
	var rival_card = rival_card_data[revealed_rival_index]["card"]
	var effect = rival_card_data[revealed_rival_index]["effect"]
	var card_instance = rival_cards[revealed_rival_index]
	if has_node("Notif"):
		$Notif.text = "Rival reveals their card..."
		$Notif.visible = true
	await _flip_card(card_instance, rival_card, effect)
	_animate_card_reveal(card_instance)
	await get_tree().create_timer(0.5).timeout # 1 second less
	await _resolve_battle()

func _resolve_battle():
	var player = player_card_data[selected_player_index]
	var rival = rival_card_data[revealed_rival_index]
	var stat = selected_stat
	var direction = selected_direction
	var player_value = int(player["card"].get(stat, 0))
	var rival_value = int(rival["card"].get(stat, 0))
	var outcome = ""
	if player_value == rival_value:
		outcome = "draw"
	elif (direction == "up" and player_value > rival_value) or (direction == "down" and player_value < rival_value):
		outcome = "player_win"
	else:
		outcome = "rival_win"
	var dir_str = ""
	if direction == "up":
		dir_str = "Greater"
	else:
		dir_str = "Lesser"
	if has_node("Notif"):
		var result_text = ""
		if outcome == "draw":
			result_text = "It's a tie!"
		elif outcome == "player_win":
			result_text = "You win this round! Rival's card is added to your collection."
		else:
			result_text = "Rival wins this round! Your card is lost."
		$Notif.text = "Battle result: %s (Your %s: %d, Rival %s: %d, Direction: %s)" % [
			result_text, stat.capitalize(), player_value, stat.capitalize(), rival_value, dir_str
		]
		$Notif.visible = true

	# Animate and update collection/win/loss tracking
	if outcome == "draw":
		await _animate_draw(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		player_card_data[selected_player_index]["lost"] = false
		rival_card_data[revealed_rival_index]["revealed"] = true
	elif outcome == "player_win":
		await _animate_win(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		_add_card_to_collection(rival["card"], rival["effect"])
		cards_won.append({"card": rival["card"], "effect": rival["effect"]})
		player_card_data[selected_player_index]["lost"] = false
		rival_card_data[revealed_rival_index]["won"] = true
	elif outcome == "rival_win":
		await _animate_loss(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		_remove_card_from_collection(player["card"], player["effect"])
		cards_lost.append({"card": player["card"], "effect": player["effect"]})
		player_card_data[selected_player_index]["lost"] = true
		rival_card_data[revealed_rival_index]["won"] = false

	Global.save_data()
	await get_tree().create_timer(3.0).timeout # 1 second after result

	# Hide played cards from the scene
	player_cards[selected_player_index].visible = false
	rival_cards[revealed_rival_index].visible = false
	player_cards[selected_player_index].scale = Vector2(1, 1)
	rival_cards[revealed_rival_index].scale = Vector2(1, 1)
	_next_turn()

func _next_turn():
	turn += 1
	_reset_selections()
	_update_turn_state()

func _populate_rival_cards():
	rival_cards.clear()
	rival_card_data.clear()
	var rival_hand = _generate_rival_hand()
	for i in range(4):
		var card = rival_hand[i]["card"]
		var effect = rival_hand[i]["effect"]
		var card_instance = get_node(RIVAL_CARD_PATHS[i])
		rival_cards.append(card_instance)
		rival_card_data.append({
			"card": card,
			"effect": effect,
			"revealed": false
		})
		_show_card_back(card_instance)

func _generate_rival_hand() -> Array:
	var all_cards = []
	for card in Global.cards.values():
		all_cards.append(card)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	all_cards.shuffle()
	var rival_hand = []
	var basic_count = 0
	for i in range(all_cards.size()):
		var card = all_cards[i]
		if card.get("rarity", "D") == "D" and basic_count < 2:
			# Force first two to be basic
			rival_hand.append({
				"card": card,
				"effect": ""
			})
			basic_count += 1
			if rival_hand.size() == 2:
				break
	# Fill the rest randomly, avoiding duplicates
	var added_ids = []
	for entry in rival_hand:
		added_ids.append(entry["card"].get("id_set", entry["card"].get("id", "")))
	var i = 0
	while rival_hand.size() < 4 and i < all_cards.size():
		var card = all_cards[i]
		var id_set = card.get("id_set", card.get("id", ""))
		if id_set in added_ids:
			i += 1
			continue
		var effect = _get_random_effect_for_card(card)
		rival_hand.append({
			"card": card,
			"effect": effect
		})
		added_ids.append(id_set)
		i += 1
	# Shuffle again for fairness
	rng.randomize()
	rival_hand.shuffle()
	return rival_hand.slice(0, 4)

func _get_random_effect_for_card(card):
	var id_set = card.get("id_set", card.get("id", ""))
	var possible_effects = []
	if Global.collection.has(id_set):
		var entry = Global.collection[id_set]
		if entry.has("effects"):
			for effect in entry["effects"].keys():
				if entry["effects"][effect] > 0:
					possible_effects.append(effect)
	if possible_effects.size() == 0:
		possible_effects = ["", "Full Art", "Silver", "Gold", "Holo", "Full Silver", "Full Gold", "Full Holo"]
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return possible_effects[rng.randi_range(0, possible_effects.size() - 1)]

# --- POPULATE PLAYER CARDS ---
func _populate_player_cards():
	player_cards.clear()
	player_card_data.clear()
	var owned = []
	for id_set in Global.collection:
		var entry = Global.collection[id_set]
		if entry.get("amount", 0) > 0 and Global.cards.has(id_set):
			var card = Global.cards[id_set]
			# Get all effects for this card, including "" if present
			var effects = []
			if entry.has("effects"):
				for effect in entry["effects"].keys():
					if entry["effects"][effect] > 0:
						effects.append(effect)
			if effects.size() == 0:
				effects.append("")
			# Add one entry per owned card, each with a random effect
			for n in range(entry.get("amount", 0)):
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var effect = effects[rng.randi_range(0, effects.size() - 1)]
				owned.append({"card": card, "effect": effect})
	if owned.size() < 4:
		push_error("Not enough cards in collection for battle!")
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	owned.shuffle()
	for i in range(4):
		var card_data = owned[i]
		var card = card_data["card"]
		var effect = card_data["effect"]
		var card_instance = get_node(PLAYER_CARD_PATHS[i])
		player_cards.append(card_instance)
		player_card_data.append({
			"card": card,
			"effect": effect,
			"lost": false
		})
		_show_card_face(card_instance, card, effect)

func _show_card_face(card_node, card, effect):
	_set_card_pivot_center(card_node)
	if card_node.has_node("Panel/Info"):
		card_node.get_node("Panel/Info").visible = true
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = card.get("name", "Unknown").to_upper()
	if card_node.has_node("Panel/Info/number"):
		card_node.get_node("Panel/Info/number").text = str(card.get("id", 0))
	if card_node.has_node("Panel/Info/red"):
		card_node.get_node("Panel/Info/red").text = str(card.get("red", 0))
	if card_node.has_node("Panel/Info/blue"):
		card_node.get_node("Panel/Info/blue").text = str(card.get("blue", 0))
	if card_node.has_node("Panel/Info/yellow"):
		card_node.get_node("Panel/Info/yellow").text = str(card.get("yellow", 0))
	if card_node.has_node("Panel/Picture"):
		var image_path = card.get("image", "")
		if ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
		else:
			card_node.get_node("Panel/Picture").texture = null
		card_node.get_node("Panel/Picture").position.y = 0
	if card_node.has_node("Panel/Info/effect"):
		card_node.get_node("Panel/Info/effect").text = effect
	# --- SET EFFECT ON CARD NODE ---
	if card_node.has_method("set_effect"):
		card_node.set_effect(effect)

func _show_card_back(card_node):
	_set_card_pivot_center(card_node)
	if card_node.has_node("Panel/Picture"):
		card_node.get_node("Panel/Picture").texture = load(CARD_BACK_IMAGE)
	if card_node.has_node("Panel/Info"):
		card_node.get_node("Panel/Info").visible = false
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = ""
	if card_node.has_node("Panel/Info/number"):
		card_node.get_node("Panel/Info/number").text = ""
	if card_node.has_node("Panel/Info/red"):
		card_node.get_node("Panel/Info/red").text = ""
	if card_node.has_node("Panel/Info/blue"):
		card_node.get_node("Panel/Info/blue").text = ""
	if card_node.has_node("Panel/Info/yellow"):
		card_node.get_node("Panel/Info/yellow").text = ""
	if card_node.has_node("Panel/Info/effect"):
		card_node.get_node("Panel/Info/effect").text = ""
	# --- SET EFFECT ON CARD NODE ---
	if card_node.has_method("set_effect"):
		card_node.set_effect("")
	card_node.get_node("Panel/Picture").position.y = 0

func _set_card_pivot_center(card_node):
	if card_node is Control:
		var size = card_node.size
		card_node.pivot_offset = size / 2

func _flip_card(card_node, card, effect):
	_set_card_pivot_center(card_node)
	var tween = create_tween()
	tween.tween_property(card_node, "scale:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_reveal_card(card_node, card, effect)
	# --- SET EFFECT ON CARD NODE ---
	if card_node.has_method("set_effect"):
		card_node.set_effect(effect)
	var tween2 = create_tween()
	tween2.tween_property(card_node, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween2.finished

func _reveal_card(card_node, card, effect):
	if card_node.has_node("Panel/Picture"):
		var image_path = card.get("image", "")
		if ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
		else:
			card_node.get_node("Panel/Picture").texture = null
		card_node.get_node("Panel/Picture").position.y = 0
	if card_node.has_node("Panel/Info"):
		card_node.get_node("Panel/Info").visible = true
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = card.get("name", "Unknown").to_upper()
	if card_node.has_node("Panel/Info/number"):
		card_node.get_node("Panel/Info/number").text = str(card.get("id", 0))
	if card_node.has_node("Panel/Info/red"):
		card_node.get_node("Panel/Info/red").text = str(card.get("red", 0))
	if card_node.has_node("Panel/Info/blue"):
		card_node.get_node("Panel/Info/blue").text = str(card.get("blue", 0))
	if card_node.has_node("Panel/Info/yellow"):
		card_node.get_node("Panel/Info/yellow").text = str(card.get("yellow", 0))
	if card_node.has_node("Panel/Info/effect"):
		card_node.get_node("Panel/Info/effect").text = effect
	# --- SET EFFECT ON CARD NODE ---
	if card_node.has_method("set_effect"):
		card_node.set_effect(effect)

func _add_card_to_collection(card, effect=""):
	var id_set = card.get("id_set", card.get("id", ""))
	if not Global.collection.has(id_set):
		Global.collection[id_set] = {"amount": 1, "effects": {}, "deck": 0}
	else:
		Global.collection[id_set]["amount"] += 1
	# Track effect
	if not Global.collection[id_set].has("effects"):
		Global.collection[id_set]["effects"] = {}
	if effect != "":
		if not Global.collection[id_set]["effects"].has(effect):
			Global.collection[id_set]["effects"][effect] = 0
		Global.collection[id_set]["effects"][effect] += 1

func _remove_card_from_collection(card, effect=""):
	var id_set = card.get("id_set", card.get("id", ""))
	if Global.collection.has(id_set):
		# Remove effect if present
		if effect != "" and Global.collection[id_set].has("effects"):
			if Global.collection[id_set]["effects"].has(effect):
				Global.collection[id_set]["effects"][effect] -= 1
				if Global.collection[id_set]["effects"][effect] <= 0:
					Global.collection[id_set]["effects"].erase(effect)
		# Always decrement amount
		Global.collection[id_set]["amount"] -= 1
		if Global.collection[id_set]["amount"] <= 0:
			Global.collection.erase(id_set)

func _animate_card_selected(card_node):
	pass

func _animate_card_reveal(card_node):
	pass

func _animate_win(player_card, rival_card):
	_set_card_pivot_center(player_card)
	_set_card_pivot_center(rival_card)
	var tween = create_tween()
	tween.tween_property(player_card, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(rival_card, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _animate_loss(player_card, rival_card):
	_set_card_pivot_center(player_card)
	_set_card_pivot_center(rival_card)
	var tween = create_tween()
	tween.tween_property(player_card, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(rival_card, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _animate_draw(player_card, rival_card):
	await get_tree().create_timer(0.1).timeout

func _all_cards_gone() -> bool:
	for i in range(4):
		if player_cards[i].visible or rival_cards[i].visible:
			return false
	return true

func _show_end_of_game_results():
	var msg = "Battle finished!\n"
	if cards_won.size() > 0:
		msg += "You WON these cards:\n"
		for entry in cards_won:
			var card = entry["card"]
			var effect = entry["effect"]
			msg += "· %s - %s\n" % [card.get("name", "Unknown"), effect]
	else:
		msg += "You did not win any cards.\n"
	if cards_lost.size() > 0:
		msg += "\nYou LOST these cards:\n"
		for entry in cards_lost:
			var card = entry["card"]
			var effect = entry["effect"]
			msg += "· %s - %s\n" % [card.get("name", "Unknown"), effect]
	else:
		msg += "\nYou did not lose any cards.\n"
	if has_node("Notif"):
		$Notif.text = msg
		$Notif.visible = true
	if has_node("Panel"):
		$Panel.visible = false
	await get_tree().create_timer(2.5).timeout
