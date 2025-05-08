extends ScrollContainer

var touch_start_position = Vector2.ZERO
var is_dragging = false
var drag_distance = 0.0
var drag_threshold = 10  # Ajusta según sea necesario

func _ready():
	# Aumentar el umbral de detección de scroll
	scroll_deadzone = 15

	# Configura los botones para que no capturen los eventos de entrada
	_configure_child_buttons(self)

func _configure_child_buttons(node):
	# Recursivamente configura todos los botones en la jerarquía
	for child in node.get_children():
		if child is Button:
			# Configura el botón para que pase los eventos de entrada
			child.mouse_filter = Control.MOUSE_FILTER_PASS

			# Opcionalmente, conecta una señal personalizada para manejar clics
			child.gui_input.connect(_on_button_gui_input.bind(child))

		# Procesa recursivamente los hijos
		if child.get_child_count() > 0:
			_configure_child_buttons(child)

func _on_button_gui_input(event, button):
	if event is InputEventScreenTouch:
		if not event.pressed and not is_dragging:
			# Si no estamos arrastrando y se levanta el dedo, es un clic
			button.emit_signal("pressed")

	# No hacemos get_viewport().set_input_as_handled() aquí
	# para permitir que los eventos lleguen al ScrollContainer

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			# Cuando el dedo toca la pantalla
			touch_start_position = event.position
			is_dragging = false
			drag_distance = 0.0
		else:
			# Cuando el dedo se levanta
			is_dragging = false

	elif event is InputEventScreenDrag:
		# Calcula la distancia arrastrada
		drag_distance = event.position.distance_to(touch_start_position)

		# Si la distancia es mayor que el umbral, estamos scrolleando
		if drag_distance > drag_threshold:
			is_dragging = true
			# No consumimos el evento aquí para permitir que el ScrollContainer lo procese
