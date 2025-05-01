extends Control

@onready var button_junk = $ButtonJunk
@onready var briefing_label = $Briefing

func _ready():
	# Ensure data is up to date
	Global.load_data()
	# Connect the "Junk" button
	button_junk.pressed.connect(_on_button_junk_pressed)

	# Preview summary variables
	var preview_total_sold: int = 0
	var preview_total_earned: float = 0.0

	# Simulate the junk operation to update the briefing
	for id_set in Global.collection.keys():
		var entry = Global.collection[id_set]
		if not entry.has("cards"):
			continue

		# Group cards by both card set ID and effect to properly identify unique cards
		var by_card_identity: Dictionary = {}
		for card in entry.cards:
			var effect: String = card["effect"]
			# Create a unique identifier combining the card set ID and effect
			var card_identity: String = id_set + "_" + effect

			if not by_card_identity.has(card_identity):
				by_card_identity[card_identity] = []
			by_card_identity[card_identity].append(card)

		# Process each unique card identity group
		for card_identity in by_card_identity.keys():
			var group: Array = by_card_identity[card_identity]
			# Only process if there are duplicates
			if group.size() <= 1:
				continue

			# Exclude protected cards
			var sellable: Array = group.filter(func(c):
				return c["protection"] == 0
			)
			if sellable.size() <= 1:
				continue

			# Find the highest grading value
			var max_grading: int = sellable[0]["grading"]
			for c in sellable:
				max_grading = max(max_grading, c["grading"])

			# Sell all but one of the highest graded cards
			var kept_one: bool = false
			for c in sellable:
				if c["grading"] == max_grading and not kept_one:
					kept_one = true
					continue

				# Extract effect from the card identity
				var effect: String = card_identity.split("_", true, 1)[1]

				# Calculate selling price: base price × effect multiplier
				var base_price: float = Global.prices.get(id_set, 0.0)
				var multiplier: float = Global.get_effect_multiplier(effect)
				var sell_price: float = base_price * multiplier

				preview_total_earned += sell_price
				preview_total_sold += 1

	# Update the briefing text
	briefing_label.text = "Ready to sell\n%d duplicates\n for %d coins?" % [preview_total_sold, round(preview_total_earned)]

func _on_button_junk_pressed() -> void:
	# Junk summary variables
	var total_sold: int = 0
	var total_earned: float = 0.0

	# Process each card set in the collection
	for id_set in Global.collection.keys():
		var entry = Global.collection[id_set]
		if not entry.has("cards") or entry.cards.size() <= 1:
			continue

		# Group cards by effect to identify unique cards
		var by_card_identity: Dictionary = {}
		for i in range(entry.cards.size()):
			var card = entry.cards[i]
			var effect: String = card["effect"]

			# Create a unique identifier combining the effect
			var card_identity: String = effect

			if not by_card_identity.has(card_identity):
				by_card_identity[card_identity] = []

			# Store card with its index in the original array
			by_card_identity[card_identity].append({"card": card, "index": i})

		# Process each unique card type group
		var cards_to_remove_indices = []

		for effect in by_card_identity.keys():
			var group = by_card_identity[effect]

			# Only process if there are duplicates
			if group.size() <= 1:
				continue

			# Filter out protected cards
			var sellable = group.filter(func(item):
				return item.card["protection"] == 0
			)

			if sellable.size() <= 1:
				continue

			# Find highest grading value among sellable cards
			var max_grading = -1
			for item in sellable:
				max_grading = max(max_grading, item.card["grading"])

			# Sell all but one of the highest graded cards
			var kept_one = false
			for item in sellable:
				if item.card["grading"] == max_grading and not kept_one:
					kept_one = true
					continue

				# Calculate selling price
				var base_price: float = Global.prices.get(id_set, 0.0)
				var multiplier: float = Global.get_effect_multiplier(effect)
				var sell_price: float = base_price * multiplier

				# Update money and counters
				Global.money += sell_price
				total_earned += sell_price
				total_sold += 1

				# Track the index to remove later
				cards_to_remove_indices.append(item.index)

		# Sort indices in descending order to safely remove from end to beginning
		cards_to_remove_indices.sort_custom(func(a, b): return a > b)

		# Now remove cards by index
		for idx in cards_to_remove_indices:
			entry.cards.remove_at(idx)

		# If we've removed all cards, clean up the entry
		if entry.cards.size() == 0:
			entry.erase("cards")

	# Save changes and update UI
	Global.save_data()
	briefing_label.text = "Sold %d duplicates\nearned %d coins" % [total_sold, round(total_earned)]
	button_junk.disabled = true

func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
