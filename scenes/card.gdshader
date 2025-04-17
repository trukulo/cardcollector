extends Button

var TIME = 0
var value = 2000
var mousepos = Vector2(0,0)
var bla = 0
var blaa = 0
@export var normal : Marker2D
@export var enabled : bool = true
var veldir = Vector2(0,0)
var oldpos = Vector2(0,0)
var veldir2 = Vector2(0,0)
var oldpos2 = Vector2(0,0)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and enabled:
		mousepos = event.position - (Vector2(140,186)/2)
		veldir = clamp(event.velocity/4000,Vector2(-0.3,-0.3),Vector2(0.3,0.3))
	if event is InputEventMouseButton and enabled:
		if event.button_index == 1 and event.pressed == false:
			bla = 0

func _process(delta: float) -> void:
	if enabled:
		self.visible = true
		TIME += 1*delta
		if bla == 1:
			self.position = lerp(self.position,mousepos,0.25)
			self.rotation += clamp(veldir.x,-0.3,0.3)
			self.rotation *= 0.8
			self.scale = lerp(self.scale,Vector2(1.05,1.05),0.25)
			oldpos = mousepos
			veldir *= 0
		else:
			self.position = lerp(self.position,normal.position,0.25)
			veldir2 = (self.position-oldpos2)*0.01532
			oldpos2 = self.position
			self.rotation += clamp(veldir2.x,-0.3,0.25)
			self.rotation *= 0.8
			veldir2 = (self.position-oldpos2)*0.01532
			self.rotation += sin(TIME+1321)*(0.003625/2)
			self.position.x += cos(TIME+180+1321)*(0.875/2)
			self.position.y += sin(TIME+360+1231)*(0.875/2)
			var material = $Chip.material
			if is_cursor_touching() and enabled:
				if material:
					blaa = 1
					self.scale = lerp(self.scale,Vector2(1.05,1.05),0.25)
					material.set_shader_parameter("hovering", 1)
					material.set_shader_parameter("mouse_screen_pos", Vector2(clampf((get_global_mouse_position()-(self.position+self.size/2)).x*2,-value,value),clampf((get_global_mouse_position()-(self.position+self.size/2)).y*2,-value,value)))
			else:
				if material:
					self.scale = lerp(self.scale,Vector2(1,1),0.25)
					material.set_shader_parameter("hovering", 0)
					blaa = 0
			$Chip/Suit.material = material
	else:
		self.position = normal.position
		self.rotation = 0
		self.visible = false

func _on_button_down() -> void:
	bla = 1

func is_cursor_touching() -> bool:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var start = self.position
	var end = self.position + self.size
	var starty = mouse_pos.x >= start.x and mouse_pos.y >= start.y
	var endy = mouse_pos.x <= end.x and mouse_pos.y <= end.y
	return starty and endy