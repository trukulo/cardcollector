extends Control

var reset_dialog: ConfirmationDialog

func _ready() -> void:

	print(Global.collection.size())
	# Make sure Global data is loaded
	if not Global.cards.size():
		Global.generate_cards_with_seed(42)

	# Always load saved data
	Global.load_data()

	# Update money based on time passed since last connection
	Global.update_money_by_time()

	# Create and configure the Timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 60.0  # Update every 60 seconds
	timer.connect("timeout", _on_Timer_timeout)
	timer.start()

	# Initial update of the money label
	update_money_label()

	_unlock()

	Global.save_data()
	# Create the confirmation dialog if not already in the scene
	if not has_node("ResetDialog"):
		reset_dialog = ConfirmationDialog.new()
		reset_dialog.name = "ResetDialog"
		reset_dialog.dialog_text = "\nAre you sure you want to reset your game?\nThis cannot be undone.\n"
		reset_dialog.get_ok_button().text = "Yes"
		reset_dialog.get_cancel_button().text = "No"
		add_child(reset_dialog)
	else:
		reset_dialog = $ResetDialog

	reset_dialog.connect("confirmed", _on_reset_confirmed)

	if Global.unlock == 2 or Global.info == false:
		$VBoxContainer2/ButtonShortDuel.visible = false
	else:
		$VBoxContainer2/ButtonShortDuel.visible = true

	if Global.unlock == 3 or Global.info == false:
		$VBoxContainer2/ButtonDuels.visible = false
	else:
		$VBoxContainer2/ButtonDuels.visible = true

	if Global.unlock == 0:
		await _narrator("In the days when the earth was young and the heavens still whispered secrets to the mortals below, there were four dragons. Each was a sovereign of their domain, a keeper of the ancient balance, and their tales were woven into the very fabric of creation.")
		await _narrator("Tsuchi, the great worm with wings, who slumbered in the deepest chasms of the world. When he stirred, the earth itself trembled beneath his might. From the abyss he came, a creature of stone, his breath the rumble of mountains being born.")
		await _narrator("Mizu, the spirit of the flowing waters, whose coils embraced the rivers and whose dominion stretched across the endless oceans. Where she passed, the tides obeyed, and the rains sang her name.")
		await _narrator("Hi, born of the Sun’s own fire, a radiant and wrathful child of flame. His wings burned with the fury of noon, and his eyes held the unrelenting glare of the inferno. To gaze upon him was to know both warmth and destruction.")
		await _narrator("Kaze, the ever-watchful, whose domain was the boundless sky. She soared above all things, her form as fleeting as the wind, yet her presence was eternal. None could hide from her sight, for she rode the currents of the air, whispering secrets to the clouds.")
		await _enarrator("I am not sure what's going on here, I can't see... But I think this is a cards game. Could you try opening a Booster Pack? There, where it says Open Pack.")
		Global.unlock = 1
		Global.save_data()

func _on_Timer_timeout() -> void:
	Global.update_money_by_time()
	update_money_label()

func update_money_label() -> void:
	if has_node("MoneyLabel"):
		$MoneyLabel.text = "¥%d" % Global.money

func _on_open_booster_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/choose_booster.tscn")

func _on_button_collection_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/collection.tscn")

func _on_button_reset_pressed() -> void:
	reset_dialog.popup_centered()
	_ready()

func _on_reset_confirmed() -> void:
	Global.reset_game()
	update_money_label()
	$VBoxContainer2/ButtonDuels.visible = false
	$VBoxContainer2/ButtonShortDuel.visible = false
	# Optionally, you can update UI or notify the player here

func _on_button_decks_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/decks.tscn")

func _on_button_duels_pressed() -> void:
	if Global.collection.size() < 21:
		show_notification("You need at least 21 cards\nin your collection to play Duels!")
	else:
		Global.train = 0
		Global.rounds = 4
		Global.lostcards = 0
		Global.woncards = 0
		get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_button_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/memory.tscn")

func _on_button_quit_pressed() -> void:
	get_tree().quit()

# Helper function to show a notification (simple example)
func show_notification(msg: String) -> void:
	var notif = AcceptDialog.new()
	notif.dialog_text = msg
	add_child(notif)
	notif.popup_centered()

func _on_button_auction_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/auction.tscn")

func _on_button_short_duel_pressed() -> void:
	if Global.collection.size() < 5:
		show_notification("You need at least 5 cards\nin your collection to play Duels!")
	else:
		Global.train = 1
		Global.rounds = 5
		Global.lostcards = 0
		Global.woncards = 0
		get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _narrator(message: String) -> void:
	$Message/Label.text = message
	$Message/Narrator.texture = load("res://gui/narrador.png")
	$Message.visible = true
	await $Message/NoNarrator.pressed
	$Message.visible = false

func _enarrator(message: String) -> void:
	$Message/Label.text = message
	$Message/Narrator.texture = load("res://gui/enarrador.png")
	$Message.visible = true
	await $Message/NoNarrator.pressed
	$Message.visible = false

func _unlock() -> void:
	var total_cards = 0
	for amount in Global.collection.values():
		total_cards += amount

	#Unlocking
	if total_cards >= 5 and Global.unlock < 1:
		Global.unlock += 1
		_enarrator("You have unlocked Collection!")
	if total_cards >= 25 and Global.unlock < 2:
		Global.unlock += 1
		_enarrator("You have unlocked Decks!")
	if total_cards >= 50 and Global.unlock < 3:
		Global.unlock += 1
		_enarrator("You have unlocked a Memory Game!")
	if total_cards >= 100 and Global.unlock < 4:
		Global.unlock += 1
		_enarrator("You have unlocked a new set!")
	if total_cards >= 100 and Global.unlock < 5:
		Global.unlock += 1
		_enarrator("You have unlocked Duels and a new set!")
	if total_cards >= 200 and Global.unlock < 6:
		Global.unlock += 1
		_enarrator("You have unlocked Auctions and a new set!")
	if total_cards >= 300 and Global.unlock < 7:
		Global.unlock += 1
		_enarrator("You have unlocked Battles and new set!")
	if total_cards >= 400 and Global.unlock < 8:
		Global.unlock += 1
		_enarrator("You have unlocked Selling cards and new set!")
	if total_cards >= 500 and Global.unlock < 9:
		Global.unlock += 1
		_enarrator("You have unlocked Protecting cards and new set!")

	#Unlocked
	if Global.unlock < 1:
		$VBoxContainer/ButtonCollection.disabled = true
		$VBoxContainer/ButtonCollection.text = "Collection 🔒"
	if Global.unlock < 2:
		$VBoxContainer/ButtonDecks.disabled = true
		$VBoxContainer/ButtonDecks.text = "Decks 🔒"
	if Global.unlock < 3:
		$VBoxContainer2/ButtonPlay.disabled = true
		$VBoxContainer2/ButtonPlay.text = "Memory 🔒"
	if Global.unlock < 6:
		$VBoxContainer/ButtonAuction.disabled = true
		$VBoxContainer/ButtonAuction.text = "Auction 🔒"
	if Global.unlock < 5:
		$VBoxContainer2/ButtonShortDuel.disabled = true
		$VBoxContainer2/ButtonShortDuel.text = "Duel 🔒"
	if Global.unlock < 7:
		$VBoxContainer2/ButtonDuels.disabled = true
		$VBoxContainer2/ButtonDuels.text = "Battle 🔒"
