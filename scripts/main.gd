extends Control

var scene_choose_booster := preload("res://scenes/choose_booster.tscn")
var scene_collection := preload("res://scenes/collection.tscn")
var scene_decks := preload("res://scenes/decks.tscn")
var scene_battle := preload("res://scenes/battle.tscn")
var scene_memory := preload("res://scenes/memory.tscn")
var scene_auction := preload("res://scenes/auction.tscn")
var scene_short_duel := preload("res://scenes/battle.tscn") # Same as battle
var scene_sacrifice := preload("res://scenes/sacrifice.tscn")
var scene_junk := preload("res://scenes/junk.tscn")
var scene_cardview := preload("res://scenes/cardview.tscn")
var scene_gravity := preload("res://scenes/gravity.tscn")
var scene_sequence := preload("res://scenes/sequence.tscn")
var scene_slots := preload("res://scenes/slots.tscn")
var scene_settings := preload("res://scenes/settings.tscn")

func _ready() -> void:
	$VBoxContainer/OpenBooster.text = tr("Open Pack")
	$VBoxContainer/ButtonAuction.text = tr("Auction")
	$VBoxContainer/ButtonCollection.text = tr("Collection")
	$VBoxContainer/ButtonDecks.text = tr("Decks")
	$VBoxContainer/ButtonJunk.text = tr("Junk")
	$VBoxContainer/ButtonSacrifice.text = tr("Sacrifice")
	$VBoxContainer2/ButtonPlay.text = tr("Memory")
	$VBoxContainer2/ButtonGravity.text = tr("Gravity Mem")
	$VBoxContainer2/ButtonSequence.text = tr("Sequence")
	$VBoxContainer2/ButtonShortDuel.text = tr("Duel")
	$VBoxContainer2/ButtonDuels.text = tr("Battle")
	$VBoxContainer2/ButtonSlots.text = tr("Slots")
	$ButtonSettings.text = tr("Settings")
	$ButtonQuit.text = tr("Quit")

	print(tr("Colección size: %d") % Global.collection.size())
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
	$CardsAccount.text = tr("%d Cards") % get_total_card_count()

	Global.save_data()

	$Playtime.text = tr("Playtime: ") + Global.format_playtime()
	$MoneySpent.text = tr("Money spent: ¥%d") % Global.money_spent

	if Global.unlock == 0:
		await _narrator("In the days when the earth was young and the heavens still whispered secrets to the mortals below, there were four dragons. Each was a sovereign of their domain, a keeper of the ancient balance, and their tales were woven into the very fabric of creation.")
		await _narrator("Tsuchi, the great worm with wings, who slumbered in the deepest chasms of the world. When he stirred, the earth itself trembled beneath his might. From the abyss he came, a creature of stone, his breath the rumble of mountains being born.")
		await _narrator("Mizu, the spirit of the flowing waters, whose coils embraced the rivers and whose dominion stretched across the endless oceans. Where she passed, the tides obeyed, and the rains sang her name.")
		await _narrator("Hi, born of the Sun’s own fire, a radiant and wrathful child of flame. His wings burned with the fury of noon, and his eyes held the unrelenting glare of the inferno. To gaze upon him was to know both warmth and destruction.")
		await _narrator("Kaze, the ever-watchful, whose domain was the boundless sky. She soared above all things, her form as fleeting as the wind, yet her presence was eternal. None could hide from her sight, for she rode the currents of the air, whispering secrets to the clouds.")
		await _enarrator("This is a cards game. Could you try opening a Booster Pack? There, where it says Open Pack. The type of the booster means the type of cards you will get more frequently.")

		Global.unlock = 1
		Global.save_data()


func _on_Timer_timeout() -> void:
	Global.update_money_by_time()
	update_money_label()

func update_money_label() -> void:
	if has_node("MoneyLabel"):
		$MoneyLabel.text = "¥%d" % Global.money

func _on_open_booster_pressed() -> void:
	get_tree().change_scene_to_packed(scene_choose_booster)

func _on_button_collection_pressed() -> void:
	get_tree().change_scene_to_packed(scene_collection)

func _on_button_decks_pressed() -> void:
	get_tree().change_scene_to_packed(scene_decks)

func _on_button_duels_pressed() -> void:
	if Global.collection.size() < 21:
		show_notification(tr("You need at least 21 cards\nin your collection to play Duels!"))
	else:
		Global.train = 0
		Global.rounds = 4
		Global.lostcards = 0
		Global.woncards = 0
		get_tree().change_scene_to_packed(scene_battle)

func _on_button_play_pressed() -> void:
	get_tree().change_scene_to_packed(scene_memory)

func _on_button_quit_pressed() -> void:
	get_tree().quit()

# Helper function to show a notification (simple example)
func show_notification(msg: String) -> void:
	var notif = AcceptDialog.new()
	notif.dialog_text = msg
	add_child(notif)
	notif.popup_centered()

func _on_button_auction_pressed() -> void:
	get_tree().change_scene_to_packed(scene_auction)

func _on_button_short_duel_pressed() -> void:
	if Global.collection.size() < 5:
		show_notification(tr("You need at least 5 cards\nin your collection to play Duels!"))
	else:
		Global.train = 1
		Global.rounds = 5
		Global.lostcards = 0
		Global.woncards = 0
		get_tree().change_scene_to_packed(scene_short_duel)

func _narrator(message: String) -> void:
	$Message/Label.text = message
	$Message/Narrator.texture = load("res://gui/narrador.png")
	$Message.visible = true
	await $Message/NoNarrator.pressed
	$Message.visible = false

func _enarrator(message: String) -> void:
	$Message/Label.text = tr(message)
	$Message/Narrator.texture = load("res://gui/enarrador.png")
	$Message.visible = true
	await $Message/NoNarrator.pressed
	$Message.visible = false

func _unlock() -> void:
	var total_cards = 0
	for entry in Global.collection.values():
		total_cards += entry["cards"].size()

	# Unlocking
	if total_cards >= 5 and Global.unlock < 1:
		Global.unlock += 1
		_enarrator("You have unlocked the Collection!")
	if total_cards >= 25 and Global.unlock < 2:
		Global.unlock += 1
		_enarrator("You have unlocked Decks!")
	if total_cards >= 50 and Global.unlock < 3:
		Global.unlock += 1
		_enarrator("You have unlocked the Memory Game!")
	if total_cards >= 100 and Global.unlock < 4:
		Global.unlock += 1
		_enarrator("You have unlocked Gravity, Duels, and a new set!")
	if total_cards >= 150 and Global.unlock < 5:
		Global.unlock += 1
		_enarrator("You have unlocked Sequence, Reveal, and a new set!")
	if total_cards >= 200 and Global.unlock < 6:
		Global.unlock += 1
		_enarrator("You have unlocked Auctions and a new set!")
	if total_cards >= 300 and Global.unlock < 7:
		Global.unlock += 1
		_enarrator("You have unlocked Battles and a new set!")
	if total_cards >= 400 and Global.unlock < 8:
		Global.unlock += 1
		_enarrator("You have unlocked Selling cards and a new set!")
	if total_cards >= 500 and Global.unlock < 9:
		Global.unlock += 1
		_enarrator("You have unlocked Auction, Protecting cards, and a new set!")
	if total_cards >= 600 and Global.unlock < 10:
		Global.unlock += 1
		_enarrator("You have unlocked Sacrifice and a new set!")
	if total_cards >= 700 and Global.unlock < 11:
		Global.unlock += 1
		_enarrator("You have unlocked Slots and a new set!")
	if total_cards >= 800 and Global.unlock < 12:
		Global.unlock += 1
		_enarrator("You have unlocked a new set!")

	#Unlocked
	if Global.unlock < 1:
		$VBoxContainer/ButtonCollection.disabled = true
		$VBoxContainer/ButtonCollection.text = tr("Collection (L)")
	if Global.unlock < 2:
		$VBoxContainer/ButtonDecks.disabled = true
		$VBoxContainer/ButtonDecks.text = tr("Decks (L)")
	if Global.unlock < 3:
		$VBoxContainer2/ButtonPlay.disabled = true
		$VBoxContainer2/ButtonPlay.text = tr("Memory (L)")
	if Global.unlock < 9:
		$VBoxContainer/ButtonAuction.disabled = true
		$VBoxContainer/ButtonAuction.text = tr("Auction (L)")
	if Global.unlock < 6:
		$VBoxContainer2/ButtonSequence.disabled = true
		$VBoxContainer2/ButtonSequence.text = tr("Sequence (L)")
	if Global.unlock < 4:
		$VBoxContainer2/ButtonShortDuel.disabled = true
		$VBoxContainer2/ButtonShortDuel.text = tr("Duel (L)")
	if Global.unlock < 5:
		$VBoxContainer2/ButtonGravity.disabled = true
		$VBoxContainer2/ButtonGravity.text = tr("Gravity (L)")
	if Global.unlock < 7:
		$VBoxContainer2/ButtonDuels.disabled = true
		$VBoxContainer2/ButtonDuels.text = tr("Battle (L)")
	if Global.unlock < 8:
		$VBoxContainer/ButtonJunk.disabled = true
		$VBoxContainer/ButtonJunk.text = tr("Junk (L)")
	if Global.unlock < 10:
		$VBoxContainer/ButtonSacrifice.disabled = true
		$VBoxContainer/ButtonSacrifice.text = tr("Sacrifice (L)")

func get_total_card_count() -> int:
	var total = 0
	for set_data in Global.collection.values():
		for card in set_data["cards"]:
			# If you store a count property per card, use it:
			if card.has("count"):
				total += card["count"]
			else:
				total += 1
	return total


func _on_button_sacrifice_pressed() -> void:
	get_tree().change_scene_to_packed(scene_sacrifice)


func _on_ginme_pressed() -> void:
	Global.money += 1000
	update_money_label()
	Global.save_data()

func _on_button_junk_pressed() -> void:
	get_tree().change_scene_to_packed(scene_junk)


func _on_button_cards_pressed() -> void:
	get_tree().change_scene_to_packed(scene_cardview)


func _on_button_gravity_pressed() -> void:
	get_tree().change_scene_to_packed(scene_gravity)


func _on_button_sequence_pressed() -> void:
	get_tree().change_scene_to_packed(scene_sequence)

func _on_button_slots_pressed() -> void:
	get_tree().change_scene_to_packed(scene_slots)


func _on_button_settings_pressed() -> void:
	get_tree().change_scene_to_packed(scene_settings)
