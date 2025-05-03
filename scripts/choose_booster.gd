extends Control

# Booster types with their corresponding image numbers and prices
var booster_types = {
	"Primes": {"image": "1", "price": 800},
	"Evens": {"image": "2", "price": 1100},
	"Odds": {"image": "5", "price": 1000},
	"Triples": {"image": "3", "price": 900}
}

# List of booster type names for easy cycling
var booster_type_names = ["Primes", "Evens", "Odds", "Triples"]
# Current index in the booster_type_names array
var current_booster_index = 0
# Total number of available boosters (sets × types)
var total_boosters = 0
# Current absolute index in the combined set/type space
var current_absolute_index = 0

func _ready():
	# Ensure data is loaded
	Global.load_data()

	# Limit the selected set to the allowed range
	var max_set = max(1, Global.unlock - 2)

	# Calculate total available boosters
	total_boosters = max_set * booster_type_names.size()

	# Initialize booster type if not set
	if not "boostertype" in Global:
		Global.boostertype = "Primes"  # Default booster type

	# Force start on Set 1
	Global.selected_set = 1

	# Calculate current absolute index from set 1 and booster type
	current_booster_index = booster_type_names.find(Global.boostertype)
	if current_booster_index == -1:
		current_booster_index = 0
		Global.boostertype = "Primes"

	current_absolute_index = current_booster_index  # because set 1 means (set-1)*4 = 0

	Global.save_data()
	update_display()

	if Global.info == false and has_node("BoosterTemplate"):
		$BoosterTemplate.visible = false

func update_collection_labels():
	# Update set collection status
	if has_node("Collection"):
		var total_cards_in_set = 0
		var owned_cards_in_set = 0

		for card in Global.cards.values():
			if card["set"] == Global.selected_set:
				total_cards_in_set += 1
				var id_set = card["id_set"]
				if Global.get_amount(id_set) > 0:
					owned_cards_in_set += 1

func _on_button_right_pressed() -> void:
	# Move to next booster (next type or next set)
	current_absolute_index += 1
	if current_absolute_index >= total_boosters:
		current_absolute_index = 0

	# Calculate new set and booster type
	update_set_and_type_from_index()
	Global.save_data()
	update_display()

func _on_button_left_pressed() -> void:
	# Move to previous booster (previous type or previous set)
	current_absolute_index -= 1
	if current_absolute_index < 0:
		current_absolute_index = total_boosters - 1

	# Calculate new set and booster type
	update_set_and_type_from_index()
	Global.save_data()
	update_display()

func update_set_and_type_from_index():
	# Calculate set and booster type from absolute index
	var types_per_set = booster_type_names.size()
	Global.selected_set = (current_absolute_index / types_per_set) + 1
	current_booster_index = current_absolute_index % types_per_set
	Global.boostertype = booster_type_names[current_booster_index]

func update_display():
	# Update all UI elements based on current selection
	update_open_booster_button()
	update_collection_labels()
	update_booster_type_label()
	update_price_label()
	check_booster_availability()

func update_booster_type_label():
	# Update the booster type text
	if has_node("BoosterTemplate/type"):
		$BoosterTemplate/type.text = Global.boostertype

	# Update the title as requested
	if has_node("BoosterTemplate/title"):
		$BoosterTemplate/title.text = Global.boostertype

func update_price_label():
	# Update the price label based on the booster type
	if has_node("Price"):
		var price = booster_types[Global.boostertype]["price"]
		$Price.text = "Price: ¥" + str(price)

func update_open_booster_button():
	# Update the button texture with the selected set's image
	var set_folder = "res://cards/" + str(Global.selected_set)

	# Get the image number from the booster type name
	var image_number = booster_types[Global.boostertype]["image"]
	var image_path = set_folder + "/" + image_number + ".jpg"

	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		# Set all button states to use the same texture
		if has_node("ButtonOpenBooster"):
			$ButtonOpenBooster.texture_normal = texture
			$ButtonOpenBooster.texture_hover = texture
			$ButtonOpenBooster.texture_pressed = texture
			$ButtonOpenBooster.texture_disabled = texture
			$ButtonOpenBooster.texture_focused = texture

		# Update the set number in BoosterTemplate/set
		if has_node("BoosterTemplate/set"):
			$BoosterTemplate/set.text = "Set " + str(Global.selected_set)
	else:
		print("Error: No se encontró la imagen para el set " + str(Global.selected_set) + " tipo " + Global.boostertype)

func check_booster_availability():
	# Get the current day of the month
	var current_day = Time.get_datetime_dict_from_system()["day"]


	# Determine which booster types are available
	var available_types = []
	if is_prime(current_day):
		available_types.append("Primes")
	if current_day % 2 == 0:
		available_types.append("Evens")
	if current_day % 2 != 0:
		available_types.append("Odds")
	if current_day % 3 == 0:
		available_types.append("Triples")

	# available_types = ["Primes", "Evens", "Odds", "Triples"]  # Uncomment this line to enable all types

	# Check if the current booster type is available
	if Global.boostertype in available_types:
		if has_node("OutStock"):
			$OutStock.visible = false
		if has_node("ButtonOpenBooster"):
			$ButtonOpenBooster.disabled = false
	else:
		if has_node("OutStock"):
			$OutStock.visible = true
		if has_node("ButtonOpenBooster"):
			$ButtonOpenBooster.disabled = true

func is_prime(num: int) -> bool:
	if num <= 1:
		return false
	if num <= 3:
		return true
	if num % 2 == 0 or num % 3 == 0:
		return false
	var i = 5
	while i * i <= num:
		if num % i == 0 or num % (i + 2) == 0:
			return false
		i += 6
	return true

func _on_button_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_open_booster_pressed() -> void:
	# Open the booster pack if the player has enough money
	var price = booster_types[Global.boostertype]["price"]
	if Global.money >= price:
		Global.money -= price  # Deduct the cost of the booster pack
		Global.money_spent += price  # Track the money spent
		Global.save_data()  # Save the remaining money
		get_tree().change_scene_to_file("res://scenes/openbooster.tscn")
	else:
		print("No tienes suficiente dinero para abrir un sobre.")
		# Show a message to the user if desired
		if has_node("NotMoney"):
			$NotMoney.visible = true
			await get_tree().create_timer(1.0).timeout
			$NotMoney.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_left"):
		_on_button_left_pressed()
	elif event.is_action_pressed("ui_right"):
		_on_button_right_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_on_button_home_pressed()
	elif event.is_action_pressed("ui_accept"):
		_on_button_open_booster_pressed()
