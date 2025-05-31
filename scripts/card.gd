extends Control

var effect: String = "" # Effect of the card
var protection: int = 0 # Protection status of the card
var hover_tween: Tween # Tween for smooth hover animation

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

	# Create tween for hover animation
	hover_tween = create_tween()
	hover_tween.kill() # Stop it initially

	# Connect mouse signals for hover detection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# Get the card's id_set from its image path
func get_card_id_set() -> String:
	var texture = $Panel/Picture.texture
	if texture == null:
		return ""

	var path = texture.resource_path
	# Extract from path like "res://cards/1/5.jpg" -> "5_1"
	var parts = path.split("/")
	if parts.size() >= 3:
		var set_id = parts[parts.size() - 2] # Second to last part (set number)
		var filename = parts[parts.size() - 1] # Last part (filename)
		var card_id = filename.get_basename() # Remove .jpg extension
		return card_id + "_" + set_id
	return ""

# Check if the player owns this card
func is_card_owned() -> bool:
	var id_set = get_card_id_set()
	if id_set != "":
		return Global.get_amount(id_set) > 0
	return false

# Handle mouse entering the card area
func _on_mouse_entered() -> void:
	if is_card_owned():
		animate_scale(Vector2(1.1, 1.1))

# Handle mouse leaving the card area
func _on_mouse_exited() -> void:
	if is_card_owned():
		animate_scale(Vector2(1.0, 1.0))

# Animate the card scale smoothly
func animate_scale(target_scale: Vector2) -> void:
	# Kill any existing tween
	if hover_tween:
		hover_tween.kill()

	# Create new tween
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_BACK)

	# Animate the scale
	hover_tween.tween_property(self, "scale", target_scale, 0.2)

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
