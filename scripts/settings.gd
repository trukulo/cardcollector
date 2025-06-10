extends Control

var reset_dialog: ConfirmationDialog
var audio_on := true
var language

func _ready() -> void:
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

	# Set audio button text based on current mute state and saved setting
	var master_idx = AudioServer.get_bus_index("Master")
	Global.load_data() # Ensure audio_on is loaded
	audio_on = Global.audio_on
	AudioServer.set_bus_mute(master_idx, not audio_on)
	if has_node("ButtonAudio"):
		$ButtonAudio.text = tr("Audio: ON") if audio_on else tr("Audio: OFF")

	# Load language from Global if available
	Global.load_data()
	if "language" in Global:
		language = Global.language
	else:
		language = "es"
	TranslationServer.set_locale(language)
	if has_node("ButtonLanguage"):
		$ButtonLanguage.text = tr("Idioma: Español") if language == "es" else tr("Language: English")
	if has_node("ButtonOk"):
		$ButtonOk.text = tr("CLOSE")
	if has_node("ButtonReset"):
		$ButtonReset.text = tr("Reset Game")

func _on_button_reset_pressed() -> void:
	reset_dialog.popup_centered()
	_ready()

func _on_reset_confirmed() -> void:
	Global.reset_game()
	Global.playtime = 0
	Global.money_spent = 0
	Global.save_data()
	# You may want to update UI or labels here as needed


func _on_button_audio_pressed() -> void:
	audio_on = not audio_on
	Global.audio_on = audio_on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not audio_on)
	if has_node("ButtonAudio"):
		$ButtonAudio.text = tr("Audio: ON") if audio_on else tr("Audio: OFF")
	Global.save_data()


func _on_button_language_pressed() -> void:
	# Toggle language
	language = "en" if language == "es" else "es"
	Global.language = language
	TranslationServer.set_locale(language)
	Global.save_data()
	# Force UI update for all visible text
	get_tree().reload_current_scene()


func _on_button_ok_pressed() -> void:
	Global.save_data()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
