extends Control
@onready var button_junk = $ButtonJunk
@onready var briefing_label = $Briefing

# Store card references instead of indices
var cards_to_sell = []

func _ready():
	Global.load_data()
	button_junk.pressed.connect(_on_button_junk_pressed)
	
	var preview_total_sold: int = 0
	var preview_total_earned: float = 0.0
	
	for id_set in Global.collection.keys():
		var entry = Global.collection[id_set]
		if not entry.has("cards"):
			continue
		
		# Group cards by card identity (id_set already contains number_set, plus effect)
		var by_card_identity: Dictionary = {}
		for card in entry.cards:
			var effect: String = card["effect"]
			var card_identity: String = id_set + "_" + effect
			
			if not by_card_identity.has(card_identity):
				by_card_identity[card_identity] = []
			by_card_identity[card_identity].append(card)
		
		# Process each unique card identity group
		for card_identity in by_card_identity.keys():
			var group: Array = by_card_identity[card_identity]
			if group.size() <= 1:
				continue
			
			# Exclude protected cards
			var sellable: Array = group.filter(func(c): return c["protection"] == 0)
			if sellable.size() <= 1:
				continue
			
			# Find the highest grading value
			var max_grading: int = sellable[0]["grading"]
			for c in sellable:
				max_grading = max(max_grading, c["grading"])
			
			# Mark all but one of the highest graded cards for sale
			var kept_one: bool = false
			for c in sellable:
				if c["grading"] == max_grading and not kept_one:
					kept_one = true
					continue
				
				# Calculate selling price
				var effect: String = c["effect"]  # Get effect directly from card
				var base_price: float = Global.prices.get(id_set, 0.0)
				var multiplier: float = Global.get_effect_multiplier(effect)
				var grading_modifier: float = 0.2 * (1.3 ** (c["grading"] - 6))
				var sell_price: float = base_price * multiplier * grading_modifier
				sell_price = int(max(1, round(sell_price)))
				
				# Store card reference instead of index
				cards_to_sell.append({
					"id_set": id_set,
					"card_ref": c,  # Direct reference to card object
					"sell_price": sell_price
				})
				
				preview_total_earned += sell_price
				preview_total_sold += 1
	
	briefing_label.text = "Ready to sell\n%d duplicates\n for %d coins?" % [preview_total_sold, round(preview_total_earned)]

func _on_button_junk_pressed() -> void:
	var total_sold: int = 0
	var total_earned: float = 0.0
	
	# Process the saved data from the preview
	for card_data in cards_to_sell:
		var id_set = card_data["id_set"]
		var card_ref = card_data["card_ref"]
		var sell_price = card_data["sell_price"]
		
		# Find and remove the specific card instance
		var entry = Global.collection[id_set]
		var index = entry.cards.find(card_ref)
		
		if index != -1:  # Safety check
			# Update money and counters
			Global.money += sell_price
			total_earned += sell_price
			total_sold += 1
			
			# Remove the card from the collection
			entry.cards.remove_at(index)
			
			# If we've removed all cards, clean up the entry
			if entry.cards.size() == 0:
				Global.collection.erase(id_set)
	
	# Clear the cards_to_sell array for next use
	cards_to_sell.clear()
	
	# Save changes and update UI
	Global.save_data()
	briefing_label.text = "Sold %d duplicates\nfor %d coins" % [total_sold, round(total_earned)]
	button_junk.disabled = true

func _on_button_ok_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")