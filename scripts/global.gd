# global.gd
extends Node

var cards: Dictionary = {}
var prices: Dictionary = {}
var collection: Dictionary = {}

var money: float = 0.0
var last_connection: int = 0
var deck_names: Dictionary = { 0: "Out of deck" }
var selected_set: int = 1  # Último set seleccionado (por defecto 1)
var info: bool = true  # Default value is true

# --------------------
# SETS, EDITIONS, PRINTS
# --------------------
var set_editions: Dictionary = {}
var available_sets: Dictionary = {}

func _ready():
	# Generate cards dynamically every time
	generate_cards_with_seed(42)
	
	# Load only the player's collection and other saved data
	load_data()
	
	# Update money based on time
	update_money_by_time()

# --------------------
# CARD GENERATION
# --------------------
func generate_cards_with_seed(seed: int = 12345):  # Default seed is 12345
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Define rarity probabilities (in percentages)
	var rarity_probabilities = {
		"D": 60,  # 60% of cards are "D"
		"C": 30,  # 30% of cards are "C"
		"B": 6,   # 6% of cards are "B"
		"A": 3,   # 3% of cards are "A"
		"S": 0.9, # 0.9% of cards are "S"
		"X": 0.1  # 0.1% of cards are "X"
	}

	var rarity_points = {"D": 9, "C": 11, "B": 13, "A": 15, "S": 17, "X": 19}
	var base_price = {
		"D": [0.01, 0.49], "C": [0.50, 0.99], "B": [1.0, 4.99],
		"A": [5.0, 9.99], "S": [10.0, 49.99], "X": [50.0, 100.0]
	}

	# Clear existing data
	cards.clear()
	prices.clear()
	set_editions.clear()
	available_sets.clear()

	# Iterate through folders in res://cards
	var dir = DirAccess.open("res://cards")
	if dir == null:
		print("Error: No se pudo abrir el directorio res://cards")
		return
	
	dir.list_dir_begin()
	var set_index = 1
	while true:
		var folder_name = dir.get_next()
		if folder_name == "":
			break
		if dir.current_is_dir() and not folder_name.begins_with("."):
			# Assign a name to the set
			var edition = "Edition %s" % folder_name.capitalize()
			set_editions[set_index] = edition
			available_sets[set_index] = true

			# Count the number of valid card images using .import files
			var card_dir = DirAccess.open("res://cards/" + folder_name)
			if card_dir == null:
				print("Error: No se pudo abrir el directorio res://cards/" + folder_name)
				continue
			
			card_dir.list_dir_begin()
			var card_id = 1
			var total_cards = 0
			var card_files = []

			# Collect all card files, ignoring "0.jpg" and counting .import files
			while true:
				var file_name = card_dir.get_next()
				if file_name == "":
					break
				if file_name.ends_with(".import") and file_name != "0.jpg.import":
					card_files.append(file_name)
					total_cards += 1
			card_dir.list_dir_end()

			# Calculate the number of cards for each rarity
			var rarities = []
			for rarity in rarity_probabilities.keys():
				var count = int(total_cards * (rarity_probabilities[rarity] / 100.0))
				for i in range(count):
					rarities.append(rarity)

			# Ensure at least one S and one X card
			if total_cards >= 2:
				rarities[0] = "S"  # Assign the first card as S
				rarities[1] = "X"  # Assign the second card as X

			# Fill remaining slots with the most common rarity ("D")
			while rarities.size() < total_cards:
				rarities.append("D")
			rarities.shuffle()

			# Assign rarities and generate cards
			for file_name in card_files:
				var id_set = "%s_%s" % [card_id, set_index]
				var rarity = rarities[(card_id - 1) % rarities.size()]
				var points = rarity_points[rarity]

				var stats = [0, 0, 0]
				for i in range(points):
					stats[rng.randi_range(0, 2)] += 1

				add_card(card_id, set_index, rarity, stats)

				var base = rng.randf_range(base_price[rarity][0], base_price[rarity][1])
				var modifier = 1.0 + rng.randf_range(-0.99, 0.99)
				prices[id_set] = round(base * modifier * 100) / 100

				card_id += 1
			set_index += 1
	dir.list_dir_end()

	# Print a summary of rarities for each set
	var set_rarity_summary = {}
	for card in cards.values():
		var current_set_id = card["set"]  # Renamed to avoid conflict
		var rarity = card["rarity"]
		if not set_rarity_summary.has(current_set_id):
			set_rarity_summary[current_set_id] = {"D": 0, "C": 0, "B": 0, "A": 0, "S": 0, "X": 0}
		set_rarity_summary[current_set_id][rarity] += 1

	for current_set_id in set_rarity_summary.keys():
		print("Set %d Summary:" % current_set_id)
		for rarity in ["D", "C", "B", "A", "S", "X"]:
			print("  %s: %d" % [rarity, set_rarity_summary[current_set_id][rarity]])

# --------------------
# ADD CARD
# --------------------
func add_card(id: int, set_id: int, rarity: String, stats: Array):
	var id_set = "%s_%s" % [id, set_id]
	cards[id_set] = {
		"id": id,
		"set": set_id,
		"id_set": id_set,
		"rarity": rarity,
		"grading": 10,
		"red": stats[0],
		"blue": stats[1],
		"yellow": stats[2],
		"effect": "",
		"edition": set_editions.get(set_id, "Unknown Edition"),
		"image": "res://cards/%s/%s.jpg" % [set_id, id],
		"name": generate_card_name()  # Generate and assign a name
	}

# --------------------
# COLLECTION
# --------------------
func add_to_collection(id_set: String, amount: int = 1, deck: int = 0, effect: String = "") -> void:
	if not collection.has(id_set):
		collection[id_set] = {"amount": 0, "deck": deck, "effects": {}}
	
	# Completely separate base cards and effect variants
	if effect == "":
		# Base card without effects
		collection[id_set]["amount"] += amount
	else:
		# Effect variant
		if not collection[id_set]["effects"].has(effect):
			collection[id_set]["effects"][effect] = 0
		collection[id_set]["effects"][effect] += amount
	
	collection[id_set]["deck"] = deck

# --------------------
# GET AMOUNT
# --------------------
func get_amount(id_set: String) -> int:
	if collection.has(id_set):
		return collection[id_set].get("amount", 0)
	return 0

# --------------------
# Has card with effect
# --------------------
# Function to check if a card with specific effect exists
func has_card_with_effect(id_set: String, effect: String) -> bool:
	if not collection.has(id_set):
		return false
	
	if effect == "":
		return collection[id_set]["amount"] > 0
	
	if not collection[id_set].has("effects"):
		return false
	
	return collection[id_set]["effects"].get(effect, 0) > 0

# Function to get the count of a specific card+effect combination
func get_effect_count(id_set: String, effect: String) -> int:
	if not collection.has(id_set):
		return 0
	
	if effect == "":
		return collection[id_set]["amount"]
	
	if not collection[id_set].has("effects"):
		return 0
	
	return collection[id_set]["effects"].get(effect, 0)	

# Function to get all effects for a card
func get_card_effects(id_set: String) -> Dictionary:
	if not collection.has(id_set) or not collection[id_set].has("effects"):
		return {}
	
	return collection[id_set]["effects"]

# --------------------
# SAVE AND LOAD
# --------------------
func save_data():
	# Save only the player's collection and other relevant data
	var f = FileAccess.open("user://data.save", FileAccess.WRITE)
	var data = {
		"collection": collection,
		"money": money,
		"last_connection": Time.get_unix_time_from_system(),
		"deck_names": deck_names,
		"available_sets": available_sets,
		"selected_set": selected_set,  # Save the selected set
		"info": info  # Save the info variable
	}
	f.store_var(data)
	f.close()

func load_data():
	# Load only the player's collection and other relevant data
	if FileAccess.file_exists("user://data.save"):
		var f = FileAccess.open("user://data.save", FileAccess.READ)
		var data = f.get_var()
		f.close()
		collection = data.get("collection", {})
		money = data.get("money", 50.0)  # Changed default to 50.0
		last_connection = data.get("last_connection", Time.get_unix_time_from_system())
		deck_names = data.get("deck_names", {0: "Out of deck"})
		available_sets = data.get("available_sets", {})
		selected_set = data.get("selected_set", 1)  # Cargar el set seleccionado o usar 1 por defecto
	else:
		# Initialize default values if no save file exists
		collection = {}
		money = 50.0  # Changed initial money to 50.0
		last_connection = Time.get_unix_time_from_system()
		deck_names = {0: "Out of deck"}
		available_sets = {}
		selected_set = 1

# --------------------
# PASSIVE INCOME
# --------------------
func update_money_by_time():
	var now = Time.get_unix_time_from_system()
	var seconds_passed = now - last_connection
	var dollars_earned = int(seconds_passed / 1200)  # Earn 1 dollar every 1200 seconds
	money += dollars_earned
	last_connection = now
	save_data()  # Save the updated money and last connection time

# --------------------
# SEARCH AND FILTERS
# --------------------
func search_by_rarity(rarity: String) -> Array:
	return cards.values().filter(func(c): return c["rarity"] == rarity)

func search_by_price(min_price: float, max_price: float) -> Array:
	return cards.values().filter(func(c):
		var id_set = c["id_set"]
		return prices.has(id_set) and prices[id_set] >= min_price and prices[id_set] <= max_price)

func filter_by_set(set_num: int) -> Array:
	return cards.values().filter(func(c): return c["set"] == set_num)

func filter_by_deck(deck: int) -> Array:
	var result: Array = []
	for id_set in collection:
		var entry = collection[id_set]
		if entry["deck"] == deck and cards.has(id_set):
			var card = cards[id_set].duplicate()
			card["amount"] = entry["amount"]
			card["deck"] = deck
			result.append(card)
	return result

func filter_out_of_deck() -> Array:
	var result: Array = []
	for id_set in collection:
		if collection[id_set]["deck"] == 0 and cards.has(id_set):
			var card = cards[id_set].duplicate()
			card["amount"] = collection[id_set]["amount"]
			card["deck"] = 0
			result.append(card)
	return result

func move_deck(from_deck: int, to_deck: int):
	for id_set in collection:
		if collection[id_set]["deck"] == from_deck:
			collection[id_set]["deck"] = to_deck

func clear_deck(deck: int):
	for id_set in collection:
		if collection[id_set]["deck"] == deck:
			collection[id_set]["deck"] = 0

# --------------------
# DECK NAMES
# --------------------
func rename_deck(deck_id: int, new_name: String) -> void:
	if deck_id <= 0:
		return
	deck_names[deck_id] = new_name

func get_deck_name(deck_id: int) -> String:
	return deck_names.get(deck_id, "Deck " + str(deck_id))

func get_all_deck_names() -> Dictionary:
	return deck_names.duplicate()

# --------------------
# PRINT CONTROL
# --------------------
func is_print_active(set_id: int) -> bool:
	return available_sets.get(set_id, false)

func close_print(set_id: int):
	available_sets[set_id] = false
	save_data()

func open_print(set_id: int):
	available_sets[set_id] = true
	save_data()

# --------------------
# RESET GAME
# --------------------
func reset_game():
	# Clear all player data
	collection = {}
	money = 50.0  # Changed reset money to 50.0
	last_connection = Time.get_unix_time_from_system()
	
	# Reset deck names while preserving the default deck 0
	deck_names = { 0: "Out of deck" }
	
	# Reset any closed prints/sets to make all available again
	for set_id in range(1, 101):
		available_sets[set_id] = true
	
	# Re-generate cards with the same seed to ensure consistency
	generate_cards_with_seed()
	
	# Save the reset data
	save_data()
	
	# You might want to add any additional reset functionality here
	# For example, resetting other game state variables that aren't shown in the code

# --------------------
# COLLECTION STATS
# --------------------
func get_collection_rarity_counts() -> Dictionary:
	var rarity_counts = {
		"D": 0, "C": 0, "B": 0, "A": 0, "S": 0, "X": 0
	}
	
	var unique_counts = {
		"D": 0, "C": 0, "B": 0, "A": 0, "S": 0, "X": 0
	}
	
	for id_set in collection:
		if cards.has(id_set):
			var rarity = cards[id_set]["rarity"]
			var amount = collection[id_set]["amount"]
			
			if rarity_counts.has(rarity):
				# Add total count
				rarity_counts[rarity] += amount
				
				# Add 1 to unique count (since this is one unique card regardless of amount)
				unique_counts[rarity] += 1
	
	# Return both total and unique counts
	return {"total": rarity_counts, "unique": unique_counts}
	
func get_collection_rarity_summary() -> String:
	var counts = get_collection_rarity_counts()
	return "D: %s (%s)\nC: %s (%s)\nB: %s (%s)\nA: %s (%s)\nS: %s (%s)\nX: %s (%s)" % [
		counts["total"]["D"], counts["unique"]["D"],
		counts["total"]["C"], counts["unique"]["C"], 
		counts["total"]["B"], counts["unique"]["B"],
		counts["total"]["A"], counts["unique"]["A"],
		counts["total"]["S"], counts["unique"]["S"],
		counts["total"]["X"], counts["unique"]["X"]
	]

# --------------------
# SELECTED SET
# --------------------
func save_selected_set():
	# Guardar el set seleccionado en un archivo
	var f = FileAccess.open("user://selected_set.save", FileAccess.WRITE)
	f.store_var(selected_set)
	f.close()

func load_selected_set():
	# Cargar el set seleccionado desde un archivo
	if FileAccess.file_exists("user://selected_set.save"):
		var f = FileAccess.open("user://selected_set.save", FileAccess.READ)
		selected_set = f.get_var()
		f.close()
	else:
		selected_set = 1  # Valor por defecto si no existe el archivo

# --------------------
# CARD NAME GENERATION
# --------------------
# Function to generate a random card name
func generate_card_name() -> String:
	var syllables = [
		"ka", "ki", "ku", "ke", "ko",
		"sa", "shi", "su", "se", "so",
		"ta", "chi", "tsu", "te", "to",
		"na", "ni", "nu", "ne", "no",
		"ha", "hi", "fu", "he", "ho",
		"ma", "mi", "mu", "me", "mo",
		"ya", "yu", "yo",
		"ra", "ri", "ru", "re", "ro",
		"wa", "wo", "ga", "gi", "gu", "ge", "go",
		"za", "ji", "zu", "ze", "zo", "da", "de", "do",
		"ba", "bi", "bu", "be", "bo", "pa", "pi", "pu", "pe", "po",
		"ryu", "kyo", "sho", "cho", "jin", "kai", "zan", "mei", "rei", "ken"
	]
	
	var name = ""
	var syllable_count = randi_range(2, 4)  # Generate names with 2 to 4 syllables
	for i in range(syllable_count):
		name += syllables[randi() % syllables.size()]
	
	# Capitalize the first letter
	return name.capitalize()
