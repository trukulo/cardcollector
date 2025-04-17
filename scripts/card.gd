extends Control

var effect: String = "" # Effect of the card

func _ready() -> void:
	# Show or hide the Info panel and adjust Picture position
	if Global.info == true:
		$Panel/Info.visible = true
	else:
		$Panel/Info.visible = false

	# Update the card appearance based on the effect
	update_card_appearance()

# Setter for the effect variable
func set_effect(new_effect: String) -> void:
	effect = new_effect
	update_card_appearance()

# Getter for the effect variable
func get_effect() -> String:
	return effect

# Update the card's appearance based on the effect
func update_card_appearance() -> void:
	# Apply shaders based on the effect
	var shader_path = ""
	match effect:
		"Gold", "Full Gold":
			shader_path = "res://shaders/gold.gdshader"
		"Holo", "Full Holo":
			shader_path = "res://shaders/holo.gdshader"
		"Silver", "Full Silver":
			shader_path = "res://shaders/silver.gdshader"
		_:
			shader_path = ""  # No shader for other effects

	match effect:
		"Gold":
			$Panel/Info/Overlay.texture = load("res://gui/overlay_gold.png")
			$Panel/Info/Overlay.visible = true
		"Silver":
			$Panel/Info/Overlay.texture = load("res://gui/overlay_silver.png")
			$Panel/Info/Overlay.visible = true
		"Holo","":
			$Panel/Info/Overlay.texture = load("res://gui/overlay.png")
			$Panel/Info/Overlay.visible = true
		_:
			$Panel/Info/Overlay.visible = false

	if shader_path != "":
		var shader = load(shader_path)
		# Apply shader to Picture
		$Panel/Picture.material = ShaderMaterial.new()
		$Panel/Picture.material.shader = shader

		# Apply shader to Overlay only if the effect is not "Holo," "Silver," or "Gold"
		if effect not in ["Holo", "Silver", "Gold"]:
			$Panel/Info/Overlay.material = ShaderMaterial.new()
			$Panel/Info/Overlay.material.shader = shader
		else:
			$Panel/Info/Overlay.material = null  # Remove shader from Overlay
	else:
		$Panel/Picture.material = null  # Remove any existing shader
		$Panel/Info/Overlay.material = null  # Remove shader from Overlay

	# Adjust Picture position based on overlay visibility
	if $Panel/Info/Overlay.visible:
		$Panel/Picture.position.y = 100
	else:
		$Panel/Picture.position.y = 0

	# Set the colors of the red, blue, and yellow labels
	$Panel/Info/red.add_theme_color_override("font_color", Color8(135, 39, 39))    # Red: #872727

	$Panel/Info/blue.add_theme_color_override("font_color", Color8(59, 90, 109))   # Blue: #3b5a6d

	$Panel/Info/yellow.add_theme_color_override("font_color", Color8(197, 197, 56)) # Yellow: #c5c538

	# Hide set and rarity nodes
	$Panel/Info/set.visible = false
	$Panel/Info/rarity.visible = false

	if Global.info == false:
		$Panel/Info.visible = false

	# Update the border color based on stats
	update_border_color()

# Update the border color based on the card's stats
func update_border_color() -> void:
	var red = $Panel/Info/red.text.to_int()
	var blue = $Panel/Info/blue.text.to_int()
	var yellow = $Panel/Info/yellow.text.to_int()

	var border_color: Color

	# Determine the border color based on the rules
	if red > blue and red > yellow:
		border_color = Color(1, 0, 0)  # Red
	elif blue > red and blue > yellow:
		border_color = Color(0, 0, 1)  # Blue
	elif yellow > red and yellow > blue:
		border_color = Color(1, 1, 0)  # Yellow
	elif yellow == blue and yellow > red:
		border_color = Color(0, 1, 0)  # Green
	elif red == yellow and red > blue:
		border_color = Color(1, 0.5, 0)  # Orange
	elif red == blue and red > yellow:
		border_color = Color(0.5, 0, 0.5)  # Purple
	elif red == blue and blue == yellow:
		border_color = Color(1, 1, 1)  # White
	else:
		border_color = Color(0, 0, 0)  # Default (black)

	# Create a new StyleBoxFlat resource for this card instance
	var new_border_style = StyleBoxFlat.new()
	new_border_style.draw_center = false  # Make the inside transparent
	new_border_style.border_width_top = 16
	new_border_style.border_width_bottom = 16
	new_border_style.border_width_left = 16
	new_border_style.border_width_right = 16
	new_border_style.border_color = border_color
	new_border_style.corner_radius_top_left = 24
	new_border_style.corner_radius_top_right = 24
	new_border_style.corner_radius_bottom_left = 24
	new_border_style.corner_radius_bottom_right = 24

	# Apply the new StyleBoxFlat to the border
	$Panel/Info/border.add_theme_stylebox_override("panel", new_border_style)

	# Also make sure the Info panel background is transparent
	var info_style = StyleBoxFlat.new()
	info_style.draw_center = false
	$Panel/Info.add_theme_stylebox_override("panel", info_style)
