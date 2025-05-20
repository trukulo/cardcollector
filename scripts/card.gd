extends Control

var effect: String = "" # Effect of the card
var protection: int = 0 # Protection status of the card

func _ready() -> void:
	# Show or hide the Info panel and adjust Picture position
	if Global.info == true:
		$Panel/Info.visible = true
	else:
		$Panel/Info.visible = false

	# Update the card appearance based on the effect
	update_card_appearance()
	if Global.info == false:
		$Panel/Picture.position.y = 0

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
		"Holo":
			$Panel/Info/Overlay.texture = load("res://gui/overlay_holo.png")
			$Panel/Info/Overlay.visible = true
		"":
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

	# Hide set and rarity nodes
	$Panel/Info/set.visible = false
	$Panel/Info/rarity.visible = false

	if Global.info == false:
		$Panel/Info.visible = false

	# Create a new StyleBoxFlat resource for this card instance
	var new_border_style = StyleBoxFlat.new()
	new_border_style.draw_center = false  # Make the inside transparent
	new_border_style.border_width_top = 24
	new_border_style.border_width_bottom = 24
	new_border_style.border_width_left = 24
	new_border_style.border_width_right = 24
	new_border_style.border_color = Color(0, 0, 0)
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

	# Adjust Picture position based on overlay visibility
	if $Panel/Info/Overlay.visible and Global.info == true:
		$Panel/Picture.position.y = 0
		$Panel/Info/red.add_theme_color_override("font_color", Color8(255, 255, 255))
		$Panel/Info/blue.add_theme_color_override("font_color", Color8(255, 255, 255))
		$Panel/Info/yellow.add_theme_color_override("font_color", Color8(255, 255, 255))
	else:
		$Panel/Picture.position.y = 0
		# Set the colors of the red, blue, and yellow labels
		$Panel/Info/red.add_theme_color_override("font_color", Color8(135, 39, 39))    # Red: #872727
		$Panel/Info/blue.add_theme_color_override("font_color", Color8(59, 90, 109))   # Blue: #3b5a6d
		$Panel/Info/yellow.add_theme_color_override("font_color", Color8(197, 197, 56)) # Yellow: #c5c538

func set_protection(protection: int) -> void:
	if has_node("Protector"):
		if protection == 1:
			$Protector.visible = true
		else:
			$Protector.visible = false

func get_protection() -> int:
	return protection
