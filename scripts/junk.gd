extends Control

@onready var button_junk = $ButtonJunk
@onready var briefing_label = $Briefing

# Store calculated prices and indices for reuse
var cards_to_sell = []

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

				# Calculate selling price
				var base_price: float = Global.prices.get(id_set, 0.0)
				var multiplier: float = Global.get_effect_multiplier(effect)
				var grading_modifier: float = 0.2 * (1.3 ** (c["grading"] - 6))
				var sell_price: float = base_price * multiplier * grading_modifier

				# Final rounding
				sell_price = int(max(1, round(sell_price)))

				# Save the card's data for reuse during the sale
				cards_to_sell.append({
					"id_set": id_set,
					"index": entry.cards.find(c),
					"sell_price": sell_price
				})

				# Update preview totals
				preview_total_earned += sell_price
				preview_total_sold += 1

	# Update the briefing text
	briefing_label.text = "Ready to sell\n%d duplicates\n for %d coins?" % [preview_total_sold, round(preview_total_earned)]

func _on_button_junk_pressed() -> void:
	# Junk summary variables
	var total_sold: int = 0
	var total_earned: float = 0.0

	# Process the saved data from the preview
	for card_data in cards_to_sell:
		var id_set = card_data["id_set"]
		var index = card_data["index"]
		var sell_price = card_data["sell_price"]

		# Update money and counters
		Global.money += sell_price
		total_earned += sell_price
		total_sold += 1

		# Remove the card from the collection
		var entry = Global.collection[id_set]
		entry.cards.remove_at(index)

		# If we've removed all cards, clean up the entry
		if entry.cards.size() == 0:
			Global.collection.erase(id_set)

	# Save changes and update UI
	Global.save_data()
	briefing_label.text = "Sold %d duplicates\nfor %d coins" % [total_sold, round(total_earned)]
	button_junk.disabled = true

func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
