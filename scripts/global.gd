# global.gd
extends Node

var cards: Dictionary = {}
var prices: Dictionary = {}
var collection: Dictionary = {}

var money: int = 0
var money_spent: int = 0
var souls: int = 0
var last_connection: int = 0
var deck_names: Dictionary = { 0: "Out of deck" }
var selected_set: int = 1  # Último set seleccionado (por defecto 1)

var unlock: int = 0

var info: bool = true  # Default value is true
var savegame_name: String = ""

var audio_on: bool = true

var language: String = "en"

# --------------------
# SETS, EDITIONS, PRINTS
# --------------------
var set_editions: Dictionary = {}
var available_sets: Dictionary = {}
var train: int = 0
var rounds: int = 4
var woncards: int = 0
var lostcards: int = 0

# Variable to store the current booster type (Primes, Evens, Odds, Triples, or "")
var boostertype: String = ""

# Playtime tracking in seconds
var playtime: int = 0
var last_playtime_save: int = 0

# Function to set the booster type
func set_booster_type(type: String) -> void:
	boostertype = type

# Function to reset the booster type (will default to random Evens or Odds)
func reset_booster_type() -> void:
	boostertype = ""

func _ready():
	if info == false:
		savegame_name = "user://dataS.save"
	else:
		savegame_name = "user://data.save"

	collection = {}
	money = 10000  # Changed reset money to 10000
	souls = 0
	last_connection = Time.get_unix_time_from_system()

	# Reset deck names while preserving the default deck 0
	deck_names = { 0: "Out of deck" }

	# Reset any closed prints/sets to make all available again
	for set_id in range(1, 101):
		available_sets[set_id] = true

	# Generate cards dynamically every time
	generate_cards_with_seed(42)

	# Load only the player's collection and other saved data
	load_data()

	# Update money based on time
	update_money_by_time()

	# Initialize playtime tracking variables if they haven't been loaded yet
	if playtime == 0:
		playtime = 0
		last_playtime_save = Time.get_unix_time_from_system()

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
		"D": [1, 24], "C": [25, 49], "B": [50, 499],
		"A": [500, 999], "S": [1000, 4999], "X": [5000, 10000]
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

	# Collect all folder names first
	var folder_names = []
	dir.list_dir_begin()
	while true:
		var folder_name = dir.get_next()
		if folder_name == "":
			break
		if dir.current_is_dir() and not folder_name.begins_with("."):
			folder_names.append(folder_name)
	dir.list_dir_end()

	# Sort folders numerically
	folder_names.sort_custom(func(a, b): return a.to_int() < b.to_int())

	var set_index = 1
	for folder_name in folder_names:
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

		# Collect all card files, ignoring "png" and counting .import files
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
		# Deterministic shuffle using our rng
		for i in range(rarities.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var tmp = rarities[i]
			rarities[i] = rarities[j]
			rarities[j] = tmp

		# Sort card files numerically
		card_files.sort_custom(func(a, b):
			var a_num = a.get_basename().get_file().to_int()
			var b_num = b.get_basename().get_file().to_int()
			return a_num < b_num
		)

		# Assign rarities and generate cards
		for file_name in card_files:
			var id_set = "%s_%s" % [card_id, set_index]
			var rarity = rarities[(card_id - 1) % rarities.size()]
			var points = rarity_points[rarity]

			var stats = [0, 0, 0]
			for i in range(points):
				stats[rng.randi_range(0, 2)] += 1

			add_card(card_id, set_index, rarity, stats, rng)

			var base = rng.randf_range(base_price[rarity][0], base_price[rarity][1])
			var modifier = 1.0 + rng.randf_range(-0.99, 0.99)
			prices[id_set] = round(base * modifier * 100) / 100

			card_id += 1
		set_index += 1

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
# ADD AND REMOVE CARD
# --------------------
func add_card(id: int, set_id: int, rarity: String, stats: Array, rng: RandomNumberGenerator):
	var id_set = "%s_%s" % [id, set_id]
	cards[id_set] = {
		"id": id,
		"set": set_id,
		"id_set": id_set,
		"rarity": rarity,
		"red": stats[0],
		"blue": stats[1],
		"yellow": stats[2],
		"effect": "",
		"edition": set_editions.get(set_id, "Unknown Edition"),
		"image": "res://cards/%s/%s.jpg" % [set_id, id],
		"name": generate_card_name(rng)  # Generate and assign a name deterministically
	}

# --------------------
# CARD NAME GENERATION (DETERMINISTIC)
# --------------------
func generate_card_name(rng: RandomNumberGenerator) -> String:
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
	var syllable_count = rng.randi_range(2, 4)  # Generate names with 2 to 4 syllables
	for i in range(syllable_count):
		name += syllables[rng.randi() % syllables.size()]

	if info == false:
		name = ""

	# Capitalize the first letter
	return name.capitalize()

# --------------------
# COLLECTION FUNCTIONS (fixed)
# --------------------
func add_to_collection(id_set: String, amount: int, effect: String = "", deck: int = 0, grading: int = 7, protection: int = 0):
	if not collection.has(id_set):
		collection[id_set] = {
			"cards": [],
			"deck": 0
		}
	for i in range(amount):
		var card_instance = {"grading": grading, "effect": effect, "protection": protection}
		collection[id_set]["cards"].append(card_instance)


func remove_from_collection(id_set: String, effect: String = "", grading: int = -1, protection: int = -1):
	if collection.has(id_set) and collection[id_set].has("cards"):
		var cards_array = collection[id_set]["cards"]
		var index_to_remove := -1
		for i in range(cards_array.size()):
			var card = cards_array[i]
			var is_match = true
			if effect != "" and card.get("effect", "") != effect:
				is_match = false
			if grading != -1 and card.get("grading", -1) != grading:
				is_match = false
			if protection != -1 and card.get("protection", -1) != protection:
				is_match = false
			if is_match:
				index_to_remove = i
				break
		if index_to_remove != -1:
			cards_array.remove_at(index_to_remove)
		if cards_array.is_empty():
			collection.erase(id_set)

func get_amount(id_set: String) -> int:
	if collection.has(id_set) and collection[id_set].has("cards"):
		return collection[id_set]["cards"].size()
	return 0

func has_card_with_effect(id_set, effect):
	if not collection.has(id_set):
		return false
	if not collection[id_set].has("cards"):
		return false
	for card_instance in collection[id_set]["cards"]:
		if card_instance.get("effect", "") == effect:
			return true
	return false

func get_effect_count(id_set: String, effect: String) -> int:
	if not collection.has(id_set) or not collection[id_set].has("cards"):
		return 0

	var count = 0
	for card in collection[id_set]["cards"]:
		if card.get("effect", "") == effect:
			count += 1
	return count

func get_effects(id_set: String) -> Dictionary:
	if not collection.has(id_set) or not collection[id_set].has("cards"):
		return {}

	var effects = {}
	for card in collection[id_set]["cards"]:
		var effect = card.get("effect", "")
		if effect != "":
			if not effects.has(effect):
				effects[effect] = 0
			effects[effect] += 1
	return effects

# --------------------
# SAVE AND LOAD
# --------------------
func save_data():
	# Update playtime before saving
	update_playtime()

	# Save only the player's collection and other relevant data
	var f = FileAccess.open(savegame_name, FileAccess.WRITE)
	var data = {
		"collection": collection,
		"money": money,
		"souls": souls,
		"last_connection": int(Time.get_unix_time_from_system()),
		"deck_names": deck_names,
		"available_sets": available_sets,
		"selected_set": selected_set,  # Save the selected set
		"info": info,  # Save the info variable
		"unlock": unlock,
		"playtime": playtime,  # Save the playtime
		"last_playtime_save": int(last_playtime_save),  # Save the last timestamp
		"money_spent": money_spent,
		"audio_on": audio_on,
		"language": language
	}
	f.store_var(data)
	f.close()

func load_data():
	# Load only the player's collection and other relevant data
	if FileAccess.file_exists(savegame_name):
		var f = FileAccess.open(savegame_name, FileAccess.READ)
		var data = f.get_var()
		f.close()
		collection = data.get("collection", {})
		money = data.get("money", 10000)  # Changed default to 10000
		souls = data.get("souls", 0)
		last_connection = int(data.get("last_connection", Time.get_unix_time_from_system()))
		deck_names = data.get("deck_names", {0: "Out of deck"})
		available_sets = data.get("available_sets", {})
		selected_set = data.get("selected_set", 1)  # Cargar el set seleccionado o usar 1 por defecto
		info = data.get("info", true)  # Load the info variable
		unlock = data.get("unlock", 0)  # Load the unlock variable
		playtime = int(data.get("playtime", 0))  # Load the playtime, default to 0
		last_playtime_save = int(data.get("last_playtime_save", Time.get_unix_time_from_system()))
		money_spent = data.get("money_spent", 0)  # Load the money spent
		audio_on = data.get("audio_on", true)
		language = data.get("language", "en")
		TranslationServer.set_locale(language)
	else:
		collection = {}
		money = 10000
		souls = 0
		last_connection = Time.get_unix_time_from_system()
		deck_names = {0: "Out of deck"}
		available_sets = {}
		selected_set = 1
		playtime = 0
		last_playtime_save = Time.get_unix_time_from_system()
		unlock = 0
		money_spent = 0
		# Initialize available_sets as in reset_game
		for set_id in range(1, 101):
			available_sets[set_id] = true
		# Optionally, save immediately to create the save file
		generate_cards_with_seed(42)
		save_data()

# --------------------
# PASSIVE INCOME
# --------------------
func update_money_by_time():
	var now = Time.get_unix_time_from_system()
	var seconds_passed = now - last_connection
	var dollars_earned = int(seconds_passed / 30)  # Earn 1 dollar every 6000 seconds
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
	money = 10000  # Changed reset money to 10000
	souls = 0
	last_connection = Time.get_unix_time_from_system()
	unlock = 0

	# Reset deck names while preserving the default deck 0
	deck_names = { 0: "Out of deck" }

	# Reset any closed prints/sets to make all available again
	for set_id in range(1, 101):
		available_sets[set_id] = true

	# Re-generate cards with the same seed to ensure consistency
	generate_cards_with_seed(42)

	# Save the reset data
	save_data()

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
	var counts = {
		"total": rarity_counts,
		"unique": unique_counts
	}
	return counts

func get_collection_rarity_counts_string() -> String:
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

# ------------------
# RANDOM GRADING
# ------------------

func get_random_grading() -> int:
	var grades = [6, 7, 8, 9, 10]
	var weights = [10, 20, 50, 15, 5]
	var total = 0
	for w in weights:
		total += w
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var pick = rng.randi_range(1, total)
	var cumulative = 0
	for i in range(grades.size()):
		cumulative += weights[i]
		if pick <= cumulative:
			return grades[i]
	return 8 # Fallback, should never happen

# ------------------
# PROTECTION
# ------------------

func protect_card_instance(id_set: String, grading: int = -1, effect: String = "", protection_value: int = 1):
	if collection.has(id_set):
		for card in collection[id_set]["cards"]:
			if (grading == -1 or card.get("grading", -1) == grading) and (effect == "" or card.get("effect", "") == effect):
				card["protection"] = protection_value
				break  # Only protect the first match

# ------------------
# EFFECT MULTIPLIER
# ------------------

func get_effect_multiplier(effect: String) -> float:
	match effect:
		"Silver":
			return 1.5
		"Gold":
			return 2.0
		"Holo":
			return 2.5
		"Full Art":
			return 3.0
		"Full Silver":
			return 5.0
		"Full Gold":
			return 7.0
		"Full Holo":
			return 10.0
		_:
			return 1.0


func update_playtime():
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - last_playtime_save
	playtime += elapsed
	last_playtime_save = current_time

func format_playtime() -> String:
	var seconds = playtime % 60
	var minutes = int(playtime / 60) % 60
	var hours = int(playtime / 3600)
	return "%02d:%02d" % [hours, minutes]
