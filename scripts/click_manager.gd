extends Node

@onready var click = $Click

func _ready():
	# Connect to scene changes to re-scan buttons
	get_tree().node_added.connect(_on_node_added)
	scan_for_buttons(get_tree().get_root())

func _on_node_added(node):
	if node is Button:
		print("New button detected: ", node.name)
		node.pressed.connect(_on_any_button_pressed)

func scan_for_buttons(node):
	for child in node.get_children():
		if child is Button:
			print("Connecting to button: ", child.name)
			child.pressed.connect(_on_any_button_pressed)
		scan_for_buttons(child)

func _on_any_button_pressed():
	print("Button clicked!")
	click.stop()
	click.play()
