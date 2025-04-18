extends Control

var reset_dialog: ConfirmationDialog

func _ready() -> void:
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

	if Global.collection.size() < 5 or Global.info == false:
		$VBoxContainer2/ButtonDuels.visible = false
	else:
		$VBoxContainer2/ButtonDuels.visible = true

	if Global.collection.size() < 21 or Global.info == false:
		$VBoxContainer2/ButtonShortDuel.visible = false
	else:
		$VBoxContainer2/ButtonShortDuel.visible = true


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

func _on_reset_confirmed() -> void:
	Global.reset_game()
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
