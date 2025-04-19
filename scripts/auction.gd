extends Control

var auction_card = null
var auction_effect = ""
var auction_grading = 8  # Will be randomized for each auction
var market_price = 0
var bid_price = 0
var timer = 59
var timer_running = false
var player_is_winner = false
var player_bid_active = false

func _ready():
	randomize()
	pick_auction_card()
	update_prices()
	update_ui()
	start_timer()

func pick_auction_card():
	# Get all cards and effects not in player's collection
	var not_owned = []
	for id_set in Global.cards.keys():
		var card = Global.cards[id_set]
		var effects = ["", "Full Art", "Silver", "Gold", "Holo", "Full Silver", "Full Gold", "Full Holo"]
		for effect in effects:
			if not Global.has_card_with_effect(id_set, effect):
				not_owned.append({"id_set": id_set, "effect": effect})
	if not_owned.size() == 0:
		# fallback: pick any card
		var id_set = Global.cards.keys()[randi() % Global.cards.size()]
		auction_card = Global.cards[id_set]
		auction_effect = ""
	else:
		var pick = not_owned[randi() % not_owned.size()]
		auction_card = Global.cards[pick["id_set"]]
		auction_effect = pick["effect"]

	# Assign a random grading for this auction card
	auction_grading = Global.get_random_grading()

	# Set up the card node
	var card_node = $Card

	$CardInfo.text = "Set %s, Rarity %s, Grading %d" % [
		str(auction_card.get("set", "")),
		auction_card.get("rarity", ""),
		auction_grading
	]
	if card_node.has_node("Panel/Info/red"):
		card_node.get_node("Panel/Info/red").text = str(auction_card.get("red", 0))
	if card_node.has_node("Panel/Info/blue"):
		card_node.get_node("Panel/Info/blue").text = str(auction_card.get("blue", 0))
	if card_node.has_node("Panel/Info/yellow"):
		card_node.get_node("Panel/Info/yellow").text = str(auction_card.get("yellow", 0))

	if card_node.has_method("set_effect"):
		card_node.set_effect(auction_effect)
	if card_node.has_node("Panel/Info/name"):
		card_node.get_node("Panel/Info/name").text = auction_card.get("name", "Unknown").to_upper()
	if card_node.has_node("Panel/Info/number"):
		card_node.get_node("Panel/Info/number").text = str(auction_card.get("id", 0))
	if card_node.has_node("Panel/Picture"):
		var image_path = auction_card.get("image", "")
		if ResourceLoader.exists(image_path):
			card_node.get_node("Panel/Picture").texture = load(image_path)
		else:
			card_node.get_node("Panel/Picture").texture = null
	if card_node.has_node("Grading"):
		card_node.get_node("Grading").text = "Grade: %d" % auction_grading

func get_effect_multiplier(effect):
	match effect:
		"Silver": return 2.0
		"Gold": return 3.0
		"Holo": return 4.0
		"Full Art": return 5.0
		"Full Silver": return 6.0
		"Full Gold": return 8.0
		"Full Holo": return 10.0
		_: return 1.0

func update_prices():
	var id_set = auction_card["id_set"]
	var base_price = Global.prices.get(id_set, 100)
	var effect_multiplier = get_effect_multiplier(auction_effect)
	market_price = int(base_price * effect_multiplier * (0.2 * (2.7 ** (auction_grading - 6))))
	bid_price = int(market_price * (0.5 + randf() * 0.2)) # Start at 50-70% of market price

func update_ui():
	$MarketPrice.text = "Market Price ¥%d" % market_price
	$BidPrice.text = "Bid Price ¥%d" % bid_price
	$Tempo.text = str(timer)
	var enough_money = Global.money >= int(bid_price * 1.1)
	$Bid.visible = enough_money
	$Bid2.visible = Global.money >= int(bid_price * 1.2)
	$Notif.visible = false
	# Color BidPrice green if player is winning
	if player_is_winner:
		$BidPrice.add_theme_color_override("font_color", Color(0, 1, 0)) # green
	else:
		$BidPrice.add_theme_color_override("font_color", Color(1, 1, 1)) # white

func start_timer():
	timer_running = true
	player_is_winner = false # Computer is winning at the start
	_tick_timer()

func _tick_timer():
	if not timer_running:
		return
	$Tempo.text = str(timer)
	if timer <= 0:
		if player_bid_active:
			$Notif.visible = true
			$Notif/Label.text = "Bid in progress!"
			await get_tree().create_timer(1.0).timeout
			$Notif.visible = false
			timer = 1 # Give one more second for the auction
			player_bid_active = false
			update_ui()
			_tick_timer()
			return
		timer_running = false
		finish_auction()
		return
	# AI may bid
	ai_bid_logic()
	timer -= 1
	update_ui()
	player_bid_active = false # Reset after each tick
	await get_tree().create_timer(1.0).timeout
	_tick_timer()

func ai_bid_logic():
	if bid_price < int(market_price * 1.3):
		# 10% chance to bid +10%
		if randf() < 0.10:
			bid_price = max(int(bid_price * 1.1), bid_price + 1)
			player_is_winner = false
	else:
		var roll = randf()
		if roll < 0.01:
			# 1% chance for +20%
			bid_price = max(int(bid_price * 1.2), bid_price + 1)
			player_is_winner = false
		elif roll < 0.06:
			# Next 5% chance for +10%
			bid_price = max(int(bid_price * 1.1), bid_price + 1)
			player_is_winner = false
		# else: no bid this second

func _on_bid_pressed():
	var new_bid = max(int(bid_price * 1.1), bid_price + 1)
	if Global.money >= new_bid:
		bid_price = new_bid
		player_is_winner = true
		player_bid_active = true
		update_ui()
		reset_player_bid_active() # Start the cooldown

func _on_bid_2_pressed():
	var new_bid = max(int(bid_price * 1.2), bid_price + 1)
	if Global.money >= new_bid:
		bid_price = new_bid
		player_is_winner = true
		player_bid_active = true
		update_ui()
		reset_player_bid_active() # Start the cooldown

func finish_auction():
	$Notif.visible = true
	if player_is_winner and Global.money >= bid_price:
		$Notif/Label.text = "Congratulations! You won the auction!\nFinal Price: ¥%d" % bid_price
		Global.money -= bid_price
		# Add to collection with grading and effect!
		Global.add_to_collection(auction_card["id_set"], 1, auction_effect, 0, auction_grading, 0)
		Global.save_data()
	else:
		$Notif/Label.text = "You lost the auction!\nFinal Price: ¥%d" % bid_price
	$Bid.visible = false
	$Bid2.visible = false
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_home_pressed():
	if player_bid_active:
		$Notif.visible = true
		$Notif/Label.text = "You can't leave with an active bid!"
		await get_tree().create_timer(1.0).timeout
		$Notif.visible = false
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func reset_player_bid_active():
	await get_tree().create_timer(1.0).timeout
	player_bid_active = false
