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
				if btn is Control:
					if selected_stat == null or selected_direction == null:
						# Show all buttons when nothing is selected
						btn.visible = true
					else:
						# Only show the selected button
						btn.visible = (stat == selected_stat && dir == selected_direction)

func _update_turn_state():
	if turn > 4:
		await _show_end_of_game_results()
		if Global.train == 1 or Global.rounds == 0:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		else:
			Global.rounds -= 1
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	if turn == 1 or turn == 3:
		input_enabled = true
		waiting_for_player_card = false
		_set_bet_buttons_enabled(true)
		_highlight_bet_button(null, null)  # Make all buttons visible
		if has_node("Notif"):
			$Notif.text = "Your turn: choose one!"
			$Notif.visible = true
	else:
		input_enabled = false
		waiting_for_player_card = false
		_set_bet_buttons_enabled(false)
		_highlight_bet_button(null, null)  # Make all buttons visible but disabled
		await get_tree().create_timer(1.0).timeout
		await _rival_turn()

func _reset_selections():
	selected_stat = ""
	selected_direction = ""
	selected_player_index = -1
	revealed_rival_index = -1

	# Restore visibility of all bet buttons
	_highlight_bet_button(null, null)

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
		$Notif.text = "Rival chose %s %s. Pick a card!" % [
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
			result_text = "You win the card"
		else:
			result_text = "You lose the card"
		$Notif.text = "%s (Your %s: %d, Rival %s: %d, %ss)" % [
			result_text, stat.capitalize(), player_value, stat.capitalize(), rival_value, dir_str
		]
		$Notif.visible = true

	# Animate and update collection/win/loss tracking
	if outcome == "draw":
		await _animate_draw(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		player_card_data[selected_player_index]["lost"] = false
		rival_card_data[revealed_rival_index]["revealed"] = true
	elif outcome == "player_win":
		$Plop.play()
		await _animate_win(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		_add_card_to_collection(rival["card"], rival["effect"])
		cards_won.append({"card": rival["card"], "effect": rival["effect"]})
		player_card_data[selected_player_index]["lost"] = false
		rival_card_data[revealed_rival_index]["won"] = true
	elif outcome == "rival_win":
		$Badplop.play()
		await _animate_loss(player_cards[selected_player_index], rival_cards[revealed_rival_index])
		_remove_card_from_collection(player["card"], player["effect"], player["grading"])
		cards_lost.append({"card": player["card"], "effect": player["effect"], "grading": player["grading"]})
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
	if Global.collection.has(id_set) and Global.collection[id_set].has("cards"):
		var cards_array = Global.collection[id_set]["cards"]
		for card_instance in cards_array:
			var effect = card_instance.get("effect", "")
			if effect != "" and not effect in possible_effects:
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
		# Skip cards without "cards" array (might be old format entries)
		if not Global.collection[id_set].has("cards"):
			continue

		var cards_array = Global.collection[id_set]["cards"]
		if cards_array.is_empty() or not Global.cards.has(id_set):
			continue

		var card = Global.cards[id_set]

		# Add all unprotected card instances to selection pool
		for card_instance in cards_array:
			if card_instance.get("protection", 0) == 0:
				owned.append({
					"card": card,
					"effect": card_instance.get("effect", ""),
					"grading": card_instance.get("grading", Global.get_random_grading())
				})

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
		var grading = card_data["grading"]
		var card_instance = get_node(PLAYER_CARD_PATHS[i])
		player_cards.append(card_instance)
		player_card_data.append({
			"card": card,
			"effect": effect,
			"grading": grading,
			"lost": false
		})
		_show_card_face(card_instance, card, effect, grading)

func _show_card_face(card_node, card, effect, grading=8):
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
		var display_text = effect
		if grading > 0:
			display_text += " [%d]" % grading
		card_node.get_node("Panel/Info/effect").text = display_text
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
	$Flipcard.play()
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
	var grading = Global.get_random_grading()

	if not Global.collection.has(id_set):
		Global.collection[id_set] = {
			"cards": [],
			"deck": 0
		}

	# Add a new card instance with the effect and grading
	var card_instance = {
		"effect": effect,
		"grading": grading,
		"protection": 0
	}

	Global.collection[id_set]["cards"].append(card_instance)

func _remove_card_from_collection(card, effect="", grading=8):
	var id_set = card.get("id_set", card.get("id", ""))

	if Global.collection.has(id_set) and Global.collection[id_set].has("cards"):
		var cards_array = Global.collection[id_set]["cards"]

		# Find matching card instance to remove
		var index_to_remove = -1
		for i in range(cards_array.size()):
			var card_instance = cards_array[i]
			if card_instance.get("effect", "") == effect:
				# If it's a matching effect and either we don't care about grading or it has the right grading
				if grading <= 0 or card_instance.get("grading", 0) == grading:
					# Apply 1% chance of grading decrease if not removing it
					var rng = RandomNumberGenerator.new()
					rng.randomize()
					if rng.randf() <= 0.01:  # 1% chance
						var current_grading = card_instance.get("grading", 6)
						var new_grading = max(6, current_grading - 1)  # Minimum 6
						if current_grading != new_grading:
							card_instance["grading"] = new_grading
							print("Card grading decreased from %d to %d" % [current_grading, new_grading])
							return  # Don't remove the card, just decrease grading

					index_to_remove = i
					break

		# If a matching card was found, remove it
		if index_to_remove != -1:
			cards_array.remove_at(index_to_remove)

		# If no cards left, remove the entry
		if cards_array.is_empty():
			Global.collection.erase(id_set)

func _animate_card_selected(card_node):
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
	$Notif.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Notif.size = Vector2(1080,1920)
	$Notif.position = Vector2(0,0)
	Global.woncards += cards_won.size()
	Global.lostcards += cards_lost.size()
	var msg = ""
	if Global.train == 1 or Global.rounds == 0:
		msg = "Battle finished!\n"
		if Global.train == 0:
			msg += "You have won the duel and ¥500.\n"
			Global.money += 500
		msg += "\nYou have won %d cards and lost %d cards.\n" % [Global.woncards, Global.lostcards]

	else:
		msg = "Next turn!\nYou have won %d cards and lost %d cards.\n" % [Global.woncards, Global.lostcards]
	Global.save_data()
	if has_node("Notif"):
		$Notif.text = msg
		$Notif.visible = true
	if has_node("Panel"):
		$Panel.visible = false
	$End.visible = true
	await $End.pressed

func _on_hide_pressed() -> void:
	$FullCard.visible = false

func _on_end_pressed() -> void:
	$End.visible = false
